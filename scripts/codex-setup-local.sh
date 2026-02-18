#!/bin/bash
#
# codex-setup-local.sh
#
# Copy Codex CLI templates from the installed Harness plugin.
#
# Usage:
#   ./scripts/codex-setup-local.sh [--user|--project] [--with-mcp|--skip-mcp]
#
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(pwd)"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
WITH_MCP="auto"
TARGET_MODE="user"

while [ $# -gt 0 ]; do
  case "$1" in
    --with-mcp)
      WITH_MCP=true
      ;;
    --skip-mcp)
      WITH_MCP=false
      ;;
    --user)
      TARGET_MODE="user"
      ;;
    --project)
      TARGET_MODE="project"
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--user|--project] [--with-mcp|--skip-mcp]" >&2
      exit 1
      ;;
  esac
  shift
done

fail() {
  echo "Error: $1" >&2
  exit 1
}

pick_latest_version_dir() {
  local base_dir="$1"
  if [ ! -d "$base_dir" ]; then
    return 1
  fi

  local latest
  latest="$(ls -1 "$base_dir" 2>/dev/null | sort -V | tail -n 1)"
  if [ -z "$latest" ]; then
    return 1
  fi
  echo "$base_dir/$latest"
}

resolve_plugin_dir() {
  local repo_root
  repo_root="$(cd "$SCRIPT_DIR/.." && pwd)"

  local marketplace_dir="$HOME/.claude/plugins/marketplaces/claude-code-harness-marketplace"
  local cache_root="$HOME/.claude/plugins/cache/claude-code-harness-marketplace/claude-code-harness"
  local cache_dir
  cache_dir="$(pick_latest_version_dir "$cache_root" || true)"

  local candidates=(
    "${CLAUDE_PLUGIN_ROOT:-}"
    "$repo_root"
    "$marketplace_dir"
    "$cache_dir"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    [ -n "$candidate" ] || continue
    if [ -d "$candidate/codex/.codex/skills" ]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

backup_path() {
  local target="$1"
  if [ -e "$target" ]; then
    local ts
    ts=$(date +%Y%m%d%H%M%S)
    mv "$target" "${target}.backup.${ts}"
    echo "Backed up $target to ${target}.backup.${ts}"
  fi
}

sync_named_children() {
  local src_dir="$1"
  local dst_dir="$2"
  local label="$3"

  [ -d "$src_dir" ] || fail "$label source not found: $src_dir"
  mkdir -p "$dst_dir"

  local copied=0
  local entry
  for entry in "$src_dir"/*; do
    [ -e "$entry" ] || continue
    local name
    name="$(basename "$entry")"
    local dst_path="$dst_dir/$name"

    if [ -e "$dst_path" ]; then
      backup_path "$dst_path"
    fi

    cp -R "$entry" "$dst_dir/"
    copied=$((copied + 1))
  done

  echo "$label synced to $dst_dir ($copied items)"
}

copy_project_agents() {
  local plugin_dir="$1"
  local agents_src="$plugin_dir/codex/AGENTS.md"
  local agents_dst="$PROJECT_DIR/AGENTS.md"

  [ -f "$agents_src" ] || fail "codex/AGENTS.md not found in plugin source"

  if [ -f "$agents_dst" ]; then
    backup_path "$agents_dst"
  fi

  cp "$agents_src" "$agents_dst"
  echo "AGENTS.md copied to project root"
}

setup_mcp_template() {
  local plugin_dir="$1"
  local target_root="$2"

  [ "$WITH_MCP" = true ] || return 0

  local src="$plugin_dir/codex/.codex/config.toml"
  local dst="$target_root/config.toml"

  if [ -f "$dst" ]; then
    echo "Warning: $dst already exists, skipping"
    return 0
  fi

  if [ -f "$src" ]; then
    mkdir -p "$target_root"
    cp "$src" "$dst"
    echo "config.toml copied to: $dst"
    echo "Edit MCP server/notify paths for your environment"
  else
    echo "Warning: codex/.codex/config.toml not found in plugin source"
  fi
}

PLUGIN_DIR="$(resolve_plugin_dir || true)"
if [ -z "$PLUGIN_DIR" ]; then
  fail "Harness plugin directory not found. Set CLAUDE_PLUGIN_ROOT or install the plugin."
fi

echo "Using Harness plugin: $PLUGIN_DIR"

target_root=""
if [ "$TARGET_MODE" = "user" ]; then
  target_root="$CODEX_HOME_DIR"
  echo "Install mode: user (target: $target_root)"
else
  target_root="$PROJECT_DIR/.codex"
  echo "Install mode: project (target: $target_root)"
fi

sync_named_children "$PLUGIN_DIR/codex/.codex/skills" "$target_root/skills" "Skills"
sync_named_children "$PLUGIN_DIR/codex/.codex/rules" "$target_root/rules" "Rules"

if [ "$TARGET_MODE" = "project" ]; then
  copy_project_agents "$PLUGIN_DIR"
else
  echo "User mode: project AGENTS.md is unchanged"
fi

setup_mcp_template "$PLUGIN_DIR" "$target_root"

echo "Codex CLI setup complete."
if [ "$TARGET_MODE" = "user" ]; then
  echo "Restart Codex to reload user-level skills/rules if needed."
fi
