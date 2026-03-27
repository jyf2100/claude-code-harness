#!/bin/bash
# session-inbox-check.sh
# 跨会话消息接收检查
#
# 使用方法:
#   ./session-inbox-check.sh           # 显示未读消息
#   ./session-inbox-check.sh --count   # 仅显示未读数量
#   ./session-inbox-check.sh --mark    # 标记为已读
#
# 输出: 未读消息列表或JSON（hooks用）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 配置 =====
SESSIONS_DIR=".claude/sessions"
BROADCAST_FILE="${SESSIONS_DIR}/broadcast.md"
SESSION_FILE=".claude/state/session.json"

# ===== 辅助函数 =====
get_session_id() {
  if [ -f "$SESSION_FILE" ] && command -v jq >/dev/null 2>&1; then
    jq -r '.session_id // "unknown"' "$SESSION_FILE" 2>/dev/null
  else
    echo "unknown"
  fi
}

get_last_read_file() {
  local session_id=$(get_session_id)
  echo "${SESSIONS_DIR}/.last_read_${session_id}"
}

get_last_read_time() {
  local last_read_file=$(get_last_read_file)
  if [ -f "$last_read_file" ]; then
    cat "$last_read_file"
  else
    echo "1970-01-01T00:00:00Z"
  fi
}

mark_as_read() {
  local last_read_file=$(get_last_read_file)
  mkdir -p "$SESSIONS_DIR"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$last_read_file"
}

# ===== 主处理 =====
main() {
  local mode="list"
  local hook_output="false"

  # 参数解析
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --count)
        mode="count"
        shift
        ;;
      --mark)
        mode="mark"
        shift
        ;;
      --hook)
        hook_output="true"
        shift
        ;;
      --help|-h)
        echo "Usage: session-inbox-check.sh [--count|--mark|--hook]"
        echo ""
        echo "Options:"
        echo "  --count  Show unread count only"
        echo "  --mark   Mark all as read"
        echo "  --hook   Output JSON for hooks"
        exit 0
        ;;
      *)
        shift
        ;;
    esac
  done

  # 广播文件不存在的情况
  if [ ! -f "$BROADCAST_FILE" ]; then
    if [ "$hook_output" = "true" ]; then
      echo '{"hookSpecificOutput":{"hookEventName":"InboxCheck","additionalContext":""}}'
    elif [ "$mode" = "count" ]; then
      echo "0"
    else
      echo "📭 没有消息"
    fi
    exit 0
  fi

  # 已读标记处理
  if [ "$mode" = "mark" ]; then
    mark_as_read
    echo "✅ 所有消息已标记为已读"
    exit 0
  fi

  # 获取最后读取时间
  local last_read=$(get_last_read_time)
  local current_session=$(get_session_id)
  local short_current="${current_session:0:12}"

  # 提取未读消息
  local unread_messages=""
  local unread_count=0
  local in_message=false
  local current_timestamp=""
  local current_sender=""
  local current_content=""

  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^##\ ([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)\ \[([^\]]+)\] ]]; then
      # 处理前一条消息
      if [ "$in_message" = true ] && [ -n "$current_content" ]; then
        if [[ "$current_timestamp" > "$last_read" ]] && [[ "$current_sender" != "$short_current" ]]; then
          unread_count=$((unread_count + 1))
          unread_messages="${unread_messages}\n[${current_timestamp:11:5}] ${current_sender}: ${current_content}"
        fi
      fi

      # 开始新消息
      current_timestamp="${BASH_REMATCH[1]}"
      current_sender="${BASH_REMATCH[2]}"
      current_content=""
      in_message=true
    elif [ "$in_message" = true ] && [ -n "$line" ]; then
      current_content="$line"
    fi
  done < "$BROADCAST_FILE"

  # 处理最后一条消息
  if [ "$in_message" = true ] && [ -n "$current_content" ]; then
    if [[ "$current_timestamp" > "$last_read" ]] && [[ "$current_sender" != "$short_current" ]]; then
      unread_count=$((unread_count + 1))
      unread_messages="${unread_messages}\n[${current_timestamp:11:5}] ${current_sender}: ${current_content}"
    fi
  fi

  # 输出
  if [ "$mode" = "count" ]; then
    echo "$unread_count"
  elif [ "$hook_output" = "true" ]; then
    if [ "$unread_count" -gt 0 ]; then
      local escaped_messages=$(echo -e "$unread_messages" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
      cat <<EOF
{"hookSpecificOutput":{"hookEventName":"InboxCheck","additionalContext":"📨 未读消息 ${unread_count}条:\\n${escaped_messages}"}}
EOF
    else
      echo '{"hookSpecificOutput":{"hookEventName":"InboxCheck","additionalContext":""}}'
    fi
  else
    if [ "$unread_count" -gt 0 ]; then
      echo "📨 未读消息 ${unread_count}条:"
      echo -e "$unread_messages"
      echo ""
      echo "💡 使用 /session inbox --mark 标记为已读"
    else
      echo "📭 没有未读消息"
    fi
  fi
}

main "$@"
