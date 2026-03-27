#!/bin/bash
# localize-rules.sh
# 根据项目结构本地化规则
#
# Usage: ./scripts/localize-rules.sh [--dry-run]
#
# 功能:
# - 根据项目分析结果调整 paths:
# - 添加语言特定规则
# - 保留现有自定义配置

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PLUGIN_PATH="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-${PLUGIN_PATH:-$DEFAULT_PLUGIN_PATH}}"
DRY_RUN=false

# 参数解析
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

# ================================
# 项目分析
# ================================
echo "🔍 正在分析项目结构..."

# 执行 analyze-project.sh
ANALYSIS=$("$PLUGIN_PATH/scripts/analyze-project.sh" 2>/dev/null || echo '{"languages":["unknown"],"source_dirs":["."],"test_info":[],"extensions":[]}')

# 从 JSON 中提取值
LANGUAGES=$(echo "$ANALYSIS" | jq -r '.languages[]' 2>/dev/null | tr '\n' ' ')
SOURCE_DIRS=$(echo "$ANALYSIS" | jq -r '.source_dirs[]' 2>/dev/null | tr '\n' ' ')
TEST_DIRS=$(echo "$ANALYSIS" | jq -r '.test_info.dirs[]' 2>/dev/null | tr '\n' ' ')
HAS_COLOCATED_TESTS=$(echo "$ANALYSIS" | jq -r '.test_info.has_colocated_tests // false' 2>/dev/null)

echo "  语言: $LANGUAGES"
echo "  源代码目录: $SOURCE_DIRS"

# ================================
# paths 模式生成
# ================================
generate_code_paths() {
  local paths=""
  local src_dirs=($SOURCE_DIRS)

  # 根据语言确定扩展名
  local extensions=""
  if [[ "$LANGUAGES" == *"typescript"* ]] || [[ "$LANGUAGES" == *"react"* ]]; then
    extensions="ts,tsx,js,jsx"
  elif [[ "$LANGUAGES" == *"javascript"* ]]; then
    extensions="js,jsx"
  elif [[ "$LANGUAGES" == *"python"* ]]; then
    extensions="py"
  elif [[ "$LANGUAGES" == *"go"* ]]; then
    extensions="go"
  elif [[ "$LANGUAGES" == *"rust"* ]]; then
    extensions="rs"
  elif [[ "$LANGUAGES" == *"ruby"* ]]; then
    extensions="rb"
  elif [[ "$LANGUAGES" == *"java"* ]] || [[ "$LANGUAGES" == *"kotlin"* ]]; then
    extensions="java,kt"
  else
    extensions="ts,tsx,js,jsx,py,rb,go,rs,java,kt"
  fi

  # 为每个源代码目录生成模式
  for dir in "${src_dirs[@]}"; do
    if [ "$dir" = "." ]; then
      paths+="**/*.{$extensions}, "
    else
      paths+="$dir/**/*.{$extensions}, "
    fi
  done

  # 移除末尾的逗号和空格
  echo "${paths%, }"
}

