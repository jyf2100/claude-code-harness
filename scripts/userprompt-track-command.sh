#!/bin/bash
# userprompt-track-command.sh
# UserPromptSubmit时检测斜杠命令并记录usage
# + Skill必需命令的 pending 创建
#
# Usage: UserPromptSubmit hook 自动执行
# Input: stdin JSON (Claude Code hooks)
# Output: JSON (continue)

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR=".claude/state"
PENDING_DIR="${STATE_DIR}/pending-skills"
RECORD_USAGE="$SCRIPT_DIR/record-usage.js"

# Skill必需命令列表
# 这些命令预期使用Skill tool
SKILL_REQUIRED_COMMANDS="work|harness-review|validate|plan-with-agent"

# 从JSON中提取值（jq优先）
json_get() {
  local json="$1"
  local key="$2"
  local default="${3:-}"

  if command -v jq >/dev/null 2>&1; then
    echo "$json" | jq -r "$key // \"$default\"" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

# 从stdin读取JSON输入
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

[ -z "$INPUT" ] && { echo '{"continue":true}'; exit 0; }

# 提取prompt
PROMPT=$(json_get "$INPUT" ".prompt" "")

# 空prompt跳过
[ -z "$PROMPT" ] && { echo '{"continue":true}'; exit 0; }

# 检测斜杠命令（行首以 /xxx 开始）
# 多行时仅检查第一行
FIRST_LINE=$(echo "$PROMPT" | head -n1)

if [[ "$FIRST_LINE" =~ ^/([a-zA-Z0-9_:/-]+) ]]; then
  RAW_COMMAND="${BASH_REMATCH[1]}"

  # 规范化命令名（移除插件前缀）
  # /claude-code-harness:core:work → work
  # /claude-code-harness/work → work
  # /work → work
  COMMAND_NAME="$RAW_COMMAND"
  # claude-code-harness:xxx:yyy → yyy（最后一个片段）
  if [[ "$COMMAND_NAME" =~ ^claude-code-harness[:/] ]]; then
    COMMAND_NAME=$(echo "$COMMAND_NAME" | sed 's|.*[:/]||')
  fi

  # 记录命令使用
  if [ -f "$RECORD_USAGE" ] && [ -n "$COMMAND_NAME" ]; then
    node "$RECORD_USAGE" command "$COMMAND_NAME" >/dev/null 2>&1 || true
  fi

  # 检查是否为Skill必需命令
  if echo "$COMMAND_NAME" | grep -qiE "^($SKILL_REQUIRED_COMMANDS)$"; then
    # Permission hardening: prompt_preview contains user input,
    # restrict file permissions to owner-only (rwx------/rw-------)
    OLD_UMASK=$(umask)
    umask 077

    # 创建pending目录 (symlink bypass protection)
    if [ -L "$PENDING_DIR" ] || [ -L "$(dirname "$PENDING_DIR")" ]; then
      echo "[track-command] Warning: symlink detected in state path, skipping" >&2
      umask "$OLD_UMASK"
    else
    mkdir -p "$PENDING_DIR"

    # 创建pending文件（带时间戳）
    PENDING_FILE="${PENDING_DIR}/${COMMAND_NAME}.pending"
    # Security: refuse if pending file is a symlink
    if [ -L "$PENDING_FILE" ]; then
      echo "[track-command] Warning: symlink detected at $PENDING_FILE, skipping" >&2
      umask "$OLD_UMASK"
    else
    cat > "$PENDING_FILE" <<EOF
{
  "command": "$COMMAND_NAME",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "prompt_preview": "$(echo "$PROMPT" | head -c 200 | tr '\n' ' ' | sed 's/"/\\"/g')"
}
EOF

    # Restore original umask
    umask "$OLD_UMASK"
    fi  # end symlink check for PENDING_FILE
    fi  # end symlink check for PENDING_DIR
  fi
fi

echo '{"continue":true}'
exit 0
