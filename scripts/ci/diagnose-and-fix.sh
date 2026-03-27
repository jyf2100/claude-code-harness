#!/bin/bash
# diagnose-and-fix.sh
# 诊断 CI 错误，提出修复建议或自动修复的脚本
#
# Usage:
#   ./scripts/ci/diagnose-and-fix.sh          # 仅诊断
#   ./scripts/ci/diagnose-and-fix.sh --fix    # 同时执行自动修复
#
# 本脚本由 Claude 在 CI 失败时执行，用于获取修复建议。

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PLUGIN_ROOT"

AUTO_FIX=false
if [ "$1" = "--fix" ]; then
  AUTO_FIX=true
fi

ISSUES_FOUND=0
FIXES_APPLIED=0

echo "🔧 CI 诊断与修复工具"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ================================
# 1. 版本同步检查
# ================================
check_version_sync() {
  echo "📋 [1/5] 版本同步检查..."

  local file_version=$(cat VERSION 2>/dev/null | tr -d '[:space:]')
  local json_version=$(grep '"version"' .claude-plugin/plugin.json | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

  if [ "$file_version" != "$json_version" ]; then
    echo "  ❌ VERSION ($file_version) 与 plugin.json ($json_version) 不一致"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))

    if [ "$AUTO_FIX" = true ]; then
      echo "  🔧 修复中: 将 plugin.json 更新为 $file_version..."
      sed -i.bak "s/\"version\": \"$json_version\"/\"version\": \"$file_version\"/" .claude-plugin/plugin.json
      rm -f .claude-plugin/plugin.json.bak
      FIXES_APPLIED=$((FIXES_APPLIED + 1))
      echo "  ✅ 修复完成"
    else
      echo "  💡 修复建议: 将 plugin.json 的 version 改为 \"$file_version\""
    fi
  else
    echo "  ✅ 已同步 (v$file_version)"
  fi
}

# ================================
# 2. 检查清单同步检查
# ================================
check_checklist_sync() {
  echo ""
  echo "📋 [2/5] 检查清单同步检查..."

  if ./scripts/ci/check-checklist-sync.sh >/dev/null 2>&1; then
    echo "  ✅ 已同步"
  else
    echo "  ❌ 脚本与命令的检查清单不一致"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))

    echo "  💡 修复建议:"
    echo "     1. 检查 scripts/*.sh 的 check_file/check_dir"
    echo "     2. 手动更新 commands/*.md 的检查清单"
    echo "     (不支持自动修复 - 需要手动确认)"
  fi
}

# ================================
# 3. 模板存在性检查
# ================================
check_templates() {
  echo ""
  echo "📋 [3/5] 模板存在性检查..."

  local missing=()
  local templates=(
    "templates/AGENTS.md.template"
    "templates/CLAUDE.md.template"
    "templates/Plans.md.template"
    "templates/.claude-code-harness-version.template"
    "templates/cursor/commands/start-session.md"
    "templates/cursor/commands/handoff-to-claude.md"
    "templates/cursor/commands/review-cc-work.md"
    "templates/rules/workflow.md.template"
    "templates/rules/coding-standards.md.template"
  )

  for t in "${templates[@]}"; do
    if [ ! -f "$t" ]; then
      missing+=("$t")
    fi
  done

  if [ ${#missing[@]} -eq 0 ]; then
    echo "  ✅ 所有模板均存在"
  else
    echo "  ❌ 缺失模板:"
    for m in "${missing[@]}"; do
      echo "     - $m"
    done
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo "  💡 修复建议: 创建缺失的文件"
  fi
}

# ================================
# 4. Hooks 完整性检查
# ================================
check_hooks() {
  echo ""
  echo "📋 [4/5] Hooks 完整性检查..."

  if ! jq empty hooks/hooks.json 2>/dev/null; then
    echo "  ❌ hooks.json 为无效的 JSON"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo "  💡 修复建议: 检查 hooks/hooks.json 的 JSON 语法"
    return
  fi

  local missing_scripts=()
  local script_refs=$(grep -oE 'scripts/[a-zA-Z0-9_.-]+' hooks/hooks.json 2>/dev/null || true)

  for ref in $script_refs; do
    if [ ! -f "$ref" ]; then
      missing_scripts+=("$ref")
    fi
  done

  if [ ${#missing_scripts[@]} -eq 0 ]; then
    echo "  ✅ Hooks 配置正常"
  else
    echo "  ❌ 引用的脚本缺失:"
    for s in "${missing_scripts[@]}"; do
      echo "     - $s"
    done
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo "  💡 修复建议: 创建缺失的脚本，或从 hooks.json 中删除引用"
  fi
}

# ================================
# 5. 发布元数据检查
# ================================
check_version_bump() {
  echo ""
  echo "📋 [5/5] 发布元数据检查..."

  local check_log
  check_log="$(mktemp)"

  if bash ./scripts/ci/check-version-bump.sh >"$check_log" 2>&1; then
    sed 's/^/  /' "$check_log"
    rm -f "$check_log"
    return
  fi

  sed 's/^/  /' "$check_log"
  rm -f "$check_log"

  if [ "$AUTO_FIX" = true ] && ! bash ./scripts/sync-version.sh check >/dev/null 2>&1; then
    echo "  🔧 修复中: 将 plugin.json 同步到 VERSION..."
    bash ./scripts/sync-version.sh sync
    FIXES_APPLIED=$((FIXES_APPLIED + 1))

    if bash ./scripts/ci/check-version-bump.sh >/dev/null 2>&1; then
      echo "  ✅ 已通过同步 plugin.json 恢复发布元数据的完整性"
      return
    fi
  fi

  ISSUES_FOUND=$((ISSUES_FOUND + 1))
  echo "  💡 修复方针:"
  echo "     - 普通 PR 不要修改 VERSION"
  echo "     - 仅在发布时同时更新 VERSION / plugin.json / CHANGELOG 发布条目"
}

# ================================
# 主执行流程
# ================================

check_version_sync
check_checklist_sync
check_templates
check_hooks
check_version_bump

# ================================
# 结果摘要
# ================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ISSUES_FOUND -eq 0 ]; then
  echo "✅ 未发现问题"
  exit 0
fi

echo "📊 结果摘要:"
echo "  - 检测到的问题: $ISSUES_FOUND 个"

if [ "$AUTO_FIX" = true ]; then
  echo "  - 自动修复: $FIXES_APPLIED 个"
  if [ $FIXES_APPLIED -gt 0 ]; then
    echo ""
    echo "💡 后续步骤:"
    echo "  1. 确认修复内容: git diff"
    echo "  2. 更新 CHANGELOG.md"
    echo "  3. 提交并推送"
  fi
else
  echo ""
  echo "💡 如需执行自动修复:"
  echo "  ./scripts/ci/diagnose-and-fix.sh --fix"
fi

exit 1
