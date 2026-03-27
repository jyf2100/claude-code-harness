#!/bin/bash
# session-list.sh
# 显示活动会话列表
#
# 使用方法:
#   ./session-list.sh
#
# 输出: 活动会话列表

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

# ===== 设置 =====
SESSIONS_DIR=".claude/sessions"
ACTIVE_FILE="${SESSIONS_DIR}/active.json"
SESSION_FILE=".claude/state/session.json"
STALE_THRESHOLD=3600  # 超过1小时的会话视为过期(stale)

# ===== 辅助函数 =====
get_current_session_id() {
  if [ -f "$SESSION_FILE" ] && command -v jq >/dev/null 2>&1; then
    jq -r '.session_id // "unknown"' "$SESSION_FILE" 2>/dev/null
  else
    echo "unknown"
  fi
}

get_current_timestamp() {
  date +%s
}

# ===== 主处理 =====
main() {
  mkdir -p "$SESSIONS_DIR"

  local current_session=$(get_current_session_id)
  local current_time=$(get_current_timestamp)

  # 注册/更新当前会话
  if [ -n "$current_session" ] && [ "$current_session" != "unknown" ]; then
    local session_data="{}"

    if [ -f "$ACTIVE_FILE" ] && command -v jq >/dev/null 2>&1; then
      session_data=$(cat "$ACTIVE_FILE")
    fi

    if command -v jq >/dev/null 2>&1; then
      local short_id="${current_session:0:12}"
      local tmp_file=$(mktemp)
      TEMP_FILES+=("$tmp_file")

      echo "$session_data" | jq \
        --arg id "$current_session" \
        --arg short "$short_id" \
        --arg time "$current_time" \
        --arg pid "$$" \
        '.[$id] = {
          "short_id": $short,
          "last_seen": ($time | tonumber),
          "pid": $pid,
          "status": "active"
        }' > "$tmp_file" && mv "$tmp_file" "$ACTIVE_FILE"
    fi
  fi

  # 显示会话列表
  echo "📋 活动会话列表"
  echo ""

  if [ ! -f "$ACTIVE_FILE" ]; then
    echo "  (无会话)"
    exit 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ⚠️ 未安装 jq，无法显示详细信息"
    exit 0
  fi

  # 清理旧会话的同时显示
  local active_count=0
  local stale_count=0

  echo "| 会话ID | 最后活动时间 | 状态 |"
  echo "|--------|-------------|------|"

  # 处理会话
  jq -r 'to_entries[] | "\(.key)|\(.value.short_id)|\(.value.last_seen)|\(.value.status)"' "$ACTIVE_FILE" 2>/dev/null | while IFS='|' read -r full_id short_id last_seen status; do
    local age=$((current_time - last_seen))
    local time_ago=""
    local display_status=""

    if [ "$age" -lt 60 ]; then
      time_ago="${age}秒前"
    elif [ "$age" -lt 3600 ]; then
      time_ago="$((age / 60))分钟前"
    elif [ "$age" -lt 86400 ]; then
      time_ago="$((age / 3600))小时前"
    else
      time_ago="$((age / 86400))天前"
    fi

    if [ "$full_id" = "$current_session" ]; then
      display_status="🟢 当前会话"
    elif [ "$age" -lt "$STALE_THRESHOLD" ]; then
      display_status="🟡 活动中"
    else
      display_status="⚪ 不活动"
    fi

    echo "| ${short_id} | ${time_ago} | ${display_status} |"
  done

  echo ""
  echo "💡 提示:"
  echo "  - /session broadcast \"消息\" 向所有会话发送通知"
  echo "  - /session inbox 查看收到的消息"
}

main "$@"