generate_test_paths() {
  local paths=""
  local test_dirs_arr=($TEST_DIRS)

  # 检测到的测试目录
  if [ ${#test_dirs_arr[@]} -gt 0 ]; then
    for dir in "${test_dirs_arr[@]}"; do
      paths+="$dir/**/*.*, "
    done
  else
    # 检查默认测试目录
    for dir in tests test __tests__ spec e2e; do
      if [ -d "$dir" ]; then
        paths+="$dir/**/*.*, "
      fi
    done
  fi

  # 同位测试 (colocated tests)
  if [ "$HAS_COLOCATED_TESTS" = "true" ]; then
    paths+="**/*.{test,spec}.{ts,tsx,js,jsx,py}, "
  fi

  # 默认值
  if [ -z "$paths" ]; then
    paths="**/*.{test,spec}.*, tests/**/*.*, test/**/*.*"
  fi

  echo "${paths%, }"
}

# ================================
# 规则文件生成
# ================================
CODE_PATHS=$(generate_code_paths)
TEST_PATHS=$(generate_test_paths)

echo ""
echo "📝 生成的 paths:"
echo "  代码: $CODE_PATHS"
echo "  测试: $TEST_PATHS"

if [ "$DRY_RUN" = true ]; then
  echo ""
  echo "🔍 [Dry Run] 不执行实际更改"
  exit 0
fi

# 确认 .claude/rules 目录存在
mkdir -p .claude/rules

# ================================
# coding-standards.md 本地化
# ================================
echo ""
echo "📁 正在本地化规则..."

# 从模板生成（如果文件存在则确认覆盖）
CODING_STANDARDS=".claude/rules/coding-standards.md"

# 添加语言特定部分
LANG_SPECIFIC=""
if [[ "$LANGUAGES" == *"typescript"* ]]; then
  LANG_SPECIFIC+="
## TypeScript 特定规则

- \`any\` 禁止使用（使用 \`unknown\` 代替）
- 返回值类型必须显式声明
- 启用严格空值检查
"
fi

if [[ "$LANGUAGES" == *"python"* ]]; then
  LANG_SPECIFIC+="
## Python 特定规则

- 遵循 PEP 8 风格指南
- 使用类型注解
- docstring 使用 Google 风格
"
fi

if [[ "$LANGUAGES" == *"react"* ]]; then
  LANG_SPECIFIC+="
## React 特定规则

- 使用函数组件
- 自定义 Hook 使用 \`use\` 前缀
- Props 类型定义必须
"
fi

# 生成 coding-standards.md
cat > "$CODING_STANDARDS" << EOF
---
description: 编码规范（仅适用于代码文件编辑）
paths: "$CODE_PATHS"
---

# Coding Standards

## 提交信息规范

| Prefix | 用途 | 示例 |
|--------|------|-----|
| \`feat:\` | 新功能 | \`feat: 添加用户认证\` |
| \`fix:\` | Bug 修复 | \`fix: 修复登录错误\` |
| \`docs:\` | 文档 | \`docs: 更新 README\` |
| \`refactor:\` | 重构 | \`refactor: 整理认证逻辑\` |
| \`test:\` | 测试 | \`test: 添加认证测试\` |
| \`chore:\` | 其他 | \`chore: 更新依赖\` |

## 代码风格

- ✅ 遵循现有代码风格
- ✅ 仅进行必要的最小修改
- ❌ 对未修改代码进行"改进"
- ❌ 未请求的重构
- ❌ 添加过多注释
$LANG_SPECIFIC
## Pull Request

- 标题: 简洁描述变更内容（50字符以内）
- 说明: 明确"做了什么"和"为什么"
- 必须记录测试方法
EOF

echo "  ✅ $CODING_STANDARDS"

# ================================
# testing.md 本地化
# ================================
TESTING_RULES=".claude/rules/testing.md"

cat > "$TESTING_RULES" << EOF
---
description: 测试文件创建/编辑规则
paths: "$TEST_PATHS"
---

# Testing Rules

## 测试创建原则

1. **边界测试**: 必须测试输入边界值
2. **正常/异常情况**: 覆盖两种情况
3. **独立性**: 每个测试不依赖其他测试
4. **清晰命名**: 测试名称应表明测试内容

## 测试命名规范

\`\`\`
describe('功能名称', () => {
  it('should 期望的行为 when 条件', () => {
    // ...
  });
});
\`\`\`

## 禁止事项

- ❌ 依赖实现内部细节的测试
- ❌ 实际连接外部服务（使用模拟）
- ❌ 测试间共享状态
EOF

echo "  ✅ $TESTING_RULES"

# ================================
# 完成
# ================================
echo ""
echo "✅ 规则本地化完成"
echo ""
echo "📋 生成的规则:"
echo "  - .claude/rules/coding-standards.md (paths: $CODE_PATHS)"
echo "  - .claude/rules/testing.md (paths: $TEST_PATHS)"
