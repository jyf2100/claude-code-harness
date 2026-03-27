#!/bin/bash
# sync-rules-to-agents.sh
# .claude/rules/*.md → codex/AGENTS.md 的自动转换 + SSOT 漂移检测
#
# 用法:
#   ./scripts/codex/sync-rules-to-agents.sh           # 转换并写入
#   ./scripts/codex/sync-rules-to-agents.sh --check   # 仅漂移检查（不写入）
#   ./scripts/codex/sync-rules-to-agents.sh --dry-run # 预览转换内容
#
# 输出: 更新 codex/AGENTS.md 的 ## Rules 部分

set -euo pipefail

# ===== 配置 =====
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RULES_DIR="${PROJECT_ROOT}/.claude/rules"
AGENTS_MD="${PROJECT_ROOT}/codex/AGENTS.md"
HASH_FILE="${PROJECT_ROOT}/.claude/state/rules-hash.txt"
SECTION_MARKER_START="<!-- sync-rules-to-agents: start -->"
SECTION_MARKER_END="<!-- sync-rules-to-agents: end -->"

# ===== 选项解析 =====
MODE="write"
for arg in "$@"; do
  case "$arg" in
    --check)    MODE="check" ;;
    --dry-run)  MODE="dry-run" ;;
  esac
done

# ===== 获取规则文件列表 =====
# CLAUDE.md 仅包含自动生成的内存上下文，因此排除
RULE_FILES=()
while IFS= read -r f; do
  basename_f="$(basename "$f")"
  case "$basename_f" in
    CLAUDE.md) continue ;;  # 排除内存上下文文件
    *.md) RULE_FILES+=("$f") ;;
  esac
done < <(find "$RULES_DIR" -maxdepth 1 -name "*.md" | sort)

