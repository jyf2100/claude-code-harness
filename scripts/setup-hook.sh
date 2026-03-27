#!/bin/bash
# setup-hook.sh
# Setup Hook: claude --init / --maintenance 时的设置处理
#
# Usage:
#   setup-hook.sh init        # 首次设置
#   setup-hook.sh maintenance # 维护处理
#
# 输出: JSON 格式输出 hookSpecificOutput

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-init}"

# ===== SIMPLE 模式检测 =====
SIMPLE_MODE="false"
if [ -f "$SCRIPT_DIR/check-simple-mode.sh" ]; then
  # shellcheck source=./check-simple-mode.sh
  source "$SCRIPT_DIR/check-simple-mode.sh"
  if is_simple_mode; then
    SIMPLE_MODE="true"
    echo -e "\033[1;33m[WARNING]\033[0m CLAUDE_CODE_SIMPLE mode detected — skills/agents/memory disabled" >&2
  fi
fi

# 从 stdin 读取 JSON 输入（Claude Code v2.1.10+）
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat 2>/dev/null || true)
fi

# ===== 通用辅助函数 =====
output_json() {
  local message="$1"
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"Setup","additionalContext":"$message"}}
EOF
}

# ===== Init 模式: 首次设置 =====
run_init() {
  local messages=()

  # 1. 插件缓存同步
  if [ -f "$SCRIPT_DIR/sync-plugin-cache.sh" ]; then
    bash "$SCRIPT_DIR/sync-plugin-cache.sh" >/dev/null 2>&1 || true
    messages+=("插件缓存同步完成")
  fi

  # 2. 状态目录初始化
  STATE_DIR=".claude/state"
  mkdir -p "$STATE_DIR"

  # 3. 生成默认配置文件（如不存在）
  CONFIG_FILE=".claude-code-harness.config.yaml"
  if [ ! -f "$CONFIG_FILE" ]; then
    if [ -f "$SCRIPT_DIR/../templates/.claude-code-harness.config.yaml.template" ]; then
      cp "$SCRIPT_DIR/../templates/.claude-code-harness.config.yaml.template" "$CONFIG_FILE"
      messages+=("配置文件生成完成")
    fi
  fi

  # 4. 生成 CLAUDE.md（如不存在）
  if [ ! -f "CLAUDE.md" ]; then
    if [ -f "$SCRIPT_DIR/../templates/CLAUDE.md.template" ]; then
      cp "$SCRIPT_DIR/../templates/CLAUDE.md.template" "CLAUDE.md"
      messages+=("CLAUDE.md 生成完成")
    fi
  fi

  # 5. 生成 Plans.md（如不存在）
  # 考虑 plansDirectory 设置
  if [ -f "$SCRIPT_DIR/config-utils.sh" ]; then
    source "$SCRIPT_DIR/config-utils.sh"
    PLANS_PATH=$(get_plans_file_path)
  else
    PLANS_PATH="Plans.md"
  fi

  if [ ! -f "$PLANS_PATH" ]; then
    # 如目录不存在则创建
    PLANS_DIR=$(dirname "$PLANS_PATH")
    [ "$PLANS_DIR" != "." ] && mkdir -p "$PLANS_DIR"

    if [ -f "$SCRIPT_DIR/../templates/Plans.md.template" ]; then
      cp "$SCRIPT_DIR/../templates/Plans.md.template" "$PLANS_PATH"
      messages+=("Plans.md 生成完成")
    fi
  fi

  # 6. 模板跟踪器初始化
  if [ -f "$SCRIPT_DIR/template-tracker.sh" ]; then
    bash "$SCRIPT_DIR/template-tracker.sh" init >/dev/null 2>&1 || true
  fi

  # 添加 SIMPLE 模式警告
  if [ "$SIMPLE_MODE" = "true" ]; then
    messages+=("WARNING: CLAUDE_CODE_SIMPLE mode — skills/agents/memory disabled, hooks only")
  fi

  # 输出结果
  if [ ${#messages[@]} -eq 0 ]; then
    output_json "[Setup:init] Harness 已经初始化完成"
  else
    local msg_str
    msg_str=$(IFS=', '; echo "${messages[*]}")
    output_json "[Setup:init] $msg_str"
  fi
}

# ===== Maintenance 模式: 维护处理 =====
run_maintenance() {
  local messages=()

  # 1. 插件缓存同步
  if [ -f "$SCRIPT_DIR/sync-plugin-cache.sh" ]; then
    bash "$SCRIPT_DIR/sync-plugin-cache.sh" >/dev/null 2>&1 || true
    messages+=("缓存同步完成")
  fi

  # 2. 清理旧会话文件
  STATE_DIR=".claude/state"
  ARCHIVE_DIR="$STATE_DIR/sessions"

  if [ -d "$ARCHIVE_DIR" ]; then
    # 删除 7 天前的会话归档
    find "$ARCHIVE_DIR" -name "session-*.json" -mtime +7 -delete 2>/dev/null || true
    messages+=("已删除旧会话归档")
  fi

  # 3. 清理临时文件
  if [ -d "$STATE_DIR" ]; then
    # 删除 .tmp 文件
    find "$STATE_DIR" -name "*.tmp" -delete 2>/dev/null || true
  fi

  # 4. 模板更新检查
  if [ -f "$SCRIPT_DIR/template-tracker.sh" ]; then
    CHECK_RESULT=$(bash "$SCRIPT_DIR/template-tracker.sh" check 2>/dev/null || echo '{"needsCheck": false}')
    if command -v jq >/dev/null 2>&1; then
      NEEDS_UPDATE=$(echo "$CHECK_RESULT" | jq -r '.needsCheck // false')
      if [ "$NEEDS_UPDATE" = "true" ]; then
        UPDATES_COUNT=$(echo "$CHECK_RESULT" | jq -r '.updatesCount // 0')
        messages+=("有模板更新: ${UPDATES_COUNT}项")
      fi
    fi
  fi

  # 5. 添加 SIMPLE 模式警告
  if [ "$SIMPLE_MODE" = "true" ]; then
    messages+=("WARNING: CLAUDE_CODE_SIMPLE mode — skills/agents/memory disabled, hooks only")
  fi

  # 6. 配置文件验证
  CONFIG_FILE=".claude-code-harness.config.yaml"
  if [ -f "$CONFIG_FILE" ]; then
    # 基本的 YAML 语法检查
    if command -v python3 >/dev/null 2>&1; then
      if ! python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
        messages+=("警告: 配置文件语法错误")
      fi
    fi
  fi

  # 输出结果
  if [ ${#messages[@]} -eq 0 ]; then
    output_json "[Setup:maintenance] 维护完成（无变更）"
  else
    local msg_str
    msg_str=$(IFS=', '; echo "${messages[*]}")
    output_json "[Setup:maintenance] $msg_str"
  fi
}

# ===== 主处理 =====
case "$MODE" in
  init)
    run_init
    ;;
  maintenance)
    run_maintenance
    ;;
  *)
    output_json "[Setup] 未知模式: $MODE"
    exit 1
    ;;
esac
