#!/bin/bash
# check-consistency.sh
# 插件一致性检查
#
# Usage: ./scripts/ci/check-consistency.sh
# Exit codes:
#   0 - All checks passed
#   1 - Inconsistencies found

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ERRORS=0

echo "🔍 claude-code-harness 一致性检查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ================================
# 1. 模板文件存在性检查
# ================================
echo ""
echo "📁 [1/12] 模板文件存在性检查..."

REQUIRED_TEMPLATES=(
  "templates/AGENTS.md.template"
  "templates/CLAUDE.md.template"
  "templates/Plans.md.template"
  "templates/.claude-code-harness-version.template"
  "templates/.claude-code-harness.config.yaml.template"
  "templates/cursor/commands/start-session.md"
  "templates/cursor/commands/project-overview.md"
  "templates/cursor/commands/plan-with-cc.md"
  "templates/cursor/commands/handoff-to-claude.md"
  "templates/cursor/commands/review-cc-work.md"
  "templates/claude/settings.security.json.template"
  "templates/claude/settings.local.json.template"
  "templates/rules/workflow.md.template"
  "templates/rules/coding-standards.md.template"
  "templates/rules/plans-management.md.template"
  "templates/rules/testing.md.template"
  "templates/rules/ui-debugging-agent-browser.md.template"
)

for template in "${REQUIRED_TEMPLATES[@]}"; do
  if [ ! -f "$PLUGIN_ROOT/$template" ]; then
    echo "  ❌ 缺失: $template"
    ERRORS=$((ERRORS + 1))
  else
    echo "  ✅ $template"
  fi
done

# ================================
# 2. 命令 ↔ 技能 的一致性
# ================================
echo ""
echo "🔗 [2/12] 命令 ↔ 技能 的引用一致性..."

# 检查命令引用的模板是否存在
check_command_references() {
  local cmd_file="$1"
  local cmd_name=$(basename "$cmd_file" .md)

  # 提取对模板的引用
  local refs=$(grep -oE 'templates/[a-zA-Z0-9/_.-]+' "$cmd_file" 2>/dev/null || true)

  for ref in $refs; do
    if [ ! -e "$PLUGIN_ROOT/$ref" ] && [ ! -e "$PLUGIN_ROOT/${ref}.template" ]; then
      echo "  ❌ $cmd_name: 引用目标不存在: $ref"
      ERRORS=$((ERRORS + 1))
    fi
  done
}

