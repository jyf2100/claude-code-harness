#!/bin/bash
# check-version-bump.sh
# release metadata policy check
#
# 目的:
# - 通常 PR 中不要求 VERSION bump
# - 只有在更新 VERSION 时，才确认 plugin.json / CHANGELOG release entry 是否齐全
#
# 使用方法:
# - PR 的情况: 设置 GITHUB_BASE_REF 环境变量
# - Push 的情况: 与前一个提交比较

set -euo pipefail

echo "🏷️ 发布元数据检查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "${GITHUB_BASE_REF:-}" ]; then
  BASE="origin/$GITHUB_BASE_REF"
  DIFF_TARGET="HEAD"
  echo "📌 PR 模式: 与 $BASE 比较"
elif [ -n "${GITHUB_EVENT_NAME:-}" ] && [ "$GITHUB_EVENT_NAME" = "push" ]; then
  BASE="HEAD~1"
  DIFF_TARGET="HEAD"
  echo "📌 Push 模式: 与前一个提交比较"
else
  BASE="origin/main"
  DIFF_TARGET=""
  echo "📌 本地模式: 与 $BASE 比较"
fi

if ! git rev-parse "$BASE" >/dev/null 2>&1; then
  echo "⚠️ 未找到比较目标 ($BASE)。跳过检查。"
  exit 0
fi

semver_gt() {
  local left="$1"
  local right="$2"
  local l_major=0 l_minor=0 l_patch=0
  local r_major=0 r_minor=0 r_patch=0

  IFS='.' read -r l_major l_minor l_patch <<< "$left"
  IFS='.' read -r r_major r_minor r_patch <<< "$right"

  for value in "$l_major" "$l_minor" "$l_patch" "$r_major" "$r_minor" "$r_patch"; do
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
      return 1
    fi
  done

  if ((10#$l_major > 10#$r_major)); then
    return 0
  fi
  if ((10#$l_major < 10#$r_major)); then
    return 1
  fi
  if ((10#$l_minor > 10#$r_minor)); then
    return 0
  fi
  if ((10#$l_minor < 10#$r_minor)); then
    return 1
  fi
  if ((10#$l_patch > 10#$r_patch)); then
    return 0
  fi

  return 1
}

echo ""
echo "🔍 检查变更文件..."

RELEASE_METADATA_FILES="VERSION .claude-plugin/plugin.json CHANGELOG.md"
if [ -n "$DIFF_TARGET" ]; then
  CHANGED_RELEASE_METADATA=$(git diff --name-only "$BASE" "$DIFF_TARGET" -- $RELEASE_METADATA_FILES 2>/dev/null | grep -v "^$" || true)
else
  CHANGED_RELEASE_METADATA=$(git diff --name-only "$BASE" -- $RELEASE_METADATA_FILES 2>/dev/null | grep -v "^$" || true)
fi

if [ -z "$CHANGED_RELEASE_METADATA" ]; then
  echo "  ✅ release metadata 未变更（作为通常 PR / 通常 push 允许）"
  exit 0
fi

echo "  📝 已变更的 release metadata:"
echo "$CHANGED_RELEASE_METADATA" | head -10 | while read -r file; do
  echo "     - $file"
done
CHANGED_COUNT=$(echo "$CHANGED_RELEASE_METADATA" | wc -l | tr -d ' ')
if [ "$CHANGED_COUNT" -gt 10 ]; then
  echo "     ... 其他 $((CHANGED_COUNT - 10)) 个文件"
fi

echo ""
echo "🔍 检查版本变更..."

CURRENT_VERSION=$(cat VERSION 2>/dev/null | tr -d '[:space:]')
BASE_VERSION=$(git show "$BASE:VERSION" 2>/dev/null | tr -d '[:space:]' || echo "")

echo "  基准: v${BASE_VERSION:-无}"
echo "  当前:   v${CURRENT_VERSION}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -z "$BASE_VERSION" ]; then
  echo "✅ 新项目（跳过 release metadata 检查）"
  exit 0
fi

if [ "$CURRENT_VERSION" = "$BASE_VERSION" ]; then
  echo "✅ VERSION 未变更。通常 PR / 通常 push 不需要 version bump。"

  if bash ./scripts/sync-version.sh check >/dev/null 2>&1; then
    echo "✅ plugin.json 也与 VERSION 一致。"
    exit 0
  fi

  echo "❌ VERSION 未变更但与 plugin.json 不一致。"
  bash ./scripts/sync-version.sh check
  exit 1
fi

if ! semver_gt "$CURRENT_VERSION" "$BASE_VERSION"; then
  echo "❌ VERSION 已更新，但不符合 SemVer 递增规则。"
  echo "   基准: $BASE_VERSION"
  echo "   当前:   $CURRENT_VERSION"
  exit 1
fi

echo "✅ 检测到发布用 VERSION 更新: $BASE_VERSION → $CURRENT_VERSION"

ERRORS=0

if bash ./scripts/sync-version.sh check >/dev/null 2>&1; then
  echo "✅ plugin.json 的 version 也一致。"
else
  echo "❌ plugin.json 的 version 与 VERSION 不一致。"
  bash ./scripts/sync-version.sh check || true
  ERRORS=$((ERRORS + 1))
fi

if grep -Eq "^## \[$CURRENT_VERSION\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" CHANGELOG.md; then
  echo "✅ CHANGELOG.md 中有 v$CURRENT_VERSION 的 release entry。"
else
  echo "❌ CHANGELOG.md 中没有 v$CURRENT_VERSION 的 release entry。"
  ERRORS=$((ERRORS + 1))
fi

if grep -Eq "^\[$CURRENT_VERSION\]: https://github.com/Chachamaru127/claude-code-harness/compare/v" CHANGELOG.md; then
  echo "✅ 有 CHANGELOG compare link。"
else
  echo "❌ 没有 CHANGELOG compare link。"
  ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "💡 修正建议:"
  echo "  - 通常 PR 中不要修改 VERSION"
  echo "  - 只有发布时才同时更新 VERSION / plugin.json / CHANGELOG release entry"
  exit 1
fi

echo "✅ release metadata 检查通过"
exit 0
