#!/bin/bash
# session-auto-broadcast.sh
# 文件更改时的自动广播
#
# 在 PostToolUse (Write|Edit) 时被调用
# 重要文件（API、类型定义等）更改时自动通知
#
# 输入: 从 stdin 读取 JSON (包含 tool_input)
# 输出: JSON (hookSpecificOutput)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 配置 =====
# 自动广播目标模式
AUTO_BROADCAST_PATTERNS=(
  "src/api/"
  "src/types/"
  "src/interfaces/"
  "api/"
  "types/"
  "schema.prisma"
  "openapi"
  "swagger"
  ".graphql"
)

# 配置文件路径
CONFIG_FILE=".claude/sessions/auto-broadcast.json"

# ===== 从 stdin 读取 JSON 输入 =====
INPUT=""
if [ -t 0 ]; then
  : # stdin 为 TTY 时无输入
else
  INPUT=$(cat 2>/dev/null || true)
fi

# ===== 提取文件路径 =====
FILE_PATH=""
if [ -n "$INPUT" ] && command -v jq >/dev/null 2>&1; then
  FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)"
fi

# 无文件路径时退出
if [ -z "$FILE_PATH" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":""}}'
  exit 0
fi

# ===== 检查自动广播是否启用 =====
AUTO_BROADCAST_ENABLED="true"
if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
  AUTO_BROADCAST_ENABLED="$(jq -r '.enabled // true' "$CONFIG_FILE" 2>/dev/null)"
fi

if [ "$AUTO_BROADCAST_ENABLED" != "true" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":""}}'
  exit 0
fi

# ===== 模式匹配 =====
should_broadcast="false"
matched_pattern=""

for pattern in "${AUTO_BROADCAST_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    should_broadcast="true"
    matched_pattern="$pattern"
    break
  fi
done

# 也检查自定义模式
if [ "$should_broadcast" = "false" ] && [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
  CUSTOM_PATTERNS=$(jq -r '.patterns // [] | .[]' "$CONFIG_FILE" 2>/dev/null)
  while IFS= read -r pattern; do
    if [ -n "$pattern" ] && [[ "$FILE_PATH" == *"$pattern"* ]]; then
      should_broadcast="true"
      matched_pattern="$pattern"
      break
    fi
  done <<< "$CUSTOM_PATTERNS"
fi

# ===== 执行广播 =====
if [ "$should_broadcast" = "true" ]; then
  # 提取文件名
  FILE_NAME=$(basename "$FILE_PATH")

  # 执行广播
  bash "$SCRIPT_DIR/session-broadcast.sh" --auto "$FILE_PATH" "匹配模式 '$matched_pattern'" >/dev/null 2>/dev/null || true

  # 输出通知消息
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"📢 自动广播: 已将 ${FILE_NAME} 的更改通知其他会话"}}
EOF
else
  echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":""}}'
fi

exit 0
