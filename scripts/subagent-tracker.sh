#!/usr/bin/env bash
# subagent-tracker.sh
# Claude Code 2.1.0 SubagentStart/SubagentStop 钩子追踪器
#
# 使用方法:
#   ./subagent-tracker.sh start   # 子代理启动时
#   ./subagent-tracker.sh stop    # 子代理结束时
#
# 环境变量（SubagentStop 时可用）:
#   AGENT_ID              - 子代理的标识符
#   AGENT_TRANSCRIPT_PATH - 转录文件的路径

set -euo pipefail

# === 配置 ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/path-utils.sh" 2>/dev/null || true

# 检测项目根目录
PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"

# 日志目录
LOG_DIR="${PROJECT_ROOT}/.claude/logs"
SUBAGENT_LOG="${LOG_DIR}/subagent-history.jsonl"

# === 工具函数 ===

ensure_log_dir() {
  mkdir -p "${LOG_DIR}" 2>/dev/null || true
}

get_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# === 主处理 ===

action="${1:-}"

case "${action}" in
  start)
    ensure_log_dir

    # 从环境变量获取信息（如果可用）
    agent_id="${AGENT_ID:-unknown}"

    # 创建日志条目
    log_entry=$(cat <<EOF
{"event":"subagent_start","timestamp":"$(get_timestamp)","agent_id":"${agent_id}"}
EOF
)

    # 以 JSONL 格式追加
    echo "${log_entry}" >> "${SUBAGENT_LOG}" 2>/dev/null || true

    # 成功响应（钩子期望的 JSON 格式）
    echo '{"decision":"approve","reason":"Subagent start tracked"}'
    ;;

  stop)
    ensure_log_dir

    # 从环境变量获取信息
    agent_id="${AGENT_ID:-unknown}"
    transcript_path="${AGENT_TRANSCRIPT_PATH:-}"

    # 获取转录摘要（如果存在）
    transcript_summary=""
    if [[ -n "${transcript_path}" && -f "${transcript_path}" ]]; then
      # 获取最后 50 行进行摘要
      transcript_summary=$(tail -50 "${transcript_path}" 2>/dev/null | head -c 500 || echo "")
      transcript_summary="${transcript_summary//\"/\\\"}"  # 转义引号
      transcript_summary="${transcript_summary//$'\n'/\\n}"  # 转义换行
    fi

    # 创建日志条目
    log_entry=$(cat <<EOF
{"event":"subagent_stop","timestamp":"$(get_timestamp)","agent_id":"${agent_id}","transcript_path":"${transcript_path}","transcript_preview":"${transcript_summary:0:200}"}
EOF
)

    # 以 JSONL 格式追加
    echo "${log_entry}" >> "${SUBAGENT_LOG}" 2>/dev/null || true

    # 成功响应
    echo '{"decision":"approve","reason":"Subagent stop tracked"}'
    ;;

  *)
    echo '{"decision":"approve","reason":"Unknown action, skipping"}'
    ;;
esac

exit 0
