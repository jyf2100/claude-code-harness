#!/bin/bash
# skill-child-reminder.sh
# PostToolUse hook: Skill 工具使用后提醒加载子技能
#
# Usage: PostToolUse hook 自动执行（matcher="Skill"）
# Input: stdin JSON (Claude Code hooks)
# Output: 提醒消息（当存在子技能时）

set +e

# 从 stdin 读取 JSON 输入
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

[ -z "$INPUT" ] && exit 0

# 从 JSON 中提取工具名和技能名
TOOL_NAME=""
SKILL_NAME=""

if command -v jq >/dev/null 2>&1; then
  TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
  SKILL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  eval "$(printf '%s' "$INPUT" | python3 -c '
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
tool_name = data.get("tool_name") or ""
tool_input = data.get("tool_input") or {}
skill_name = tool_input.get("skill") or ""
print(f"TOOL_NAME={shlex.quote(tool_name)}")
print(f"SKILL_NAME={shlex.quote(skill_name)}")
' 2>/dev/null)"
fi

# 跳过非 Skill 工具
[ "$TOOL_NAME" != "Skill" ] && exit 0
[ -z "$SKILL_NAME" ] && exit 0

# 获取插件根目录
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(realpath "$0")")")}"

# 从技能名中提取类别（例: "claude-code-harness:impl" → "impl"）
SKILL_CATEGORY="${SKILL_NAME##*:}"

# 确认子技能目录是否存在
SKILL_DIR="${PLUGIN_ROOT}/skills/${SKILL_CATEGORY}"

if [ -d "$SKILL_DIR" ]; then
  # 获取子技能（doc.md）列表
  CHILD_SKILLS=""
  for child_dir in "$SKILL_DIR"/*/; do
    if [ -f "${child_dir}doc.md" ]; then
      child_name=$(basename "$child_dir")
      CHILD_SKILLS="${CHILD_SKILLS}  - ${SKILL_CATEGORY}/${child_name}/doc.md\n"
    fi
  done

  # 仅当存在子技能时输出提醒
  if [ -n "$CHILD_SKILLS" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📚 Skill Hierarchy Reminder"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "「${SKILL_CATEGORY}」技能包含以下子技能："
    echo ""
    echo -e "$CHILD_SKILLS"
    echo ""
    echo "⚠️  请根据用户意图，使用 Read 读取相应的 doc.md。"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
  fi
fi

exit 0
