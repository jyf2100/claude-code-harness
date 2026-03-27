#!/bin/bash
# posttooluse-clear-pending.sh
# PostToolUse/Skill 时清除 pending-skills
#
# Usage: PostToolUse hook 自动执行（Skill 匹配器）
# Input: stdin JSON (Claude Code hooks)
# Output: JSON (continue)

set +e

STATE_DIR=".claude/state"
PENDING_DIR="${STATE_DIR}/pending-skills"

# 如果 pending 目录不存在则跳过
[ ! -d "$PENDING_DIR" ] && { echo '{"continue":true}'; exit 0; }

# 如果存在 pending 文件则全部清除
# （Skill 调用 = 视为已执行质量门检查）
PENDING_FILES=$(ls "$PENDING_DIR"/*.pending 2>/dev/null || true)

if [ -n "$PENDING_FILES" ]; then
  for f in $PENDING_FILES; do
    rm -f "$f" 2>/dev/null || true
  done
fi

echo '{"continue":true}'
exit 0
