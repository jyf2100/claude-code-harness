#!/bin/bash
# pretooluse-inbox-check.sh
# PreToolUse Hook: 在工具执行前检查未读消息
#
# 在 Write|Edit 执行前检查来自其他会话的消息，
# 确保不会错过重要的变更通知
#
# 输入: 从 stdin 读取 JSON
# 输出: JSON (hookSpecificOutput)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 配置 =====
SESSIONS_DIR=".claude/sessions"
BROADCAST_FILE="${SESSIONS_DIR}/broadcast.md"
SESSION_FILE=".claude/state/session.json"
CHECK_INTERVAL_FILE="${SESSIONS_DIR}/.last_inbox_check"
CHECK_INTERVAL=300  # 每5分钟检查一次（防止通知过于频繁）

# ===== 从 stdin 读取 JSON 输入 =====
INPUT=""
if [ -t 0 ]; then
  : # stdin 是 TTY 时无输入
else
  INPUT=$(cat 2>/dev/null || true)
fi

# ===== 检查间隔确认 =====
current_time=$(date +%s)
last_check=0

if [ -f "$CHECK_INTERVAL_FILE" ]; then
  last_check=$(cat "$CHECK_INTERVAL_FILE" 2>/dev/null || echo "0")
fi

time_since_check=$((current_time - last_check))

# 在检查间隔内则跳过（不输出任何内容 → 不影响权限判定）
if [ "$time_since_check" -lt "$CHECK_INTERVAL" ]; then
  exit 0
fi

# 更新检查时间
mkdir -p "$SESSIONS_DIR"
echo "$current_time" > "$CHECK_INTERVAL_FILE"

# ===== 检查未读消息 =====
if [ ! -f "$BROADCAST_FILE" ]; then
  exit 0
fi

# 使用 inbox-check 脚本
UNREAD_COUNT=$(bash "$SCRIPT_DIR/session-inbox-check.sh" --count 2>/dev/null || echo "0")

if [ "$UNREAD_COUNT" -gt 0 ]; then
  # 获取未读消息内容（最多5条）
  # 从 session-inbox-check.sh 的输出中提取实际消息行
  INBOX_MESSAGES=$(bash "$SCRIPT_DIR/session-inbox-check.sh" 2>/dev/null | grep -E '^\[' | head -5 || echo "")

  if [ -n "$INBOX_MESSAGES" ]; then
    # 对消息内容进行转义处理
    ESCAPED_MESSAGES=$(echo "$INBOX_MESSAGES" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

    # 直接显示消息内容（permissionDecision: "allow" 不影响权限判定）
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"📨 来自其他会话的消息 ${UNREAD_COUNT}件:\\n---\\n${ESCAPED_MESSAGES}\\n---"}}
EOF
  else
    # 消息提取失败时的回退处理
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"📨 来自其他会话的消息有 ${UNREAD_COUNT}件"}}
EOF
  fi
else
  # 无未读消息 → 不输出任何内容（不影响权限判定）
  :
fi

exit 0
