#!/bin/bash
# session-register.sh
# 将会话注册到 active.json（无输出）
#
# 使用方法:
#   ./session-register.sh [session_id]
#
# 如果省略 session_id，则从 .claude/state/session.json 获取
# 被 hook 调用时抑制输出，避免与 JSON 输出混淆

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 配置 =====
SESSIONS_DIR=".claude/sessions"
ACTIVE_FILE="${SESSIONS_DIR}/active.json"
SESSION_FILE=".claude/state/session.json"
STALE_THRESHOLD=3600  # 超过1小时的会话视为过期

# ===== 辅助函数 =====
get_session_id_from_file() {
  if [ -f "$SESSION_FILE" ] && command -v jq >/dev/null 2>&1; then
    jq -r '.session_id // empty' "$SESSION_FILE" 2>/dev/null
  fi
}

get_current_timestamp() {
  date +%s
}

# ===== 主处理 =====
main() {
  # 获取会话ID（参数优先，否则从文件获取）
  local session_id="${1:-}"
  if [ -z "$session_id" ]; then
    session_id=$(get_session_id_from_file)
  fi

  # 如果没有会话ID则不做任何处理（也不输出错误）
  if [ -z "$session_id" ] || [ "$session_id" = "null" ]; then
    exit 0
  fi

  # 如果没有 jq 则不做任何处理
  if ! command -v jq >/dev/null 2>&1; then
    exit 0
  fi

  # 创建目录
  mkdir -p "$SESSIONS_DIR"

  local current_time=$(get_current_timestamp)
  local short_id="${session_id:0:12}"

  # 读取 active.json（不存在则为空对象）
  local session_data="{}"
  if [ -f "$ACTIVE_FILE" ]; then
    session_data=$(cat "$ACTIVE_FILE" 2>/dev/null || echo "{}")
  fi

  # 临时文件清理设置
  local tmp_file=""
  cleanup_tmp() { [ -n "$tmp_file" ] && [ -f "$tmp_file" ] && rm -f "$tmp_file"; }
  trap cleanup_tmp EXIT

  # 注册/更新会话
  tmp_file=$(mktemp)
  echo "$session_data" | jq \
    --arg id "$session_id" \
    --arg short "$short_id" \
    --arg time "$current_time" \
    --arg pid "$$" \
    '.[$id] = {
      "short_id": $short,
      "last_seen": ($time | tonumber),
      "pid": $pid,
      "status": "active"
    }' > "$tmp_file" && mv "$tmp_file" "$ACTIVE_FILE"

  # 清理过期会话（超过24小时的）
  local cleanup_threshold=$((current_time - 86400))
  tmp_file=$(mktemp)
  jq --arg threshold "$cleanup_threshold" \
    'to_entries | map(select(.value.last_seen > ($threshold | tonumber))) | from_entries' \
    "$ACTIVE_FILE" > "$tmp_file" && mv "$tmp_file" "$ACTIVE_FILE"
}

main "$@"
