#!/bin/bash
# setup-existing-project.sh
# 将 claude-code-harness 应用到现有项目的安装脚本
#
# Usage: ./scripts/setup-existing-project.sh [project_path]
#
# Cross-platform: Supports Windows (Git Bash/MSYS2/Cygwin/WSL), macOS, Linux

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(dirname "$SCRIPT_DIR")"

# Load cross-platform path utilities
if [ -f "$SCRIPT_DIR/path-utils.sh" ]; then
  # shellcheck source=./path-utils.sh
  source "$SCRIPT_DIR/path-utils.sh"
fi

PROJECT_PATH="${1:-.}"
# Normalize project path for cross-platform compatibility
if type normalize_path &>/dev/null; then
  PROJECT_PATH="$(normalize_path "$PROJECT_PATH")"
fi

# 彩色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Claude harness - 现有项目应用${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ================================
# Step 1: 前置条件检查
# ================================

echo -e "${BLUE}[1/6] 前置条件检查${NC}"
echo "----------------------------------------"

# 确认项目目录存在
if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}✗ 未找到项目目录: $PROJECT_PATH${NC}"
    exit 1
fi

cd "$PROJECT_PATH" || {
    echo -e "${RED}✗ 无法进入目录: $PROJECT_PATH${NC}"
    exit 1
}
PROJECT_PATH=$(pwd)
echo -e "${GREEN}✓${NC} 项目目录: $PROJECT_PATH"

# 安装元信息
PROJECT_NAME="$(basename "$PROJECT_PATH")"
SETUP_DATE_ISO="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
SETUP_DATE_SHORT="$(date +"%Y-%m-%d")"
HARNESS_VERSION="unknown"
if [ -f "$HARNESS_ROOT/VERSION" ]; then
    HARNESS_VERSION="$(cat "$HARNESS_ROOT/VERSION" | tr -d ' \n\r')"
fi

# 模板变量（稍后可能被 analyze-project 结果覆盖）
LANGUAGE="unknown"

# 检查是否为 Git 仓库
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}⚠${NC}  不是 Git 仓库"
    read -p "是否初始化 Git 仓库？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git init
        echo -e "${GREEN}✓${NC} 已初始化 Git 仓库"
    fi
else
    echo -e "${GREEN}✓${NC} 是 Git 仓库"
fi

# 检查未提交的更改
if [ -d ".git" ]; then
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        echo -e "${YELLOW}⚠${NC}  有未提交的更改"
        echo ""
        echo -e "${YELLOW}建议: 请在安装前先提交${NC}"
        echo ""
        read -p "是否继续？ (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "安装已取消"
            exit 0
        fi
    else
        echo -e "${GREEN}✓${NC} 工作区干净"
    fi
fi

echo ""

# ================================
# Step 2: 搜索现有文档
# ================================

echo -e "${BLUE}[2/6] 搜索现有文档${NC}"
echo "----------------------------------------"

FOUND_DOCS=()
DOC_PATTERNS=(
    "README.md"
    "SPEC.md"
    "SPECIFICATION.md"
    "仕様書.md"
    "要件定義.md"
    "docs/spec.md"
    "docs/specification.md"
    "docs/requirements.md"
    "docs/proposal.md"
    "docs/提案書.md"
    "Plans.md"
    "PLAN.md"
    "計画.md"
)

for pattern in "${DOC_PATTERNS[@]}"; do
    if [ -f "$pattern" ]; then
        FOUND_DOCS+=("$pattern")
        echo -e "${GREEN}✓${NC} 发现: $pattern"
    fi
done

