#!/bin/bash
# fix-symlinks.sh
# Windows 環境で壊れた symlink / plain-text link projection を検出し、実体コピーで自動修復する
#
# 用途: session-init.sh から呼び出し
# 動作:
#   - skills/ 内の公開 harness-* skill が通常ファイルになっている場合（古い Windows checkout）
#   - skills-v3/ から実体コピーで置き換える
#   - 修復件数を stdout に出力（JSON 形式）
#
# 出力:
#   {"fixed": N, "checked": M, "details": ["harness-work", ...]}

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SKILLS_DIR="$PLUGIN_ROOT/skills"
SKILLS_V3_DIR="$PLUGIN_ROOT/skills-v3"

# 公開 5 skill 一覧（skills/ mirror bundle）
V3_SKILLS=("harness-plan" "harness-work" "harness-review" "harness-setup" "harness-release")

FIXED=0
CHECKED=0
FIXED_NAMES=()

for skill in "${V3_SKILLS[@]}"; do
  CHECKED=$((CHECKED + 1))
  skill_path="$SKILLS_DIR/$skill"
  source_path="$SKILLS_V3_DIR/$skill"

  # 正常: symlink またはディレクトリとして存在 → スキップ
  if [ -d "$skill_path" ]; then
    continue
  fi

  # 壊れた plain-text link: 通常ファイルとして存在（Windows git clone で発生）
  if [ -f "$skill_path" ]; then
    # 修復元が存在するか確認
    if [ -d "$source_path" ]; then
      rm -f "$skill_path"
      cp -r "$source_path" "$skill_path"
      FIXED=$((FIXED + 1))
      FIXED_NAMES+=("$skill")
    fi
  fi

  # 存在しない場合も修復を試みる
  if [ ! -e "$skill_path" ] && [ -d "$source_path" ]; then
    cp -r "$source_path" "$skill_path"
    FIXED=$((FIXED + 1))
    FIXED_NAMES+=("$skill")
  fi
done

# extensions/ 内の symlink も同様にチェック
EXTENSIONS_DIR="$SKILLS_V3_DIR/extensions"
if [ -d "$EXTENSIONS_DIR" ]; then
  for ext_path in "$EXTENSIONS_DIR"/*; do
    [ -e "$ext_path" ] || continue
    ext_name="$(basename "$ext_path")"
    CHECKED=$((CHECKED + 1))

    # 通常ファイル（壊れた symlink）の場合
    if [ -f "$ext_path" ] && [ ! -d "$ext_path" ]; then
      # リンク先を読み取り（ファイル内容がパス）
      target=$(cat "$ext_path" 2>/dev/null || true)
      # 相対パスを解決
      resolved="$(cd "$EXTENSIONS_DIR" && cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")" 2>/dev/null || true
      if [ -d "$resolved" ]; then
        rm -f "$ext_path"
        cp -r "$resolved" "$ext_path"
        FIXED=$((FIXED + 1))
        FIXED_NAMES+=("extensions/$ext_name")
      fi
    fi
  done
fi

# JSON 出力
NAMES_JSON="[]"
if [ ${#FIXED_NAMES[@]} -gt 0 ]; then
  NAMES_JSON="["
  for i in "${!FIXED_NAMES[@]}"; do
    [ "$i" -gt 0 ] && NAMES_JSON+=","
    NAMES_JSON+="\"${FIXED_NAMES[$i]}\""
  done
  NAMES_JSON+="]"
fi

echo "{\"fixed\":${FIXED},\"checked\":${CHECKED},\"details\":${NAMES_JSON}}"
