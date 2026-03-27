#!/bin/bash
# stop-check-pending.sh
# Stop 时检查未解决的 pending-skills 并发出警告
#
# Usage: 从 Stop hook 自动执行（type: command）
# Input: stdin JSON (Claude Code hooks)
# Output: 面向人类的文本警告（直接输出到 stdout）

set +e

STATE_DIR=".claude/state"
PENDING_DIR="${STATE_DIR}/pending-skills"

# 如果 pending 目录不存在，则不输出任何内容并退出
if [ ! -d "$PENDING_DIR" ]; then
  exit 0
fi

# 检查 pending 文件
PENDING_FILES=$(ls "$PENDING_DIR"/*.pending 2>/dev/null || true)

if [ -z "$PENDING_FILES" ]; then
  exit 0
fi

# 存在未解决的 pending
PENDING_COMMANDS=""
for f in $PENDING_FILES; do
  CMD_NAME=$(basename "$f" .pending)
  PENDING_COMMANDS="${PENDING_COMMANDS}${CMD_NAME}, "
done
PENDING_COMMANDS=$(echo "$PENDING_COMMANDS" | sed 's/, $//')

# 清除 pending（已警告）
rm -f "$PENDING_DIR"/*.pending 2>/dev/null || true

# 向 stdout 输出面向人类的文本警告
cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  质量门禁未执行警告
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

以下命令已执行，但对应的 Skill 未被调用:
  → ${PENDING_COMMANDS}

这可能会导致以下问题:
  1. 使用统计缺失: Skills 的使用历史未被记录
  2. 质量护栏未执行: 审查/验证技能可能未被应用

建议: 手动执行 /harness-review 进行质量检查。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

exit 0
