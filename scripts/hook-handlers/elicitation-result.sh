#!/usr/bin/env bash
# elicitation-result.sh
# ElicitationResult 钩子处理器
# 在 Elicitation 结果返回给 MCP 服务器后触发
# 仅进行轻量级日志记录
#
# Input: stdin JSON from Claude Code hooks
# Output: JSON to approve the event
# Hook event: ElicitationResult

set -euo pipefail

# === 配置 ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 加载 path-utils.sh
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh"
fi

# 检测项目根目录
PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"

# 日志文件
STATE_DIR="${PROJECT_ROOT}/.claude/state"
LOG_FILE="${STATE_DIR}/elicitation-events.jsonl"

# === 工具函数 ===

ensure_state_dir() {
  mkdir -p "${STATE_DIR}" 2>/dev/null || true
  chmod 700 "${STATE_DIR}" 2>/dev/null || true
}

# JSONL 轮转（超过 500 行时截断为 400 行）
rotate_jsonl() {
  local file="$1"
  local _lines
  _lines="$(wc -l < "${file}" 2>/dev/null)" || _lines=0
  if [ "${_lines}" -gt 500 ] 2>/dev/null; then
    tail -400 "${file}" > "${file}.tmp" 2>/dev/null && \
      mv "${file}.tmp" "${file}" 2>/dev/null || true
  fi
}

get_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# === 从 stdin 读取 JSON 载荷 ===
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

# 载荷为空时跳过
if [ -z "${INPUT}" ]; then
  echo '{"decision":"approve","reason":"ElicitationResult: no payload"}'
  exit 0
fi

# === 字段提取 ===
MCP_SERVER=""
ELICITATION_ID=""
RESULT_STATUS=""

if command -v jq >/dev/null 2>&1; then
  MCP_SERVER="$(printf '%s' "${INPUT}" | jq -r '.mcp_server_name // .server_name // .matcher // ""' 2>/dev/null || true)"
  ELICITATION_ID="$(printf '%s' "${INPUT}" | jq -r '.elicitation_id // .id // ""' 2>/dev/null || true)"
  RESULT_STATUS="$(printf '%s' "${INPUT}" | jq -r '.result_status // .status // ""' 2>/dev/null || true)"
elif command -v python3 >/dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('mcp_server_name', d.get('server_name', d.get('matcher', ''))))
    print(d.get('elicitation_id', d.get('id', '')))
    print(d.get('result_status', d.get('status', '')))
except:
    print('')
    print('')
    print('')
" 2>/dev/null)"
  MCP_SERVER="$(echo "${_parsed}" | sed -n '1p')"
  ELICITATION_ID="$(echo "${_parsed}" | sed -n '2p')"
  RESULT_STATUS="$(echo "${_parsed}" | sed -n '3p')"
fi

# === 日志记录 ===
ensure_state_dir
TS="$(get_timestamp)"

log_entry=""
if command -v jq >/dev/null 2>&1; then
  log_entry="$(jq -nc \
    --arg event "elicitation_result" \
    --arg mcp_server "${MCP_SERVER}" \
    --arg elicitation_id "${ELICITATION_ID}" \
    --arg result_status "${RESULT_STATUS}" \
    --arg timestamp "${TS}" \
    '{event:$event, mcp_server:$mcp_server, elicitation_id:$elicitation_id, result_status:$result_status, timestamp:$timestamp}')"
elif command -v python3 >/dev/null 2>&1; then
  log_entry="$(python3 -c "
import json, sys
print(json.dumps({
    'event': 'elicitation_result',
    'mcp_server': sys.argv[1],
    'elicitation_id': sys.argv[2],
    'result_status': sys.argv[3],
    'timestamp': sys.argv[4]
}, ensure_ascii=False))
" "${MCP_SERVER}" "${ELICITATION_ID}" "${RESULT_STATUS}" "${TS}" 2>/dev/null)" || log_entry=""
fi

if [ -n "${log_entry}" ]; then
  echo "${log_entry}" >> "${LOG_FILE}" 2>/dev/null || true
  rotate_jsonl "${LOG_FILE}"
fi

# === 响应 ===
echo '{"decision":"approve","reason":"ElicitationResult tracked"}'
exit 0
