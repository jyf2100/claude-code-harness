#!/bin/bash
# fix-symlinks.sh
# 检测 Windows 环境中损坏的 symlink / 纯文本链接映射，并用实体副本自动修复
#
# 用途: 从 session-init.sh 调用
# 行为:
#   - 如果 skills/ 内的公开 harness-* skill 变成了普通文件（旧版 Windows checkout）
#   - 则从 skills-v3/ 复制实体副本进行替换
#   - 输出修复数量（JSON 格式）
#
# 输出:
#   {"fixed": N, "checked": M, "details": ["harness-work", ...]}

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SKILLS_DIR="$PLUGIN_ROOT/skills"
SKILLS_V3_DIR="$PLUGIN_ROOT/skills-v3"

# 公开 5 个 skill 列表（skills/ 镜像包）
V3_SKILLS=("harness-plan" "harness-work" "harness-review" "harness-setup" "harness-release")

FIXED=0
CHECKED=0
FIXED_NAMES=()

for skill in "${V3_SKILLS[@]}"; do
  CHECKED=$((CHECKED + 1))
  skill_path="$SKILLS_DIR/$skill"
  source_path="$SKILLS_V3_DIR/$skill"

  # 正常: 以 symlink 或目录形式存在 → 跳过
  if [ -d "$skill_path" ]; then
    continue
  fi

  # 损坏的纯文本链接: 以普通文件形式存在（Windows git clone 时发生）
  if [ -f "$skill_path" ]; then
    # 确认修复源是否存在
    if [ -d "$source_path" ]; then
      rm -f "$skill_path"
      cp -r "$source_path" "$skill_path"
      FIXED=$((FIXED + 1))
      FIXED_NAMES+=("$skill")
    fi
  fi

  # 不存在时也尝试修复
  if [ ! -e "$skill_path" ] && [ -d "$source_path" ]; then
    cp -r "$source_path" "$skill_path"
    FIXED=$((FIXED + 1))
    FIXED_NAMES+=("$skill")
  fi
done

# extensions/ 内的 symlink 也同样检查
EXTENSIONS_DIR="$SKILLS_V3_DIR/extensions"
if [ -d "$EXTENSIONS_DIR" ]; then
  for ext_path in "$EXTENSIONS_DIR"/*; do
    [ -e "$ext_path" ] || continue
    ext_name="$(basename "$ext_path")"
    CHECKED=$((CHECKED + 1))

    # 普通文件（损坏的 symlink）的情况
    if [ -f "$ext_path" ] && [ ! -d "$ext_path" ]; then
      # 读取链接目标（文件内容为路径）
      target=$(cat "$ext_path" 2>/dev/null || true)
      # 解析相对路径
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

# JSON 输出
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
