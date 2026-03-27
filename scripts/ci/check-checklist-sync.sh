#!/bin/bash
# check-checklist-sync.sh
# 验证命令文件的检查清单与脚本的检查项是否同步
#
# 目的:
# - 确认 scripts/setup-2agent.sh 的 check_file/check_dir 与
#   commands/setup-2agent.md 的检查清单是否一致
# - scripts/update-2agent.sh 与 commands/update-2agent.md 同理

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ERRORS=0

echo "🔍 检查清单同步验证"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ================================
# 工具函数
# ================================

# 从脚本中提取 check_file/check_dir 的参数
extract_script_checks() {
  local script="$1"
  grep -E 'check_(file|dir)' "$script" 2>/dev/null | \
    awk -F'"' '{print $2}' | \
    grep -v '^$' | \
    sort -u
}

# 从命令文件中提取检查清单项
# 仅提取"自动验证"部分（排除"Claude 生成"部分）
extract_command_checklist() {
  local cmd="$1"
  # 提取从"自动验证"到"Claude 生成"或下一章节的内容
  awk '/自动验证/,/Claude 生成|^###|^\*\*全部/' "$cmd" 2>/dev/null | \
    grep -E '^\s*-\s*\[\s*\]\s*`[^`]+`' | \
    awk -F'`' '{print $2}' | \
    grep -v '^$' | \
    sort -u
}

# 比较两个列表
compare_lists() {
  local name="$1"
  local script_file="$2"
  local command_file="$3"

  echo ""
  echo "📋 验证 $name..."

  # 提取到临时文件
  local script_checks=$(mktemp)
  local command_checks=$(mktemp)

  extract_script_checks "$script_file" > "$script_checks"
  extract_command_checklist "$command_file" > "$command_checks"

  # 脚本中有但命令中没有的项
  local missing_in_command=$(comm -23 "$script_checks" "$command_checks")
  if [ -n "$missing_in_command" ]; then
    echo "  ❌ 脚本中存在但命令检查清单中没有:"
    echo "$missing_in_command" | while read item; do
      echo "     - $item"
    done
    ERRORS=$((ERRORS + 1))
  fi

  # 命令中有但脚本中没有的项
  local missing_in_script=$(comm -13 "$script_checks" "$command_checks")
  if [ -n "$missing_in_script" ]; then
    echo "  ❌ 命令检查清单中存在但脚本中没有:"
    echo "$missing_in_script" | while read item; do
      echo "     - $item"
    done
    ERRORS=$((ERRORS + 1))
  fi

  # 两者都为空时跳过（防止误判为通过）
  local script_count=$(wc -l < "$script_checks" | tr -d ' ')
  local command_count=$(wc -l < "$command_checks" | tr -d ' ')

  if [ "$script_count" -eq 0 ] && [ "$command_count" -eq 0 ]; then
    echo "  ⚠️ 跳过: 未找到检查项（请确认文件结构）"
  elif [ -z "$missing_in_command" ] && [ -z "$missing_in_script" ]; then
    echo "  ✅ 已同步 ($script_count 项)"
  fi

  rm -f "$script_checks" "$command_checks"
}

# ================================
# 主验证
# ================================

# setup hub 的验证（v2.19.0+ 2agent 已整合到 setup）
SETUP_SKILL="$PLUGIN_ROOT/skills/setup/SKILL.md"
SETUP_2AGENT_REF="$PLUGIN_ROOT/skills/setup/references/2agent-setup.md"

if [ -f "$SETUP_SKILL" ] && [ -f "$SETUP_2AGENT_REF" ]; then
  echo "✓ setup 技能和 2agent-setup 参考文件存在"
elif [ -f "$SETUP_SKILL" ]; then
  echo "⚠️ 未找到 setup/references/2agent-setup.md（请确认整合后的结构）"
else
  echo "⚠️ 未找到 skills/setup/SKILL.md（技能可能尚未创建）"
fi

# 注意: v2.17.0 之后，命令已迁移至技能
# 检查清单同步今后将按技能单位管理
# 如果未找到目标技能则正常退出（不因空检查清单而失败）

# ================================
# 结果摘要
# ================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ]; then
  echo "✅ 检查清单同步验证通过"
  exit 0
else
  echo "❌ 发现 $ERRORS 处不一致"
  echo ""
  echo "💡 修复方法:"
  echo "  1. 检查 scripts/*.sh 的 check_file/check_dir"
  echo "  2. 更新 commands/*.md 的检查清单"
  echo "  3. 确保两者一致"
  exit 1
fi
