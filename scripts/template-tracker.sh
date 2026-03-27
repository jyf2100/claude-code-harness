#!/bin/bash
# template-tracker.sh
# 模板跟踪功能：管理生成文件的更新状态
#
# 功能:
# - init: 初始化 generated-files.json（记录现有文件的状态）
# - check: 检查模板更新，显示需要更新的文件
# - status: 显示每个文件的详细状态
#
# 使用方法:
#   template-tracker.sh init   - 初始化
#   template-tracker.sh check  - 更新检查（用于 SessionStart，JSON 输出）
#   template-tracker.sh status - 详细显示（面向用户）
#
# 注意（v2.5.30+）:
# - 优先使用基于 frontmatter 的跟踪（_harness_version, _harness_template）
# - generated-files.json 用于回退（将来会弃用）
# - 新生成的文件通过 frontmatter 进行版本管理

set -euo pipefail

# 获取脚本目录和插件根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 加载 frontmatter 工具
# shellcheck source=frontmatter-utils.sh
if [ ! -f "$SCRIPT_DIR/frontmatter-utils.sh" ]; then
  echo "错误: 找不到 frontmatter-utils.sh。请重新安装插件。" >&2
  exit 1
fi
source "$SCRIPT_DIR/frontmatter-utils.sh"

# 常量
REGISTRY_FILE="$PLUGIN_ROOT/templates/template-registry.json"
STATE_DIR=".claude/state"
GENERATED_FILES="$STATE_DIR/generated-files.json"
VERSION_FILE="$PLUGIN_ROOT/VERSION"

# 获取当前插件版本
get_plugin_version() {
  cat "$VERSION_FILE" 2>/dev/null || echo "unknown"
}

# 获取文件的 SHA256 哈希值
get_file_hash() {
  local file="$1"
  if [ -f "$file" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      sha256sum "$file" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
      shasum -a 256 "$file" | cut -d' ' -f1
    else
      # 回退: 使用 md5
      md5sum "$file" 2>/dev/null | cut -d' ' -f1 || md5 -q "$file" 2>/dev/null || echo "no-hash"
    fi
  else
    echo ""
  fi
}

# 读取 generated-files.json
load_generated_files() {
  if [ -f "$GENERATED_FILES" ]; then
    cat "$GENERATED_FILES"
  else
    echo '{}'
  fi
}

# 保存 generated-files.json
save_generated_files() {
  local content="$1"
  mkdir -p "$STATE_DIR"
  echo "$content" > "$GENERATED_FILES"
}

# 从 template-registry.json 获取 tracked=true 的模板列表
get_tracked_templates() {
  if [ ! -f "$REGISTRY_FILE" ]; then
    echo "[]"
    return
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -r '.templates | to_entries | map(select(.value.tracked == true)) | .[].key' "$REGISTRY_FILE" 2>/dev/null
  else
    # 没有 jq 时仅返回基本模板
    echo "CLAUDE.md.template"
    echo "AGENTS.md.template"
    echo "Plans.md.template"
  fi
}

# 获取模板的输出路径
get_output_path() {
  local template="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r ".templates[\"$template\"].output // \"\"" "$REGISTRY_FILE" 2>/dev/null
  else
    # 没有 jq 时的基本映射
    case "$template" in
      "CLAUDE.md.template") echo "CLAUDE.md" ;;
      "AGENTS.md.template") echo "AGENTS.md" ;;
      "Plans.md.template") echo "Plans.md" ;;
      *) echo "" ;;
    esac
  fi
}

