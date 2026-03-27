#!/bin/bash
# show-failures.sh
# 显示 StopFailure 日志的汇总摘要
#
# 读取 stop-failures.jsonl，输出按错误代码分类的统计、最近 5 条记录和建议操作。
# 由 harness-sync --show-failures 调用。也可独立运行。
#
# Usage: bash scripts/show-failures.sh [--days N] [--json]
#   --days N  统计天数（默认: 30）
#   --json    以 JSON 格式输出（用于管道）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 加载 path-utils.sh
if [ -f "${SCRIPT_DIR}/path-utils.sh" ]; then
  source "${SCRIPT_DIR}/path-utils.sh"
fi

# 检测项目根目录
if declare -F detect_project_root > /dev/null 2>&1; then
  PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"
else
  PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
fi

# 状态目录（支持 CLAUDE_PLUGIN_DATA）
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  _project_hash="$(printf '%s' "${PROJECT_ROOT}" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null || echo "default  -"; } | cut -c1-12)"
  [ -z "${_project_hash}" ] && _project_hash="default"
  STATE_DIR="${CLAUDE_PLUGIN_DATA}/projects/${_project_hash}"
else
  STATE_DIR="${PROJECT_ROOT}/.claude/state"
fi
LOG_FILE="${STATE_DIR}/stop-failures.jsonl"

# === 参数解析 ===
DAYS=30
JSON_OUTPUT=false

while [ $# -gt 0 ]; do
  case "$1" in
    --days)
      if [ $# -lt 2 ] || ! [[ ${2} =~ ^[0-9]+$ ]]; then
        echo "错误: --days 需要指定正整数" >&2
        exit 1
      fi
      DAYS="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    *) shift ;;
  esac
done

# === 日志文件存在检查 ===
if [ ! -f "${LOG_FILE}" ] || [ ! -s "${LOG_FILE}" ]; then
  if [ "${JSON_OUTPUT}" = true ]; then
    echo '{"total":0,"entries":[],"summary":"No StopFailure events recorded."}'
  else
    echo "没有 StopFailure 日志（${LOG_FILE}）"
    echo ""
    echo "这是个好消息 — 尚未发生因 API 错误导致的会话停止失败。"
  fi
  exit 0
fi

# === 需要 jq ===
if ! command -v jq > /dev/null 2>&1; then
  # 没有 jq 时只显示行数
  LINE_COUNT=$(wc -l < "${LOG_FILE}" | tr -d ' ')
  echo "StopFailure 日志: ${LINE_COUNT} 条（需要 jq 才能显示详情）"
  echo "日志文件: ${LOG_FILE}"
  exit 0
fi

# === 统计 ===
CUTOFF_DATE=$(date -u -v-${DAYS}d +"%Y-%m-%dT" 2>/dev/null || date -u -d "${DAYS} days ago" +"%Y-%m-%dT" 2>/dev/null || echo "")

# 全部或按期间过滤
if [ -n "${CUTOFF_DATE}" ]; then
  FILTERED=$(jq -c "select(.timestamp >= \"${CUTOFF_DATE}\")" "${LOG_FILE}" 2>/dev/null || cat "${LOG_FILE}")
else
  FILTERED=$(cat "${LOG_FILE}")
fi

TOTAL=$(echo "${FILTERED}" | grep -c '^{' 2>/dev/null || echo "0")

if [ "${TOTAL}" -eq 0 ]; then
  if [ "${JSON_OUTPUT}" = true ]; then
    echo '{"total":0,"entries":[],"summary":"No events in the specified period."}'
  else
    echo "最近 ${DAYS} 天的 StopFailure 事件: 0 条"
  fi
  exit 0
fi

# 按错误代码统计
COUNT_429=$(echo "${FILTERED}" | jq -r 'select(.error_code == "429") | .error_code' 2>/dev/null | wc -l | tr -d ' ')
COUNT_401=$(echo "${FILTERED}" | jq -r 'select(.error_code == "401") | .error_code' 2>/dev/null | wc -l | tr -d ' ')
COUNT_500=$(echo "${FILTERED}" | jq -r 'select(.error_code == "500") | .error_code' 2>/dev/null | wc -l | tr -d ' ')
COUNT_OTHER=$(( TOTAL - COUNT_429 - COUNT_401 - COUNT_500 ))
[ "${COUNT_OTHER}" -lt 0 ] && COUNT_OTHER=0

# 最近 5 条
RECENT=$(echo "${FILTERED}" | tail -5 | jq -r '[.timestamp, .error_code, .session_id, .message] | join(" | ")' 2>/dev/null || echo "(parse error)")

# === 输出 ===
if [ "${JSON_OUTPUT}" = true ]; then
  jq -nc \
    --argjson total "${TOTAL}" \
    --argjson c429 "${COUNT_429}" \
    --argjson c401 "${COUNT_401}" \
    --argjson c500 "${COUNT_500}" \
    --argjson cother "${COUNT_OTHER}" \
    --argjson days "${DAYS}" \
    '{
      total: $total,
      period_days: $days,
      by_code: { "429": $c429, "401": $c401, "500": $c500, other: $cother }
    }'
else
  echo "StopFailure 摘要（最近 ${DAYS} 天）"
  echo "========================================"
  echo ""
  echo "总计: ${TOTAL} 条"
  echo ""
  echo "错误分布:"
  [ "${COUNT_429}" -gt 0 ] && echo "  429 (Rate Limit): ${COUNT_429} 次"
  [ "${COUNT_401}" -gt 0 ] && echo "  401 (Auth):       ${COUNT_401} 次"
  [ "${COUNT_500}" -gt 0 ] && echo "  500 (Server):     ${COUNT_500} 次"
  [ "${COUNT_OTHER}" -gt 0 ] && echo "  其他:             ${COUNT_OTHER} 次"
  [ "${TOTAL}" -eq 0 ] && echo "  （无事件）"
  echo ""
  echo "最近 5 条:"
  echo "${RECENT}" | while IFS= read -r line; do
    [ -n "${line}" ] && echo "  ${line}"
  done
  echo ""

  # 建议操作
  if [ "${COUNT_429}" -ge 5 ]; then
    echo "建议: 429 错误频繁发生。请减少 Breezing 的并行 Worker 数量。"
  elif [ "${COUNT_429}" -ge 1 ]; then
    echo "信息: 已发生 ${COUNT_429} 次 429 错误。如频繁发生，请考虑调整 Worker 数量。"
  fi
  if [ "${COUNT_401}" -ge 1 ]; then
    echo "建议: 发生了认证错误。请运行 claude auth login 更新认证。"
  fi
fi
