#!/bin/bash
# validate-release-notes.sh
# GitHub Release Notes 格式验证脚本
# 使用方法: ./scripts/validate-release-notes.sh [tag]
# 示例: ./scripts/validate-release-notes.sh v2.10.0

set -e

TAG="${1:-}"
ERRORS=0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色

log_error() {
    echo -e "${RED}❌ $1${NC}"
    ERRORS=$((ERRORS + 1))
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_ok() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 如果未指定 tag 则检查最新版本
if [ -z "$TAG" ]; then
    TAG=$(gh release list --limit 1 --json tagName -q '.[0].tagName')
    echo "📋 Checking latest release: $TAG"
fi

# 获取 Release Notes
NOTES=$(gh release view "$TAG" --json body -q '.body' 2>/dev/null)

if [ -z "$NOTES" ]; then
    log_error "找不到版本: $TAG"
    exit 1
fi

echo ""
echo "🔍 Release Notes 验证: $TAG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. 标题检查
if echo "$NOTES" | grep -qE "^## 🎯 (对你来说有什么变化|What's Changed for You)"; then
    # 中英混用检查
    if echo "$NOTES" | grep -qE "^## 🎯 .*\|"; then
        log_error "标题存在中英混用（使用 | 分隔）"
    else
        log_ok "标题: 格式正确"
    fi
else
    log_error "缺少标题: 🎯 对你来说有什么变化"
fi

# 2. Before → After 表格检查
if echo "$NOTES" | grep -q "Before → After"; then
    log_ok "Before → After 表格: 存在"
else
    log_error "缺少 Before → After 表格"
fi

# 3. 页脚检查
if echo "$NOTES" | grep -q "Generated with \[Claude Code\]"; then
    log_ok "页脚: 存在"
else
    log_error "缺少页脚: 🤖 Generated with [Claude Code](...)"
fi

# 4. 中英混用检查（详细）
# 英文标题模式
if echo "$NOTES" | grep -qE "^## (What's New|What's Changed|Summary)$"; then
    log_warn "使用了英文标题（推荐使用中文）"
fi

# 中英文说明并列存在
if echo "$NOTES" | grep -qE "^\*\*.+\*\*$" | grep -q "[a-zA-Z]" && echo "$NOTES" | grep -qE "^\*\*.+\*\*$" | grep -q "[\u4e00-\u9fa5]"; then
    log_warn "说明文可能存在中英混用"
fi

# 5. 章节检查
for section in "Added" "Changed" "Fixed" "Security"; do
    if echo "$NOTES" | grep -q "^## $section"; then
        log_ok "章节: $section 存在"
    fi
done

# 6. 粗体摘要检查
if echo "$NOTES" | head -10 | grep -qE "^\*\*.+\*\*$"; then
    log_ok "粗体摘要: 存在"
else
    log_warn "未找到粗体摘要（用一行说明变更的价值）"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}验证结果: $ERRORS 个错误${NC}"
    echo ""
    echo "📖 参考: .claude/rules/github-release.md"
    exit 1
else
    echo -e "${GREEN}验证结果: 所有检查均已通过${NC}"
    exit 0
fi