if [ ${#RULE_FILES[@]} -eq 0 ]; then
  echo "INFO: No rule files found in ${RULES_DIR}" >&2
  exit 0
fi

# ===== 将规则内容转换为 AGENTS.md 格式 =====
build_rules_section() {
  echo "${SECTION_MARKER_START}"
  echo ""
  echo "## Rules (from .claude/rules/)"
  echo ""
  echo "> 此部分由 \`scripts/codex/sync-rules-to-agents.sh\` 自动生成。"
  echo "> 请勿直接编辑。SSOT 是 \`.claude/rules/\`。"
  echo ""
  echo "| 规则文件 | 说明 |"
  echo "|--------------|------|"

  for f in "${RULE_FILES[@]}"; do
    name="$(basename "$f" .md)"
    # 从 frontmatter 获取 description
    desc=$(awk '/^---/{count++; next} count==1 && /^description:/{sub(/^description:[[:space:]]*/, ""); print; exit}' "$f" 2>/dev/null || true)
    if [ -z "$desc" ]; then
      # 如果没有 frontmatter，使用第一个 H1 标题
      desc=$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //' || true)
    fi
    [ -z "$desc" ] && desc="${name}"
    echo "| \`${name}.md\` | ${desc} |"
  done

  echo ""

  # 展开各规则文件的重要部分
  for f in "${RULE_FILES[@]}"; do
    name="$(basename "$f" .md)"
    echo "### ${name}"
    echo ""
    # codex-cli-only.md: Claude Code 专用规则（MCP 废止/禁止重新注册）在 Codex 环境中不需要
    # Codex 自身不需要调用 codex exec，因此跳过（仅保留参考链接）
    if [ "$name" = "codex-cli-only" ]; then
      echo "> 此规则面向 Claude Code。在 Codex 环境中不适用。"
    # test-quality.md: 优先展开「绝对禁止事项」部分（AGENTS.md 格式模板）
    # 提取禁止模式表和对应流程，嵌入 AGENTS.md
    elif [ "$name" = "test-quality" ]; then
      awk '
        BEGIN { in_front=0; done_front=0; in_prohibited=0; lines=0 }
        /^---/ && !done_front { in_front=!in_front; if (!in_front) done_front=1; next }
        in_front { next }
        !done_front { next }
        /^## 绝对禁止事项/ { in_prohibited=1 }
        /^## / && !/^## 绝对禁止事项/ && in_prohibited { in_prohibited=0 }
        in_prohibited && lines < 40 { print; lines++ }
      ' "$f"
    # implementation-quality.md: 展开「绝对禁止事项」和「实现时的自检」
    # 将形式化实现禁止模式表 + 检查清单嵌入 AGENTS.md
    elif [ "$name" = "implementation-quality" ]; then
      awk '
        BEGIN { in_front=0; done_front=0; in_section=0; lines=0 }
        /^---/ && !done_front { in_front=!in_front; if (!in_front) done_front=1; next }
        in_front { next }
        !done_front { next }
        /^## 绝对禁止事项|^## 实现时的自检/ { in_section=1 }
        /^## / && !/^## 绝对禁止事项/ && !/^## 实现时的自检/ && in_section { in_section=0 }
        in_section && lines < 60 { print; lines++ }
      ' "$f"
    else
      # 其他规则文件输出前 50 行
      awk '
        BEGIN { in_front=0; done_front=0; lines=0 }
        /^---/ && !done_front { in_front=!in_front; if (!in_front) done_front=1; next }
        in_front { next }
        done_front && lines < 50 { print; lines++ }
      ' "$f"
    fi
    echo ""
    echo "<!-- 全文: .claude/rules/${name}.md -->"
    echo ""
  done

  echo "${SECTION_MARKER_END}"
}

# ===== 计算当前规则内容的哈希值 =====
compute_rules_hash() {
  cat "${RULE_FILES[@]}" | shasum -a 256 | awk '{print $1}'
}

CURRENT_HASH="$(compute_rules_hash)"

# ===== --check 模式: 仅漂移检测 =====
if [ "$MODE" = "check" ]; then
  if [ ! -f "$HASH_FILE" ]; then
    echo "DRIFT: hash file not found (${HASH_FILE}). Run without --check to initialize." >&2
    exit 1
  fi
  SAVED_HASH="$(cat "$HASH_FILE" 2>/dev/null || true)"
  if [ "$CURRENT_HASH" = "$SAVED_HASH" ]; then
    echo "OK: rules are in sync (hash: ${CURRENT_HASH})"
    exit 0
  else
    echo "DRIFT: rules have changed since last sync." >&2
    echo "  saved:   ${SAVED_HASH}" >&2
    echo "  current: ${CURRENT_HASH}" >&2
    echo "  Run ./scripts/codex/sync-rules-to-agents.sh to update." >&2
    exit 1
  fi
fi

# ===== 将转换内容写入临时文件 =====
NEW_SECTION_FILE="$(mktemp)"
build_rules_section > "$NEW_SECTION_FILE"

# ===== --dry-run 模式: 仅预览 =====
if [ "$MODE" = "dry-run" ]; then
  echo "=== DRY RUN: would write to ${AGENTS_MD} ==="
  echo ""
  cat "$NEW_SECTION_FILE"
  rm -f "$NEW_SECTION_FILE"
  exit 0
fi

# ===== write 模式: 更新 AGENTS.md =====
if [ ! -f "$AGENTS_MD" ]; then
  echo "ERROR: ${AGENTS_MD} not found." >&2
  rm -f "$NEW_SECTION_FILE"
  exit 1
fi

# 如果已存在该部分则替换，否则追加到末尾
if grep -q "${SECTION_MARKER_START}" "$AGENTS_MD" 2>/dev/null; then
  # 替换已存在的部分（用 awk 将标记之间的内容替换为新文件）
  TMP_FILE="$(mktemp)"
  awk -v new_file="$NEW_SECTION_FILE" \
    -v start="${SECTION_MARKER_START}" \
    -v end="${SECTION_MARKER_END}" '
    BEGIN { in_section=0; inserted=0 }
    $0 ~ start {
      in_section=1
      while ((getline line < new_file) > 0) { print line }
      close(new_file)
      inserted=1
      next
    }
    $0 ~ end   { in_section=0; next }
    !in_section { print }
  ' "$AGENTS_MD" > "$TMP_FILE"
  mv "$TMP_FILE" "$AGENTS_MD"
  echo "INFO: Updated existing Rules section in ${AGENTS_MD}"
else
  # 如果部分不存在，则追加到末尾
  printf '\n' >> "$AGENTS_MD"
  cat "$NEW_SECTION_FILE" >> "$AGENTS_MD"
  echo "INFO: Appended Rules section to ${AGENTS_MD}"
fi

rm -f "$NEW_SECTION_FILE"

# ===== 保存哈希值 =====
mkdir -p "$(dirname "$HASH_FILE")"
echo "$CURRENT_HASH" > "$HASH_FILE"
echo "INFO: Saved hash (${CURRENT_HASH}) to ${HASH_FILE}"

echo "DONE: sync complete."