for cmd in "$PLUGIN_ROOT/commands"/*.md; do
  check_command_references "$cmd"
done
echo "  ✅ 命令引用检查完成"

# ================================
# 3. 版本号一致性
# ================================
echo ""
echo "🏷️ [3/12] 版本号一致性..."

VERSION_FILE="$PLUGIN_ROOT/VERSION"
PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"

if [ -f "$VERSION_FILE" ] && [ -f "$PLUGIN_JSON" ]; then
  FILE_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
  JSON_VERSION=$(grep '"version"' "$PLUGIN_JSON" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

  if [ "$FILE_VERSION" != "$JSON_VERSION" ]; then
    echo "  ❌ 版本不一致: VERSION=$FILE_VERSION, plugin.json=$JSON_VERSION"
    ERRORS=$((ERRORS + 1))
  else
    echo "  ✅ VERSION 与 plugin.json 一致: $FILE_VERSION"
  fi
fi

LATEST_RELEASE_URL="https://github.com/Chachamaru127/claude-code-harness/releases/latest"
LATEST_RELEASE_BADGE="https://img.shields.io/github/v/release/Chachamaru127/claude-code-harness?display_name=tag&sort=semver"

# ================================
# 4. 技能预期文件结构
# ================================
echo ""
echo "📋 [4/12] 技能定义的预期文件结构..."

# 2agent 配置已整合到 harness-setup (v3)
# 确认 skills-v3/harness-setup/SKILL.md 的存在
SETUP_V3="$PLUGIN_ROOT/skills-v3/harness-setup/SKILL.md"
if [ -f "$SETUP_V3" ]; then
  echo "  ✅ skills-v3/harness-setup/SKILL.md 存在（包含 2agent 配置）"
else
  echo "  ❌ skills-v3/harness-setup/SKILL.md 未找到"
  ERRORS=$((ERRORS + 1))
fi

# ================================
# 5. Hooks 配置一致性
# ================================
echo ""
echo "🪝 [5/12] Hooks 配置一致性..."

HOOKS_JSON="$PLUGIN_ROOT/hooks/hooks.json"
if [ -f "$HOOKS_JSON" ]; then
  # 检查 hooks.json 内的脚本引用
  SCRIPT_REFS=$(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/scripts/[a-zA-Z0-9_./-]+' "$HOOKS_JSON" 2>/dev/null || true)

  for ref in $SCRIPT_REFS; do
    script_name=$(echo "$ref" | sed 's|\${CLAUDE_PLUGIN_ROOT}/scripts/||')
    if [ ! -f "$PLUGIN_ROOT/scripts/$script_name" ]; then
      echo "  ❌ hooks.json: 脚本不存在: scripts/$script_name"
      ERRORS=$((ERRORS + 1))
    else
      echo "  ✅ scripts/$script_name"
    fi
  done
fi

# ================================
# 6. /start-task 废弃回归检查
# ================================
echo ""
echo "🚫 [6/12] /start-task 废弃回归检查..."

# 运维导线文件（排除 CHANGELOG 等历史记录）
START_TASK_TARGETS=(
  "commands/"
  "skills/"
  "workflows/"
  "profiles/"
  "templates/"
  "scripts/"
  "DEVELOPMENT_FLOW_GUIDE.md"
  "IMPLEMENTATION_GUIDE.md"
  "README.md"
)

START_TASK_FOUND=0
for target in "${START_TASK_TARGETS[@]}"; do
  if [ -e "$PLUGIN_ROOT/$target" ]; then
    # 搜索对 /start-task 的引用（排除历史/说明上下文）
    # 排除模式: 删除/废弃/Removed（历史）, 相当/整合/原有/吸收（迁移说明）, 改善/区分使用（CHANGELOG）
    REFS=$(grep -rn "/start-task" "$PLUGIN_ROOT/$target" 2>/dev/null \
      | grep -v "删除" | grep -v "废弃" | grep -v "Removed" \
      | grep -v "相当" | grep -v "整合" | grep -v "原有" | grep -v "吸收" \
      | grep -v "改善" | grep -v "区分使用" | grep -v "CHANGELOG" \
      | grep -v "check-consistency.sh" \
      || true)
    if [ -n "$REFS" ]; then
      echo "  ❌ /start-task 引用残留: $target"
      echo "$REFS" | head -3 | sed 's/^/      /'
      START_TASK_FOUND=$((START_TASK_FOUND + 1))
    fi
  fi
done

if [ $START_TASK_FOUND -eq 0 ]; then
  echo "  ✅ /start-task 引用不存在（运维导线）"
else
  ERRORS=$((ERRORS + START_TASK_FOUND))
fi

# ================================
# 7. docs/ 规范化回归检查
# ================================
echo ""
echo "📁 [7/12] docs/ 规范化回归检查..."

# 检查 proposal.md / priority_matrix.md 的根目录引用
DOCS_TARGETS=(
  "commands/"
  "skills/"
)

DOCS_ISSUES=0
for target in "${DOCS_TARGETS[@]}"; do
  if [ -d "$PLUGIN_ROOT/$target" ]; then
    # 搜索对根目录下 proposal.md / technical-spec.md / priority_matrix.md 的引用
    # 检测没有 docs/ 前缀的情况
    REFS=$(grep -rn "proposal.md\|technical-spec.md\|priority_matrix.md" "$PLUGIN_ROOT/$target" 2>/dev/null | grep -v "docs/" | grep -v "\.template" || true)
    if [ -n "$REFS" ]; then
      echo "  ❌ 无 docs/ 前缀的引用: $target"
      echo "$REFS" | head -3 | sed 's/^/      /'
      DOCS_ISSUES=$((DOCS_ISSUES + 1))
    fi
  fi
done

if [ $DOCS_ISSUES -eq 0 ]; then
  echo "  ✅ docs/ 规范化OK"
else
  ERRORS=$((ERRORS + DOCS_ISSUES))
fi

# ================================
# 8. bypassPermissions 前提运维回归检查
# ================================
echo ""
echo "🔓 [8/12] bypassPermissions 前提运维回归检查..."

BYPASS_ISSUES=0

# Check 1: disableBypassPermissionsMode 未返回到 templates
SECURITY_TEMPLATE="$PLUGIN_ROOT/templates/claude/settings.security.json.template"
if [ -f "$SECURITY_TEMPLATE" ]; then
  if grep -q "disableBypassPermissionsMode" "$SECURITY_TEMPLATE"; then
    echo "  ❌ settings.security.json.template 中 disableBypassPermissionsMode 残留"
    echo "      由于 bypassPermissions 前提运维，请删除此设置"
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  else
    echo "  ✅ disableBypassPermissionsMode 不存在"
  fi
fi

# Check 2: permissions.ask 中不包含 Edit / Write
if [ -f "$SECURITY_TEMPLATE" ]; then
  if grep -q '"Edit' "$SECURITY_TEMPLATE" || grep -q '"Write' "$SECURITY_TEMPLATE"; then
    echo "  ❌ settings.security.json.template 的 ask 中包含 Edit/Write"
    echo "      由于 bypassPermissions 前提运维，请不要将 Edit/Write 放入 ask"
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  else
    echo "  ✅ ask 中无 Edit/Write"
  fi
fi

# Check 2.5: Bash 权限语法回归检查（前缀必须使用 :*）
if [ -f "$SECURITY_TEMPLATE" ]; then
  # Portable regex: use [(] / [*] instead of escaping to avoid BSD grep issues.
  if grep -nEq 'Bash[(][^)]*[^:][*]' "$SECURITY_TEMPLATE"; then
    echo "  ❌ settings.security.json.template 中包含无效的 Bash 权限语法"
    echo "      前缀匹配请使用 :*（例如: Bash(git status:*)）"
    grep -nE 'Bash[(][^)]*[^:][*]' "$SECURITY_TEMPLATE" | head -3 | sed 's/^/      /'
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  else
    echo "  ✅ Bash 权限语法OK (:*)"
  fi
fi

# Check 3: settings.local.json.template 存在，且 defaultMode 是文档化的 permission mode
# NOTE: shipped default 保持 bypassPermissions，Auto Mode 作为 teammate 执行路径的 follow-up rollout 处理
LOCAL_TEMPLATE="$PLUGIN_ROOT/templates/claude/settings.local.json.template"
if [ -f "$LOCAL_TEMPLATE" ]; then
  if grep -q '"defaultMode"[[:space:]]*:[[:space:]]*"bypassPermissions"' "$LOCAL_TEMPLATE"; then
    mode_val=$(grep '"defaultMode"' "$LOCAL_TEMPLATE" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    echo "  ✅ settings.local.json.template: defaultMode=${mode_val}"
  else
    echo "  ❌ settings.local.json.template 中没有 defaultMode=bypassPermissions"
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  fi
else
  echo "  ❌ settings.local.json.template 不存在"
  BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
fi

if [ $BYPASS_ISSUES -eq 0 ]; then
  echo "  ✅ bypassPermissions 前提运维OK"
else
  ERRORS=$((ERRORS + BYPASS_ISSUES))
fi

# ================================
# 9. ccp-* 技能废弃回归检查
# ================================
echo ""
echo "🚫 [9/12] ccp-* 技能废弃回归检查..."

CCP_ISSUES=0

# Check 1: skills 的 name: 中不包含 ccp-
CCP_NAMES=$(grep -rn "^name: ccp-" "$PLUGIN_ROOT/skills/" 2>/dev/null || true)
if [ -n "$CCP_NAMES" ]; then
  echo "  ❌ skills 中 name: ccp-* 残留"
  echo "$CCP_NAMES" | head -3 | sed 's/^/      /'
  CCP_ISSUES=$((CCP_ISSUES + 1))
else
  echo "  ✅ skills 中无 name: ccp-*"
fi

# Check 2: workflows 的 skill: 中不包含 ccp-
CCP_WORKFLOWS=$(grep -rn "skill: ccp-" "$PLUGIN_ROOT/workflows/" 2>/dev/null || true)
if [ -n "$CCP_WORKFLOWS" ]; then
  echo "  ❌ workflows 中 skill: ccp-* 残留"
  echo "$CCP_WORKFLOWS" | head -3 | sed 's/^/      /'
  CCP_ISSUES=$((CCP_ISSUES + 1))
else
  echo "  ✅ workflows 中无 skill: ccp-*"
fi

# Check 3: ccp-* 目录未残留
CCP_DIRS=$(find "$PLUGIN_ROOT/skills" -type d -name "ccp-*" 2>/dev/null || true)
if [ -n "$CCP_DIRS" ]; then
  echo "  ❌ ccp-* 目录残留"
  echo "$CCP_DIRS" | head -3 | sed 's/^/      /'
  CCP_ISSUES=$((CCP_ISSUES + 1))
else
  echo "  ✅ ccp-* 目录不存在"
fi

if [ $CCP_ISSUES -eq 0 ]; then
  echo "  ✅ ccp-* 技能废弃OK"
else
  ERRORS=$((ERRORS + CCP_ISSUES))
fi

# ================================
# 10. v3 技能 Mirror 检查
# ================================
echo ""
echo "📦 [10/12] v3 技能 Mirror 检查..."

V3_SKILLS_DIR="$PLUGIN_ROOT/skills-v3"
CLAUDE_MIRROR="$PLUGIN_ROOT/skills"
CODEX_MIRROR="$PLUGIN_ROOT/codex/.codex/skills"
OPENCODE_MIRROR="$PLUGIN_ROOT/opencode/skills"
MIRROR_ISSUES=0

# v3 核心技能（5动词 harness- 前缀）的 mirror 检查
V3_CORE_SKILLS="harness-plan harness-work harness-review harness-release harness-setup"
V3_AUX_SKILLS="harness-sync"

if [ -d "$V3_SKILLS_DIR" ]; then
  for skill in $V3_CORE_SKILLS; do
    src="$V3_SKILLS_DIR/$skill"
    for mirror_name in claude codex opencode; do
      case "$mirror_name" in
        claude) mirror_root="$CLAUDE_MIRROR" ;;
        codex) mirror_root="$CODEX_MIRROR" ;;
        opencode) mirror_root="$OPENCODE_MIRROR" ;;
      esac

      if [ ! -d "$mirror_root" ]; then
        continue
      fi

      mirror_path="$mirror_root/$skill"
      if [ ! -d "$mirror_path" ]; then
        echo "  ❌ $mirror_name: $skill 不作为目录存在"
        MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
        continue
      fi

      if [ -L "$mirror_path" ]; then
        echo "  ❌ $mirror_name: $skill 仍然是 symlink"
        MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
        continue
      fi

      if diff -qr "$src" "$mirror_path" >/dev/null 2>&1; then
        echo "  ✅ $mirror_name: $skill mirror is in sync"
      else
        echo "  ❌ $mirror_name: $skill mirror 与 skills-v3 不一致"
        MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
      fi
    done
  done

  for skill in $V3_AUX_SKILLS; do
    src="$V3_SKILLS_DIR/$skill"
    for mirror_name in claude codex opencode; do
      case "$mirror_name" in
        claude) mirror_root="$CLAUDE_MIRROR" ;;
        codex) mirror_root="$CODEX_MIRROR" ;;
        opencode) mirror_root="$OPENCODE_MIRROR" ;;
      esac

      if [ ! -d "$mirror_root" ]; then
        continue
      fi

      mirror_path="$mirror_root/$skill"
      if [ ! -d "$mirror_path" ]; then
        echo "  ❌ $mirror_name: $skill 不作为目录存在"
        MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
        continue
      fi

      if [ -L "$mirror_path" ]; then
        echo "  ❌ $mirror_name: $skill 仍然是 symlink"
        MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
        continue
      fi

      if diff -qr "$src" "$mirror_path" >/dev/null 2>&1; then
        echo "  ✅ $mirror_name: $skill mirror is in sync"
      else
        echo "  ❌ $mirror_name: $skill mirror drifted from skills-v3/$skill"
        MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
      fi
    done
  done
else
  echo "  ⚠️ skills-v3/ 不存在（跳过）"
fi

if [ $MIRROR_ISSUES -gt 0 ]; then
  ERRORS=$((ERRORS + MIRROR_ISSUES))
fi

# breezing 别名必须在 public mirror 和 codex mirror 中都与 skills-v3 一致
for mirror_entry in "claude:$CLAUDE_MIRROR/breezing" "codex:$CODEX_MIRROR/breezing"; do
  mirror_name="${mirror_entry%%:*}"
  mirror_path="${mirror_entry#*:}"
  if [ ! -d "$mirror_path" ]; then
    echo "  ❌ $mirror_name: breezing 不作为目录存在"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  if [ -L "$mirror_path" ]; then
    echo "  ❌ $mirror_name: breezing 仍然是 symlink"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  if diff -qr "$V3_SKILLS_DIR/breezing" "$mirror_path" >/dev/null 2>&1; then
    echo "  ✅ $mirror_name: breezing mirror is in sync"
  else
    echo "  ❌ $mirror_name: breezing mirror 与 skills-v3 不一致"
    ERRORS=$((ERRORS + 1))
  fi
done

# ================================
# 11. CHANGELOG 格式验证
# ================================
echo ""
echo "📝 [11/12] CHANGELOG 格式验证..."

CHANGELOG_ISSUES=0

for changelog in "$PLUGIN_ROOT/CHANGELOG.md" "$PLUGIN_ROOT/CHANGELOG_ja.md"; do
  if [ ! -f "$changelog" ]; then
    continue
  fi

  cl_name=$(basename "$changelog")

  # Check 1: Keep a Changelog 标题（## [x.y.z] - YYYY-MM-DD 格式）
  BAD_DATES=$(grep -nE '^\#\# \[[0-9]' "$changelog" | grep -vE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | grep -v "Unreleased" || true)
  if [ -n "$BAD_DATES" ]; then
    echo "  ❌ $cl_name: 非 ISO 8601 日期的条目"
    echo "$BAD_DATES" | head -3 | sed 's/^/      /'
    CHANGELOG_ISSUES=$((CHANGELOG_ISSUES + 1))
  fi

  # Check 2: 非标准章节标题（Keep a Changelog 1.1.0 的 6 种以外）
  NON_STANDARD=$(grep -nE '^\#\#\# ' "$changelog" \
    | grep -viE '(Added|Changed|Deprecated|Removed|Fixed|Security|What.*Changed|あなたにとって)' \
    | grep -viE '(Internal|Breaking|Migration|Summary|Before)' \
    || true)
  if [ -n "$NON_STANDARD" ]; then
    echo "  ⚠️ $cl_name: 非标准章节标题（建议确认）"
    echo "$NON_STANDARD" | head -3 | sed 's/^/      /'
    # 仅警告（不作为错误）
  fi

  # Check 3: [Unreleased] 章节是否存在
  if ! grep -q '^\#\# \[Unreleased\]' "$changelog"; then
    echo "  ❌ $cl_name: 没有 [Unreleased] 章节"
    CHANGELOG_ISSUES=$((CHANGELOG_ISSUES + 1))
  fi
done

if [ $CHANGELOG_ISSUES -eq 0 ]; then
  echo "  ✅ CHANGELOG 格式OK"
else
  ERRORS=$((ERRORS + CHANGELOG_ISSUES))
fi

# ================================
# 12. README claim drift 检查
# ================================
echo ""
echo "📚 [12/12] README claim drift 检查..."

README_ISSUES=0
README_EN="$PLUGIN_ROOT/README.md"
README_JA="$PLUGIN_ROOT/README_ja.md"
SCOPE_DOC="$PLUGIN_ROOT/docs/distribution-scope.md"
RUBRIC_DOC="$PLUGIN_ROOT/docs/benchmark-rubric.md"
POSITIONING_DOC="$PLUGIN_ROOT/docs/positioning-notes.md"
WORK_ALL_DOC="$PLUGIN_ROOT/docs/evidence/work-all.md"

check_fixed_string() {
  local file_path="$1"
  local needle="$2"
  local label="$3"

  if [ ! -f "$file_path" ]; then
    echo "  ❌ ${label}: 文件不存在: $file_path"
    README_ISSUES=$((README_ISSUES + 1))
    return
  fi

  if grep -qF "$needle" "$file_path"; then
    echo "  ✅ ${label}"
  else
    echo "  ❌ ${label}: 必需字符串未找到"
    README_ISSUES=$((README_ISSUES + 1))
  fi
}

check_absent_string() {
  local file_path="$1"
  local needle="$2"
  local label="$3"

  if [ ! -f "$file_path" ]; then
    echo "  ❌ ${label}: 文件不存在: $file_path"
    README_ISSUES=$((README_ISSUES + 1))
    return
  fi

  if grep -qF "$needle" "$file_path"; then
    echo "  ❌ ${label}: 旧的 claim 仍然存在"
    README_ISSUES=$((README_ISSUES + 1))
  else
    echo "  ✅ ${label}"
  fi
}

check_exists() {
  local file_path="$1"
  local label="$2"

  if [ -f "$file_path" ]; then
    echo "  ✅ ${label}"
  else
    echo "  ❌ ${label}: 文件不存在"
    README_ISSUES=$((README_ISSUES + 1))
  fi
}

check_fixed_string "$README_EN" "$LATEST_RELEASE_URL" "README.md latest release link"
check_fixed_string "$README_JA" "$LATEST_RELEASE_URL" "README_ja.md latest release link"
check_fixed_string "$README_EN" "$LATEST_RELEASE_BADGE" "README.md latest release badge"
check_fixed_string "$README_JA" "$LATEST_RELEASE_BADGE" "README_ja.md latest release badge"

check_exists "$SCOPE_DOC" "distribution-scope.md"
check_exists "$RUBRIC_DOC" "benchmark-rubric.md"
check_exists "$POSITIONING_DOC" "positioning-notes.md"
check_exists "$WORK_ALL_DOC" "work-all evidence doc"

check_fixed_string "$README_EN" "docs/CLAUDE_CODE_COMPATIBILITY.md" "README.md compatibility doc link"
check_fixed_string "$README_EN" "docs/CURSOR_INTEGRATION.md" "README.md cursor doc link"
check_fixed_string "$README_EN" "docs/evidence/work-all.md" "README.md work-all evidence link"
check_fixed_string "$README_EN" "docs/distribution-scope.md" "README.md distribution scope link"
check_fixed_string "$README_EN" "5 verb skills" "README.md 5 verb skills message"
check_fixed_string "$README_EN" "TypeScript guardrail engine" "README.md TypeScript guardrail engine message"
check_absent_string "$README_EN" "Production-ready code." "README.md stale production-ready wording"

check_fixed_string "$README_JA" "docs/CLAUDE_CODE_COMPATIBILITY.md" "README_ja.md compatibility doc link"
check_fixed_string "$README_JA" "docs/CURSOR_INTEGRATION.md" "README_ja.md cursor doc link"
check_fixed_string "$README_JA" "docs/evidence/work-all.md" "README_ja.md work-all evidence link"
check_fixed_string "$README_JA" "docs/distribution-scope.md" "README_ja.md distribution scope link"
check_fixed_string "$README_JA" "5動詞スキル" "README_ja.md 5動詞スキル message"
check_fixed_string "$README_JA" "TypeScript ガードレールエンジン" "README_ja.md TypeScript ガードレールエンジン message"
check_absent_string "$README_JA" "本番品質のコード。" "README_ja.md stale production-ready wording"

check_fixed_string "$SCOPE_DOC" '| `commands/` | Compatibility-retained |' "distribution-scope commands classification"
check_fixed_string "$SCOPE_DOC" '| `mcp-server/` | Development-only and distribution-excluded |' "distribution-scope mcp-server classification"
check_fixed_string "$RUBRIC_DOC" "| Static evidence |" "benchmark-rubric static evidence"
check_fixed_string "$RUBRIC_DOC" "| Executed evidence |" "benchmark-rubric executed evidence"
check_fixed_string "$POSITIONING_DOC" "runtime enforcement" "positioning-notes runtime enforcement"

if [ $README_ISSUES -eq 0 ]; then
  echo "  ✅ README claim drift 检查OK"
else
  ERRORS=$((ERRORS + README_ISSUES))
fi

# ================================
# 结果摘要
# ================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ]; then
  echo "✅ 所有检查已通过"
  exit 0
else
  echo "❌ 发现 $ERRORS 个问题"
  exit 1
fi
