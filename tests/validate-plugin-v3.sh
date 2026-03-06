#!/bin/bash
# validate-plugin-v3.sh
# Harness v3 プラグイン構造バリデーター
#
# Usage: ./tests/validate-plugin-v3.sh
# Exit codes:
#   0 - All checks passed
#   1 - Failures found

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Claude Harness v3 — プラグイン検証テスト"
echo "=========================================="
echo ""

# カラー出力
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass_test() { echo -e "${GREEN}✓${NC} $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail_test() { echo -e "${RED}✗${NC} $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn_test() { echo -e "${YELLOW}⚠${NC} $1"; WARN_COUNT=$((WARN_COUNT + 1)); }

# ============================================================
# [1] v3 コア構造チェック
# ============================================================
echo "📁 [1/6] v3 コア構造チェック..."

V3_REQUIRED_FILES=(
  "core/package.json"
  "core/tsconfig.json"
  "core/src/index.ts"
  "core/src/types.ts"
  "core/src/guardrails/rules.ts"
  "core/src/guardrails/pre-tool.ts"
  "core/src/guardrails/post-tool.ts"
  "core/src/guardrails/permission.ts"
  "core/src/guardrails/tampering.ts"
  "core/src/engine/lifecycle.ts"
)

for f in "${V3_REQUIRED_FILES[@]}"; do
  if [ -f "$PLUGIN_ROOT/$f" ]; then
    pass_test "$f"
  else
    fail_test "$f (存在しない)"
  fi
done

# ============================================================
# [2] 5動詞スキルチェック
# ============================================================
echo ""
echo "🎯 [2/6] 5動詞スキルチェック..."

V3_SKILLS=(harness-plan harness-work harness-review harness-release harness-setup)

for skill in "${V3_SKILLS[@]}"; do
  skill_dir="$PLUGIN_ROOT/skills-v3/$skill"
  skill_md="$skill_dir/SKILL.md"

  if [ ! -d "$skill_dir" ]; then
    fail_test "skills-v3/$skill/ (ディレクトリなし)"
    continue
  fi

  if [ ! -f "$skill_md" ]; then
    fail_test "skills-v3/$skill/SKILL.md (なし)"
    continue
  fi

  # frontmatter の name: チェック
  if grep -q "^name: $skill$" "$skill_md"; then
    pass_test "skills-v3/$skill/SKILL.md (name: $skill)"
  else
    fail_test "skills-v3/$skill/SKILL.md (name: フィールドが '$skill' でない)"
  fi
done

# ============================================================
# [3] Public mirror bundle チェック
# ============================================================
echo ""
echo "📦 [3/6] Public mirror bundle チェック..."

MIRRORS=(
  "skills"
  "codex/.codex/skills"
  "opencode/skills"
)

for mirror_dir in "${MIRRORS[@]}"; do
  if [ ! -d "$PLUGIN_ROOT/$mirror_dir" ]; then
    warn_test "$mirror_dir (存在しない、スキップ)"
    continue
  fi

  for skill in "${V3_SKILLS[@]}"; do
    source_dir="$PLUGIN_ROOT/skills-v3/$skill"
    mirror_path="$PLUGIN_ROOT/$mirror_dir/$skill"

    if [ ! -d "$mirror_path" ]; then
      fail_test "$mirror_dir/$skill (ディレクトリなし)"
      continue
    fi

    if [ -L "$mirror_path" ]; then
      fail_test "$mirror_dir/$skill (symlink のまま)"
      continue
    fi

    if diff -qr "$source_dir" "$mirror_path" >/dev/null 2>&1; then
      pass_test "$mirror_dir/$skill (skills-v3/$skill と同期)"
    else
      fail_test "$mirror_dir/$skill (skills-v3/$skill と差分あり)"
    fi
  done
done

# ============================================================
# [4] 3エージェントチェック
# ============================================================
echo ""
echo "🤖 [4/6] 3エージェントチェック..."

V3_AGENTS=(worker reviewer scaffolder)

for agent in "${V3_AGENTS[@]}"; do
  agent_file="$PLUGIN_ROOT/agents-v3/$agent.md"
  if [ -f "$agent_file" ]; then
    # name: フィールド確認
    if grep -q "^name: $agent$" "$agent_file"; then
      pass_test "agents-v3/$agent.md (name: $agent)"
    else
      fail_test "agents-v3/$agent.md (name: フィールドが '$agent' でない)"
    fi
  else
    fail_test "agents-v3/$agent.md (存在しない)"
  fi
done

# team-composition.md
if [ -f "$PLUGIN_ROOT/agents-v3/team-composition.md" ]; then
  pass_test "agents-v3/team-composition.md"
else
  warn_test "agents-v3/team-composition.md (なし)"
fi

# ============================================================
# [5] TypeScript 型チェック
# ============================================================
echo ""
echo "🔷 [5/6] TypeScript 型チェック..."

CORE_DIR="$PLUGIN_ROOT/core"

if [ ! -d "$CORE_DIR/node_modules" ]; then
  warn_test "core/node_modules なし — npm ci が必要 (スキップ)"
else
  if cd "$CORE_DIR" && npm run typecheck --silent 2>/dev/null; then
    pass_test "core/ TypeScript 型チェック通過"
  else
    fail_test "core/ TypeScript 型チェック失敗"
  fi
  cd "$PLUGIN_ROOT"
fi

# ============================================================
# [6] hooks シム チェック
# ============================================================
echo ""
echo "🪝 [6/6] hooks シムチェック..."

HOOK_FILES=(
  "hooks/pre-tool.sh"
  "hooks/post-tool.sh"
  "hooks/session.sh"
  "hooks/hooks.json"
)

for f in "${HOOK_FILES[@]}"; do
  if [ -f "$PLUGIN_ROOT/$f" ]; then
    pass_test "$f"
  else
    fail_test "$f (存在しない)"
  fi
done

# ============================================================
# サマリー
# ============================================================
echo ""
echo "=========================================="
echo "結果サマリー"
echo "=========================================="
echo -e "${GREEN}✓ 通過${NC}: $PASS_COUNT"
echo -e "${RED}✗ 失敗${NC}: $FAIL_COUNT"
echo -e "${YELLOW}⚠ 警告${NC}: $WARN_COUNT"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}❌ バリデーション失敗: $FAIL_COUNT 件のエラーがあります${NC}"
  exit 1
else
  echo -e "${GREEN}✅ バリデーション通過${NC}"
  exit 0
fi