# 获取模板版本
get_template_version() {
  local template="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r ".templates[\"$template\"].templateVersion // \"unknown\"" "$REGISTRY_FILE" 2>/dev/null
  else
    echo "unknown"
  fi
}

# 初始化: 记录现有文件的状态
cmd_init() {
  local plugin_version
  plugin_version=$(get_plugin_version)

  local result='{"lastCheckedPluginVersion":"'"$plugin_version"'","files":{}}'

  while IFS= read -r template; do
    [ -z "$template" ] && continue

    local output_path
    output_path=$(get_output_path "$template")
    [ -z "$output_path" ] && continue

    if [ -f "$output_path" ]; then
      local file_hash
      file_hash=$(get_file_hash "$output_path")

      # 现有文件以 templateVersion: "unknown" 记录
      if command -v jq >/dev/null 2>&1; then
        result=$(echo "$result" | jq --arg path "$output_path" --arg hash "$file_hash" \
          '.files[$path] = {"templateVersion": "unknown", "fileHash": $hash, "recordedAt": (now | strftime("%Y-%m-%dT%H:%M:%SZ"))}')
      fi
    fi
  done < <(get_tracked_templates)

  save_generated_files "$result"
  echo "已初始化生成文件。记录了 $(echo "$result" | jq '.files | length') 个文件。"
}

# 检查: 检测需要更新的文件（JSON 输出）
cmd_check() {
  local generated
  generated=$(load_generated_files)

  local plugin_version
  plugin_version=$(get_plugin_version)

  local last_checked
  if command -v jq >/dev/null 2>&1; then
    last_checked=$(echo "$generated" | jq -r '.lastCheckedPluginVersion // "unknown"')
  else
    last_checked="unknown"
  fi

  # 如果插件版本未变化则跳过
  if [ "$last_checked" = "$plugin_version" ]; then
    echo '{"needsCheck": false, "reason": "Plugin version unchanged"}'
    return
  fi

  local updates_needed=()
  local updates_details='[]'
  local installs_details='[]'

  while IFS= read -r template; do
    [ -z "$template" ] && continue

    local output_path
    output_path=$(get_output_path "$template")
    [ -z "$output_path" ] && continue

    local template_version
    template_version=$(get_template_version "$template")

    # 如果文件不存在，则报告为 needsInstall
    if [ ! -f "$output_path" ]; then
      if command -v jq >/dev/null 2>&1; then
        installs_details=$(echo "$installs_details" | jq --arg path "$output_path" \
          --arg version "$template_version" \
          '. + [{"path": $path, "version": $version}]')
      fi
      continue
    fi

    local recorded_version="unknown"
    local recorded_hash=""
    local current_hash
    current_hash=$(get_file_hash "$output_path")

    # Phase B: 优先从 frontmatter 获取版本
    local frontmatter_version
    frontmatter_version=$(get_file_version "$output_path" "$GENERATED_FILES")

    if [ -n "$frontmatter_version" ] && [ "$frontmatter_version" != "unknown" ]; then
      recorded_version="$frontmatter_version"
    elif command -v jq >/dev/null 2>&1; then
      # 回退: 从 generated-files.json 获取
      recorded_version=$(echo "$generated" | jq -r ".files[\"$output_path\"].templateVersion // \"unknown\"")
    fi

    if command -v jq >/dev/null 2>&1; then
      recorded_hash=$(echo "$generated" | jq -r ".files[\"$output_path\"].fileHash // \"\"")
    fi

    # 版本比较（unknown 始终视为旧版本）
    local needs_update=false
    if [ "$recorded_version" = "unknown" ]; then
      needs_update=true
    elif [ "$recorded_version" != "$template_version" ]; then
      needs_update=true
    fi

    if [ "$needs_update" = true ]; then
      local is_localized=false
      if [ -n "$recorded_hash" ] && [ "$recorded_hash" != "$current_hash" ]; then
        is_localized=true
      fi

      if command -v jq >/dev/null 2>&1; then
        updates_details=$(echo "$updates_details" | jq --arg path "$output_path" \
          --arg from "$recorded_version" --arg to "$template_version" \
          --argjson localized "$is_localized" \
          '. + [{"path": $path, "from": $from, "to": $to, "localized": $localized}]')
      fi
    fi
  done < <(get_tracked_templates)

  local updates_count=0
  local installs_count=0
  if command -v jq >/dev/null 2>&1; then
    updates_count=$(echo "$updates_details" | jq 'length')
    installs_count=$(echo "$installs_details" | jq 'length')
  fi

  # 更新 lastCheckedPluginVersion
  if command -v jq >/dev/null 2>&1; then
    generated=$(echo "$generated" | jq --arg v "$plugin_version" '.lastCheckedPluginVersion = $v')
    save_generated_files "$generated"
  fi

  local total_count=$((updates_count + installs_count))

  if [ "$total_count" -gt 0 ]; then
    if command -v jq >/dev/null 2>&1; then
      echo "{\"needsCheck\": true, \"updatesCount\": $updates_count, \"installsCount\": $installs_count, \"updates\": $updates_details, \"installs\": $installs_details}"
    else
      echo "{\"needsCheck\": true, \"updatesCount\": $updates_count, \"installsCount\": $installs_count}"
    fi
  else
    echo '{"needsCheck": false, "reason": "All files up to date"}'
  fi
}

# 状态: 面向用户的详细显示
cmd_status() {
  local generated
  generated=$(load_generated_files)

  local plugin_version
  plugin_version=$(get_plugin_version)

  echo "=== 模板跟踪状态 ==="
  echo ""
  echo "插件版本: $plugin_version"

  if command -v jq >/dev/null 2>&1; then
    local last_checked
    last_checked=$(echo "$generated" | jq -r '.lastCheckedPluginVersion // "未检查"')
    echo "最后检查时: $last_checked"
  fi
  echo ""

  printf "%-40s %-12s %-12s %-10s %s\n" "文件" "记录版本" "最新版本" "状态" "来源"
  printf "%-40s %-12s %-12s %-10s %s\n" "--------" "------" "------" "----" "------"

  while IFS= read -r template; do
    [ -z "$template" ] && continue

    local output_path
    output_path=$(get_output_path "$template")
    [ -z "$output_path" ] && continue

    local template_version
    template_version=$(get_template_version "$template")

    if [ ! -f "$output_path" ]; then
      printf "%-40s %-12s %-12s %-10s\n" "$output_path" "-" "$template_version" "未生成"
      continue
    fi

    local recorded_version="unknown"
    local recorded_hash=""
    local current_hash
    current_hash=$(get_file_hash "$output_path")

    # Phase B: 优先从 frontmatter 获取版本
    local frontmatter_version
    frontmatter_version=$(get_file_version "$output_path" "$GENERATED_FILES")

    if [ -n "$frontmatter_version" ] && [ "$frontmatter_version" != "unknown" ]; then
      recorded_version="$frontmatter_version"
    elif command -v jq >/dev/null 2>&1; then
      # 回退: 从 generated-files.json 获取
      recorded_version=$(echo "$generated" | jq -r ".files[\"$output_path\"].templateVersion // \"unknown\"")
    fi

    if command -v jq >/dev/null 2>&1; then
      recorded_hash=$(echo "$generated" | jq -r ".files[\"$output_path\"].fileHash // \"\"")
    fi

    local status="✅ 最新"
    local version_source=""

    # 记录版本来源用于显示
    if has_frontmatter "$output_path" 2>/dev/null; then
      version_source="[FM]"
    else
      version_source="[GF]"
    fi

    if [ "$recorded_version" = "unknown" ]; then
      status="⚠️ 需确认"
    elif [ "$recorded_version" != "$template_version" ]; then
      if [ -n "$recorded_hash" ] && [ "$recorded_hash" != "$current_hash" ]; then
        status="🔧 需合并"
      else
        status="🔄 可覆盖"
      fi
    fi

    printf "%-40s %-12s %-12s %-10s %s\n" "$output_path" "$recorded_version" "$template_version" "$status" "$version_source"
  done < <(get_tracked_templates)

  echo ""
  echo "图例:"
  echo "  ✅ 最新     : 无需更新"
  echo "  🔄 可覆盖   : 无本地化修改，可通过覆盖更新"
  echo "  🔧 需合并   : 有本地化修改，需要合并"
  echo "  ⚠️ 需确认   : 版本未知，建议确认"
  echo ""
  echo "来源:"
  echo "  [FM] : 从 frontmatter 获取（优先）"
  echo "  [GF] : 从 generated-files.json 获取（回退）"
}

# 使用最新模板更新文件（同时更新记录）
cmd_record() {
  local file_path="$1"

  if [ -z "$file_path" ]; then
    echo "使用方法: template-tracker.sh record <file_path>"
    exit 1
  fi

  if [ ! -f "$file_path" ]; then
    echo "错误: 找不到文件: $file_path"
    exit 1
  fi

  # 从 template-registry.json 查找对应的模板
  local template_version=""
  while IFS= read -r template; do
    [ -z "$template" ] && continue

    local output_path
    output_path=$(get_output_path "$template")

    if [ "$output_path" = "$file_path" ]; then
      template_version=$(get_template_version "$template")
      break
    fi
  done < <(get_tracked_templates)

  if [ -z "$template_version" ]; then
    echo "错误: 找不到模板: $file_path"
    exit 1
  fi

  local file_hash
  file_hash=$(get_file_hash "$file_path")

  local generated
  generated=$(load_generated_files)

  if command -v jq >/dev/null 2>&1; then
    generated=$(echo "$generated" | jq --arg path "$file_path" \
      --arg version "$template_version" --arg hash "$file_hash" \
      '.files[$path] = {"templateVersion": $version, "fileHash": $hash, "recordedAt": (now | strftime("%Y-%m-%dT%H:%M:%SZ"))}')
    save_generated_files "$generated"
    echo "记录完成: $file_path (版本: $template_version)"
  else
    echo "错误: 此操作需要 jq"
    exit 1
  fi
}

# 主函数
case "${1:-}" in
  init)
    cmd_init
    ;;
  check)
    cmd_check
    ;;
  status)
    cmd_status
    ;;
  record)
    cmd_record "$2"
    ;;
  *)
    echo "使用方法: template-tracker.sh {init|check|status|record <file>}"
    echo ""
    echo "命令:"
    echo "  init   - 使用当前文件状态初始化 generated-files.json"
    echo "  check  - 检查模板更新（用于 SessionStart 的 JSON 输出）"
    echo "  status - 显示详细状态（面向用户）"
    echo "  record - 记录文件的当前状态"
    exit 1
    ;;
esac