if [ ${#FOUND_DOCS[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠${NC}  未找到现有文档"
else
    echo ""
    echo -e "${GREEN}发现 ${#FOUND_DOCS[@]} 个文档${NC}"
fi

echo ""

# ================================
# Step 3: 项目分析
# ================================

echo -e "${BLUE}[3/6] 项目分析${NC}"
echo "----------------------------------------"

# 执行 analyze-project.sh
if [ -f "$HARNESS_ROOT/scripts/analyze-project.sh" ]; then
    ANALYSIS_RESULT=$("$HARNESS_ROOT/scripts/analyze-project.sh" "$PROJECT_PATH" 2>/dev/null || echo "{}")

    # 显示技术栈（analyze-project.sh 输出: technologies/frameworks/testing）
    if command -v jq &> /dev/null; then
        TECHNOLOGIES=$(echo "$ANALYSIS_RESULT" | jq -r '.technologies[]?' 2>/dev/null || true)
        FRAMEWORKS=$(echo "$ANALYSIS_RESULT" | jq -r '.frameworks[]?' 2>/dev/null || true)
        TESTING=$(echo "$ANALYSIS_RESULT" | jq -r '.testing[]?' 2>/dev/null || true)

        # 简易估算 LANGUAGE（用于模板 {{LANGUAGE}} 变量）
        LANGUAGE=$(echo "$ANALYSIS_RESULT" | jq -r '.technologies[0] // "unknown"' 2>/dev/null || echo "unknown")

        if [ -n "${TECHNOLOGIES}${FRAMEWORKS}${TESTING}" ]; then
            echo "检测结果:"
            if [ -n "$TECHNOLOGIES" ]; then
                echo "  technologies:"
                echo "$TECHNOLOGIES" | while read -r tech; do
                    [ -n "$tech" ] && echo -e "    ${GREEN}•${NC} $tech"
                done
            fi
            if [ -n "$FRAMEWORKS" ]; then
                echo "  frameworks:"
                echo "$FRAMEWORKS" | while read -r fw; do
                    [ -n "$fw" ] && echo -e "    ${GREEN}•${NC} $fw"
                done
            fi
            if [ -n "$TESTING" ]; then
                echo "  testing:"
                echo "$TESTING" | while read -r t; do
                    [ -n "$t" ] && echo -e "    ${GREEN}•${NC} $t"
                done
            fi
        fi
    fi
else
    echo -e "${YELLOW}⚠${NC}  未找到项目分析脚本"
fi

echo ""

# ================================
# Step 4: 创建 Harness 配置文件
# ================================

echo -e "${BLUE}[4/6] 创建 Harness 配置文件${NC}"
echo "----------------------------------------"

# 创建 .claude-code-harness 目录
mkdir -p .claude-code-harness

# 创建包含现有文档引用的配置文件（如已存在则不覆盖）
CONFIG_PATH=".claude-code-harness/config.json"
if [ -f "$CONFIG_PATH" ]; then
    echo -e "${YELLOW}⚠${NC}  配置文件已存在（不覆盖）: $CONFIG_PATH"
else
    cat > "$CONFIG_PATH" << EOF
{
  "version": "$HARNESS_VERSION",
  "setup_date": "$SETUP_DATE_ISO",
  "project_type": "existing",
  "existing_documents": [
$(
    for doc in "${FOUND_DOCS[@]}"; do
        echo "    \"$doc\","
    done | sed '$ s/,$//'
)
  ],
  "harness_path": "$HARNESS_ROOT"
}
EOF

    echo -e "${GREEN}✓${NC} 已创建配置文件: $CONFIG_PATH"
fi

# 创建现有文档摘要（如已存在则不覆盖）
if [ ${#FOUND_DOCS[@]} -gt 0 ]; then
    SUMMARY_PATH=".claude-code-harness/existing-docs-summary.md"
    if [ -f "$SUMMARY_PATH" ]; then
        echo -e "${YELLOW}⚠${NC}  现有文档摘要已存在（不覆盖）: $SUMMARY_PATH"
    else
        cat > "$SUMMARY_PATH" << EOF
# 现有文档一览

本项目包含以下现有文档：

EOF

        for doc in "${FOUND_DOCS[@]}"; do
            echo "## $doc" >> "$SUMMARY_PATH"
            echo "" >> "$SUMMARY_PATH"
            echo '```' >> "$SUMMARY_PATH"
            head -20 "$doc" >> "$SUMMARY_PATH"
            echo '```' >> "$SUMMARY_PATH"
            echo "" >> "$SUMMARY_PATH"
        done

        echo -e "${GREEN}✓${NC} 已创建现有文档摘要: $SUMMARY_PATH"
    fi
fi

echo ""

# ================================
# Step 5: 创建 Project Rules
# ================================

echo -e "${BLUE}[5/6] 创建 Project Rules / 工作流文件${NC}"
echo "----------------------------------------"

# 创建 .claude/rules 目录
mkdir -p .claude/rules

# 模板简易渲染（{{PROJECT_NAME}}/{{DATE}}/{{LANGUAGE}}）
escape_sed_repl() {
    # 作为 sed 替换字符串安全化（转义 \ / & |）
    # 先转义反斜杠，再转义其他字符
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/[\/&|]/\\&/g'
}

render_template_if_missing() {
    local template_path="$1"
    local dest_path="$2"
    local label="$3"

    if [ -f "$dest_path" ]; then
        echo -e "${GREEN}✓${NC} ${label}: 已存在（跳过）"
        return 0
    fi
    if [ ! -f "$template_path" ]; then
        echo -e "${YELLOW}⚠${NC} ${label}: 未找到模板: $template_path"
        return 0
    fi
    # 支持嵌套路径
    mkdir -p "$(dirname "$dest_path")" 2>/dev/null || true

    local project_esc date_esc lang_esc
    project_esc=$(escape_sed_repl "$PROJECT_NAME")
    date_esc=$(escape_sed_repl "$SETUP_DATE_SHORT")
    lang_esc=$(escape_sed_repl "$LANGUAGE")

    sed \
        -e "s|{{PROJECT_NAME}}|$project_esc|g" \
        -e "s|{{DATE}}|$date_esc|g" \
        -e "s|{{LANGUAGE}}|$lang_esc|g" \
        "$template_path" > "$dest_path"

    echo -e "${GREEN}✓${NC} 已创建 ${label}: $dest_path"
}

# 为现有项目创建 Project Rules（如已存在则不覆盖）
RULES_PATH=".claude/rules/harness.md"
if [ -f "$RULES_PATH" ]; then
    echo -e "${YELLOW}⚠${NC}  Project Rules 已存在（不覆盖）: $RULES_PATH"
else
    cat > "$RULES_PATH" << EOF
# Claude harness - Project Rules

本项目使用 **claude-code-harness**。

## 应用到现有项目

本项目是在现有代码库上应用 claude-code-harness 的结果。

### 尊重现有资产

1. **优先使用现有文档**
   - 如有现有的规格书、README、计划书，请最优先参考它们
   - `.claude-code-harness/existing-docs-summary.md` 中有现有文档一览

2. **保持现有代码风格**
   - 尊重现有的编码规范、格式设置
   - 新代码应与现有代码风格保持一致

3. **渐进式改进**
   - 不要一次性全部重写
   - 注意不要破坏现有功能

## 可用命令

### 核心（Plan → Work → Review）
- \`/plan-with-agent\` - 项目计划的创建/更新（考虑现有文档）
- \`/work\` - 功能实现（支持并行执行，保持与现有代码的一致性）
- \`/harness-review\` - 代码审查

### 质量/运维
- \`/validate\` - 交付前验证
- \`/cleanup\` - Plans.md 等的自动整理
- \`/sync-status\` - 进度确认 → 建议下一步操作
- \`/refactor\` - 安全的重构

### 实现支持
- \`/crud\` - CRUD 功能生成
- \`/ci-setup\` - CI/CD 设置

### 技能（对话中自动启动）
- \`component\` - "创建英雄区" → UI 组件实现
- \`auth\` - "添加登录功能" → 认证实现
- \`payments\` - "用 Stripe 做支付" → 支付集成
- \`deploy-setup\` - "想部署到 Vercel" → 部署设置
- \`analytics\` - "加入访问分析" → 分析集成
- \`auto-fix\` - "修复问题" → 自动修复

## 现有项目注意事项

1. **务必确认现有规格书**
   - 执行命令前先阅读现有文档
   - 如有矛盾请确认

2. **渐进式应用**
   - 从小功能开始
   - 频繁进行功能验证

3. **版本控制**
   - 频繁提交
   - 大改动前创建分支

## 安装信息

- 安装日期: $SETUP_DATE_SHORT
- Harness 版本: $HARNESS_VERSION
- 配置文件: \`.claude-code-harness/config.json\`
EOF

    echo -e "${GREEN}✓${NC} 已创建 Project Rules: $RULES_PATH"
fi

echo ""

# 根据需要创建工作流文件（AGENTS/CLAUDE/Plans）（如已存在则不覆盖）
TEMPLATE_DIR="$HARNESS_ROOT/templates"
render_template_if_missing "$TEMPLATE_DIR/AGENTS.md.template" "AGENTS.md" "AGENTS.md"
render_template_if_missing "$TEMPLATE_DIR/CLAUDE.md.template" "CLAUDE.md" "CLAUDE.md"
render_template_if_missing "$TEMPLATE_DIR/Plans.md.template" "Plans.md" "Plans.md"

echo ""

# ================================
# Step 5.5: 初始化项目内存（SSOT）
# ================================
echo -e "${BLUE}[5.5/6] 初始化项目内存（SSOT）${NC}"
echo "----------------------------------------"

# decisions/patterns 推荐作为 SSOT 共享。session-log 适用于本地使用。
mkdir -p .claude/memory
render_template_if_missing "$TEMPLATE_DIR/memory/decisions.md.template" ".claude/memory/decisions.md" "decisions.md (SSOT)"
render_template_if_missing "$TEMPLATE_DIR/memory/patterns.md.template" ".claude/memory/patterns.md" "patterns.md (SSOT)"
render_template_if_missing "$TEMPLATE_DIR/memory/session-log.md.template" ".claude/memory/session-log.md" "session-log.md"

echo ""

# ================================
# Step 6: 安装完成
# ================================

echo -e "${BLUE}[6/6] 安装完成${NC}"
echo "----------------------------------------"

echo ""
echo -e "${GREEN}✅ 安装已完成！${NC}"
echo ""
echo "下一步:"
echo ""
echo "1. 确认现有文档:"
echo -e "   ${BLUE}cat .claude-code-harness/existing-docs-summary.md${NC}"
echo ""
echo "2. 用 Claude Code 打开项目:"
echo -e "   ${BLUE}cd $PROJECT_PATH${NC}"
echo -e "   ${BLUE}claude${NC}"
echo -e "   ${YELLOW}（如未安装插件，从本地直接读取此 Harness）${NC}"
echo -e "   ${BLUE}claude --plugin-dir \"$HARNESS_ROOT\"${NC}"
echo ""
echo "3. 确认现有规格后更新计划:"
echo -e "   ${BLUE}/plan${NC}"
echo ""
echo "4. 从小功能开始实现:"
echo -e "   ${BLUE}/work${NC}"
echo ""
echo "5. 频繁进行审查:"
echo -e "   ${BLUE}/harness-review${NC}"
echo ""
echo "6. （可选）启用 Cursor 集成:"
echo -e "   ${BLUE}/setup-cursor${NC}"
echo ""

# 添加到 .gitignore
if [ -f ".gitignore" ]; then
    if ! grep -q ".claude-code-harness" .gitignore; then
        echo "" >> .gitignore
        echo "# Claude harness" >> .gitignore
        echo ".claude-code-harness/" >> .gitignore
        echo -e "${GREEN}✓${NC} 已添加到 .gitignore"
    fi

    # 内存使用建议（不重复追加）
    if ! grep -q "Claude Memory Policy" .gitignore; then
        echo "" >> .gitignore
        echo "# Claude Memory Policy (recommended)" >> .gitignore
        echo "# - Keep (shared SSOT): .claude/memory/decisions.md, .claude/memory/patterns.md" >> .gitignore
        echo "# - Ignore (local): .claude/state/, session-log.md, context.json, archives" >> .gitignore
        echo ".claude/state/" >> .gitignore
        echo ".claude/memory/session-log.md" >> .gitignore
        echo ".claude/memory/context.json" >> .gitignore
        echo ".claude/memory/archive/" >> .gitignore
        echo -e "${GREEN}✓${NC} 已将内存使用建议追加到 .gitignore（请根据需要调整）"
    fi
fi

echo ""
echo -e "${YELLOW}⚠${NC}  重要: 建议提交更改"
echo ""
