#!/bin/bash
# session-broadcast.sh
# 跨会话广播消息发送
#
# 使用方法:
#   ./session-broadcast.sh "消息内容"
#   ./session-broadcast.sh --auto "文件名" "变更内容"
#
# 输出: 将广播消息追加到 .claude/sessions/broadcast.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== Cleanup trap for temp files =====
TEMP_FILES=()
cleanup() {
  for f in "${TEMP_FILES[@]:-}"; do
    [ -f "$f" ] && rm -f "$f"
  done
}
trap cleanup EXIT

# ===== 配置 =====
SESSIONS_DIR=".claude/sessions"
BROADCAST_FILE="${SESSIONS_DIR}/broadcast.md"
SESSION_FILE=".claude/state/session.json"
MAX_MESSAGES=100  # 最大保留消息数

# ===== 辅助函数 =====
get_session_id() {
  if [ -f "$SESSION_FILE" ] && command -v jq >/dev/null 2>&1; then
    jq -r '.session_id // "unknown"' "$SESSION_FILE" 2>/dev/null
  else
    echo "session-$(date +%s)"
  fi
}

get_timestamp() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# ===== 主处理 =====
main() {
  local mode="manual"
  local message=""
  local file_path=""

  # 参数解析
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --auto)
        mode="auto"
        shift
        if [[ $# -ge 2 ]]; then
          file_path="$1"
          message="$2"
          shift 2
        else
          echo "Error: --auto requires <file_path> <message>" >&2
          exit 1
        fi
        ;;
      --help|-h)
        echo "Usage: session-broadcast.sh [--auto <file> <msg>] <message>"
        echo ""
        echo "Options:"
        echo "  --auto <file> <msg>  Auto-broadcast for file changes"
        echo "  --help               Show this help"
        exit 0
        ;;
      *)
        message="$1"
        shift
        ;;
    esac
  done

  if [ -z "$message" ]; then
    echo "Error: Message is required" >&2
    exit 1
  fi

  # 创建目录
  mkdir -p "$SESSIONS_DIR"

  # 获取会话ID和时间戳
  local session_id=$(get_session_id)
  local timestamp=$(get_timestamp)
  local short_id="${session_id:0:12}"

  # 消息类型前缀
  local prefix=""
  if [ "$mode" = "auto" ]; then
    prefix="[AUTO] "
    message="📁 \`${file_path}\` 已变更: ${message}"
  fi

  # 追加到广播文件
  {
    echo ""
    echo "## ${timestamp} [${short_id}]"
    echo "${prefix}${message}"
  } >> "$BROADCAST_FILE"

  # 删除旧消息（超过 MAX_MESSAGES 时）
  if [ -f "$BROADCAST_FILE" ]; then
    local msg_count=$(grep -c "^## " "$BROADCAST_FILE" 2>/dev/null || echo "0")
    if [ "$msg_count" -gt "$MAX_MESSAGES" ]; then
      # 仅保留最新的 MAX_MESSAGES 条
      local temp_file=$(mktemp)
      TEMP_FILES+=("$temp_file")
      local skip_count=$((msg_count - MAX_MESSAGES))
      awk -v skip="$skip_count" '
        /^## / { count++ }
        count > skip { print }
      ' "$BROADCAST_FILE" > "$temp_file"
      mv "$temp_file" "$BROADCAST_FILE"
    fi
  fi

  # 输出成功消息
  echo "📤 Broadcast sent: ${message:0:50}..."

  # JSON 输出（用于 hooks）
  if [ "${HOOK_OUTPUT:-}" = "true" ]; then
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"📤 广播已发送: ${message:0:50}..."}}
EOF
  fi
}

main "$@"
