#!/bin/bash
# frontmatter-utils.sh
# 从 frontmatter 提取元数据的工具函数
#
# 使用方法:
#   source frontmatter-utils.sh
#   get_frontmatter_version "CLAUDE.md"         # 获取版本
#   get_frontmatter_template "CLAUDE.md"        # 获取模板名
#   has_frontmatter "CLAUDE.md"                 # 检查 frontmatter 是否存在

# 检查 frontmatter 是否存在
has_frontmatter() {
  local file="$1"
  [ ! -f "$file" ] && return 1

  # 检查文件开头是否以 --- 开始
  head -1 "$file" | grep -q "^---$" || return 1

  # 检查是否存在 _harness_version 或 _harness_template
  sed -n '/^---$/,/^---$/p' "$file" | grep -qE "_harness_(version|template):"
}

# 从 frontmatter 获取版本
# 如果没有 frontmatter 则返回空字符串
get_frontmatter_version() {
  local file="$1"

  [ ! -f "$file" ] && echo "" && return 1

  local version=""

  # JSON 文件时使用 jq 直接获取（.json 或 .json.template）
  if [[ "$file" == *.json ]] || [[ "$file" == *.json.template ]]; then
    if command -v jq >/dev/null 2>&1; then
      version=$(jq -r '._harness_version // empty' "$file" 2>/dev/null)
    fi
    echo "$version"
    return 0
  fi

  # YAML frontmatter 存在检查
  if ! head -1 "$file" | grep -q "^---$"; then
    echo ""
    return 1
  fi

  # 从 YAML frontmatter 提取 _harness_version
  version=$(sed -n '/^---$/,/^---$/p' "$file" | grep "_harness_version:" | head -1 | sed 's/.*: *"//' | sed 's/".*//')

  echo "$version"
}

# 从 frontmatter 获取模板名
get_frontmatter_template() {
  local file="$1"

  [ ! -f "$file" ] && echo "" && return 1

  local template=""

  # JSON 文件时使用 jq 直接获取（.json 或 .json.template）
  if [[ "$file" == *.json ]] || [[ "$file" == *.json.template ]]; then
    if command -v jq >/dev/null 2>&1; then
      template=$(jq -r '._harness_template // empty' "$file" 2>/dev/null)
    fi
    echo "$template"
    return 0
  fi

  # YAML frontmatter 存在检查
  if ! head -1 "$file" | grep -q "^---$"; then
    echo ""
    return 1
  fi

  # 从 YAML frontmatter 提取 _harness_template
  template=$(sed -n '/^---$/,/^---$/p' "$file" | grep "_harness_template:" | head -1 | sed 's/.*: *"//' | sed 's/".*//')

  echo "$template"
}

# 获取文件版本（优先从 frontmatter，有回退机制）
# 用法: get_file_version "CLAUDE.md" "generated-files.json"
get_file_version() {
  local file="$1"
  local fallback_registry="$2"

  # 1. 尝试从 frontmatter 获取版本
  local version
  version=$(get_frontmatter_version "$file")

  if [ -n "$version" ]; then
    echo "$version"
    return 0
  fi

  # 2. 回退: 从 generated-files.json 获取
  if [ -n "$fallback_registry" ] && [ -f "$fallback_registry" ]; then
    if command -v jq >/dev/null 2>&1; then
      version=$(jq -r ".files[\"$file\"].templateVersion // empty" "$fallback_registry" 2>/dev/null)
      if [ -n "$version" ]; then
        echo "$version"
        return 0
      fi
    fi
  fi

  # 版本未知
  echo "unknown"
  return 1
}

# YAML 注释形式的版本获取（用于 .yaml 文件）
get_yaml_comment_version() {
  local file="$1"

  [ ! -f "$file" ] && echo "" && return 1

  # 提取 # _harness_version: "x.y.z" 形式
  local version
  version=$(grep "# _harness_version:" "$file" | head -1 | sed 's/.*: *"//' | sed 's/".*//')

  echo "$version"
}
