#!/bin/bash
# sync-plugin-cache.sh
# 检查插件源和缓存的一致性，必要时进行同步
#
# 使用方法：从 SessionStart hook 自动执行
#
# 处理流程：
# 1. 获取插件源的版本
# 2. 比较缓存的版本/文件哈希
# 3. 如果有差异则同步

set -euo pipefail

# ===== 颜色定义 =====
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# ===== 路径设置 =====
# 检测插件源位置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load cross-platform path utilities (if available)
if [ -f "$SCRIPT_DIR/path-utils.sh" ]; then
  # shellcheck source=./path-utils.sh
  source "$SCRIPT_DIR/path-utils.sh"
fi

# Detect plugin source location
# Priority: 1. CLAUDE_PLUGIN_ROOT env var, 2. Script's parent directory (default)
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  if [ -f "${CLAUDE_PLUGIN_ROOT}/VERSION" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
    PLUGIN_SOURCE="$CLAUDE_PLUGIN_ROOT"
  elif [ -f "${CLAUDE_PLUGIN_ROOT}/claude-code-harness/VERSION" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/claude-code-harness/.claude-plugin/plugin.json" ]; then
    PLUGIN_SOURCE="$CLAUDE_PLUGIN_ROOT/claude-code-harness"
  else
    PLUGIN_SOURCE="$CLAUDE_PLUGIN_ROOT"
  fi
else
  # Default: use script's parent directory (works for both dev and installed)
  PLUGIN_SOURCE="$(dirname "$SCRIPT_DIR")"
fi

# Note: Removed hardcoded development paths for cross-platform compatibility
# If you need to override in development, set CLAUDE_PLUGIN_ROOT environment variable

# 插件信息
PLUGIN_NAME="claude-code-harness"
MARKETPLACE_NAME="claude-code-harness-marketplace"

# 缓存目录
CACHE_BASE="$HOME/.claude/plugins/cache/$MARKETPLACE_NAME/$PLUGIN_NAME"

# ===== 版本获取 =====
get_source_version() {
  if [ -f "$PLUGIN_SOURCE/VERSION" ]; then
    cat "$PLUGIN_SOURCE/VERSION" | tr -d '[:space:]'
  else
    echo "unknown"
  fi
}

get_cache_version() {
  # 获取缓存中的最新版本目录
  if [ -d "$CACHE_BASE" ]; then
    ls -1 "$CACHE_BASE" 2>/dev/null | sort -V | tail -1
  else
    echo ""
  fi
}

# ===== 文件哈希比较 =====
get_file_hash() {
  local file="$1"
  if [ -f "$file" ]; then
    if command -v md5sum >/dev/null 2>&1; then
      md5sum "$file" | cut -d' ' -f1
    elif command -v md5 >/dev/null 2>&1; then
      md5 -q "$file"
    else
      # 回退方案：文件大小
      wc -c < "$file" | tr -d '[:space:]'
    fi
  else
    echo ""
  fi
}

files_differ() {
  local source_file="$1"
  local cache_file="$2"
  
  [ ! -f "$source_file" ] && return 1
  [ ! -f "$cache_file" ] && return 0
  
  local source_hash=$(get_file_hash "$source_file")
  local cache_hash=$(get_file_hash "$cache_file")
  
  [ "$source_hash" != "$cache_hash" ]
}

# ===== 同步处理 =====
sync_file() {
  local rel_path="$1"
  local cache_dir="$2"  # Explicit argument instead of global variable
  local source_file="$PLUGIN_SOURCE/$rel_path"
  local cache_file="$cache_dir/$rel_path"

  if [ -f "$source_file" ]; then
    mkdir -p "$(dirname "$cache_file")"
    cp "$source_file" "$cache_file"
    echo "  ✓ $rel_path"
  fi
}

sync_critical_files() {
  local cache_dir="$1"
  local plugin_source="$2"  # 显式接收源目录
  local synced=0

  # 需要同步的文件（关键脚本）
  local critical_files=(
    "scripts/run-script.js"
    "scripts/path-utils.sh"
    "scripts/pretooluse-guard.sh"
    "scripts/posttooluse-log-toolname.sh"
    "scripts/session-init.sh"
    "scripts/session-monitor.sh"
    "scripts/userprompt-inject-policy.sh"
    "scripts/sync-plugin-cache.sh"
    "scripts/track-changes.sh"
    "scripts/analyze-project.sh"
    "scripts/setup-existing-project.sh"
    "scripts/stop-cleanup-check.sh"
    "scripts/stop-plans-reminder.sh"
    "scripts/lib/harness-mem-bridge.sh"
    "scripts/hook-handlers/memory-bridge.sh"
    "scripts/hook-handlers/memory-session-start.sh"
    "scripts/hook-handlers/memory-user-prompt.sh"
    "scripts/hook-handlers/memory-post-tool-use.sh"
    "scripts/hook-handlers/memory-stop.sh"
    "scripts/hook-handlers/memory-codex-notify.sh"
    "hooks/hooks.json"
    ".claude-plugin/hooks.json"
    ".claude-plugin/plugin.json"
    "VERSION"
  )

  for rel_path in "${critical_files[@]}"; do
    local source_file="$plugin_source/$rel_path"
    local cache_file="$cache_dir/$rel_path"

    if files_differ "$source_file" "$cache_file"; then
      mkdir -p "$(dirname "$cache_file")"
      cp "$source_file" "$cache_file"
      echo -e "  ${GREEN}✓${NC} $rel_path" >&2
      synced=$((synced + 1))
    fi
  done

  printf "%d" "$synced"
}

# ===== 主处理 =====
# 注意：Claude Code 只显示 hook 的 stderr，因此输出到 stderr
main() {
  local SOURCE_VERSION=$(get_source_version)

  # 调试信息（通过环境变量启用）
  if [ "${CC_HARNESS_DEBUG:-0}" = "1" ]; then
    echo -e "${BLUE}[Debug] Plugin source: $PLUGIN_SOURCE${NC}" >&2
    echo -e "${BLUE}[Debug] Source version: $SOURCE_VERSION${NC}" >&2
    echo -e "${BLUE}[Debug] Cache base: $CACHE_BASE${NC}" >&2
  fi

  # 如果缓存目录不存在
  if [ ! -d "$CACHE_BASE" ]; then
    echo -e "${YELLOW}⚠️ 未找到缓存${NC}" >&2
    return 0
  fi

  # 对所有缓存版本进行同步
  local total_synced=0
  for cache_version_dir in "$CACHE_BASE"/*/; do
    [ ! -d "$cache_version_dir" ] && continue

    local cache_version=$(basename "$cache_version_dir")
    local CACHE_DIR="$cache_version_dir"

    if [ "${CC_HARNESS_DEBUG:-0}" = "1" ]; then
      echo -e "${BLUE}[Debug] Checking cache: $cache_version${NC}" >&2
    fi

    # 检查文件差异（包含 VERSION）
    local needs_sync=false
    for rel_path in \
      "VERSION" \
      "scripts/pretooluse-guard.sh" \
      "scripts/posttooluse-log-toolname.sh" \
      "scripts/session-init.sh" \
      "scripts/lib/harness-mem-bridge.sh" \
      "scripts/hook-handlers/memory-bridge.sh" \
      "scripts/hook-handlers/memory-session-start.sh" \
      "scripts/hook-handlers/memory-user-prompt.sh" \
      "scripts/hook-handlers/memory-post-tool-use.sh" \
      "scripts/hook-handlers/memory-stop.sh" \
      "scripts/hook-handlers/memory-codex-notify.sh"
    do
      if files_differ "$PLUGIN_SOURCE/$rel_path" "$CACHE_DIR/$rel_path"; then
        needs_sync=true
        break
      fi
    done

    if [ "$needs_sync" = true ]; then
      echo -e "${YELLOW}🔄 正在同步缓存 v$cache_version...${NC}" >&2
      SYNCED=$(sync_critical_files "$CACHE_DIR" "$PLUGIN_SOURCE")
      total_synced=$((total_synced + SYNCED))
    fi
  done

  if [ "$total_synced" -gt 0 ]; then
    echo -e "${GREEN}✅ 已同步共 $total_synced 个文件${NC}" >&2
  fi
}

main "$@"
