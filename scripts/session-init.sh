#!/bin/bash
# session-init.sh
# SessionStart Hook: 会话开始时的初始化处理
#
# 功能:
# 1. 插件缓存的完整性检查和同步
# 2. Skills Gate 的初始化
# 3. Plans.md 的状态显示
#
# 输出: JSON格式输出到 hookSpecificOutput.additionalContext
#       → Claude Code 作为 system-reminder 显示

set -euo pipefail

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_SNAPSHOT_LIB="${SCRIPT_DIR}/lib/progress-snapshot.sh"
if [ -f "${PROGRESS_SNAPSHOT_LIB}" ]; then
  # shellcheck source=/dev/null
  source "${PROGRESS_SNAPSHOT_LIB}"
fi

# ===== 横幅显示（通过 stderr 在终端显示） =====
VERSION=$(cat "$SCRIPT_DIR/../VERSION" 2>/dev/null || echo "unknown")
echo -e "\033[0;36m[claude-code-harness v${VERSION}]\033[0m Session initialized" >&2

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

# ===== 从 stdin 读取 JSON 输入 =====
INPUT=""
if [ -t 0 ]; then
  : # stdin 为 TTY 时无输入
else
  INPUT=$(cat 2>/dev/null || true)
fi

# ===== agent_type / session_id 判定（Claude Code v2.1.2+） =====
AGENT_TYPE=""
CC_SESSION_ID=""
if [ -n "$INPUT" ]; then
  if command -v jq >/dev/null 2>&1; then
    AGENT_TYPE="$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)"
    CC_SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
  fi
fi

# 子代理时采用轻量初始化（早期 return）
# - 跳过插件缓存同步
# - 跳过 Skills Gate 初始化
# - 跳过 Plans.md 检查
# - 跳过模板更新检查
# - 跳过新规则文件检查
# - 跳过旧钩子配置检测
if [ "$AGENT_TYPE" = "subagent" ]; then
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[subagent] 轻量初始化完成"}}
EOF
  exit 0
fi

# ===== Hook 使用状况记录 =====
if [ -x "$SCRIPT_DIR/record-usage.js" ] && command -v node >/dev/null 2>&1; then
  node "$SCRIPT_DIR/record-usage.js" hook session-init >/dev/null 2>&1 &
fi

# 累积输出消息的变量
OUTPUT=""

add_line() {
  OUTPUT="${OUTPUT}$1\n"
}

count_matches() {
  local pattern="$1"
  local file="$2"
  local count
  count="$(grep -c "$pattern" "$file" 2>/dev/null || true)"
  printf '%s' "${count:-0}"
}

# ===== Step 1: 插件缓存同步 =====
if [ -f "$SCRIPT_DIR/sync-plugin-cache.sh" ]; then
  # 同步处理静默执行
  bash "$SCRIPT_DIR/sync-plugin-cache.sh" >/dev/null 2>&1 || true
fi

# ===== Step 1.5: Symlink 健全性检查（Windows 兼容） =====
# 自动修复 Windows git clone 时 symlink 损坏的问题
SYMLINK_INFO=""
if [ -f "$SCRIPT_DIR/fix-symlinks.sh" ]; then
  FIX_RESULT=$(bash "$SCRIPT_DIR/fix-symlinks.sh" 2>/dev/null || echo '{"fixed":0}')
  if command -v jq >/dev/null 2>&1; then
    SYMLINK_FIXED=$(echo "$FIX_RESULT" | jq -r '.fixed // 0' 2>/dev/null)
    if [ "$SYMLINK_FIXED" -gt 0 ] 2>/dev/null; then
      SYMLINK_DETAILS=$(echo "$FIX_RESULT" | jq -r '.details | join(", ")' 2>/dev/null)
      SYMLINK_INFO="🔧 Symlink 自动修复: 已修复 ${SYMLINK_FIXED} 项 (${SYMLINK_DETAILS})"
      echo -e "\033[1;33m[FIX]\033[0m Broken symlinks repaired: ${SYMLINK_FIXED} skills" >&2
    fi
  fi
fi

# ===== Step 2: Skills Gate 初始化 =====
# Resolve to git repository root for consistency with other hooks
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || REPO_ROOT="$(pwd)"
STATE_DIR="${REPO_ROOT}/.claude/state"
SKILLS_CONFIG_FILE="${STATE_DIR}/skills-config.json"
SESSION_SKILLS_USED_FILE="${STATE_DIR}/session-skills-used.json"

mkdir -p "$STATE_DIR"

# 重置 session-skills-used.json（新会话开始）
echo '{"used": [], "session_start": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$SESSION_SKILLS_USED_FILE"

RESUME_CONTEXT_FILE="${STATE_DIR}/memory-resume-context.md"
RESUME_PENDING_FLAG="${STATE_DIR}/.memory-resume-pending"
RESUME_PROCESSING_FLAG="${STATE_DIR}/.memory-resume-processing"
RESUME_MAX_BYTES="${HARNESS_MEM_RESUME_MAX_BYTES:-32768}"

case "$RESUME_MAX_BYTES" in
  ''|*[!0-9]*) RESUME_MAX_BYTES=32768 ;;
esac
if [ "$RESUME_MAX_BYTES" -gt 65536 ]; then
  RESUME_MAX_BYTES=65536
fi
if [ "$RESUME_MAX_BYTES" -lt 4096 ]; then
  RESUME_MAX_BYTES=4096
fi

consume_memory_resume_context() {
  local file="$1"
  local max_bytes="$2"
  local total=0
  local line=""
  local line_bytes=0
  local out=""

  if [ ! -f "$file" ]; then
    return 0
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    line_bytes="$(printf '%s\n' "$line" | wc -c | tr -d '[:space:]')"
    case "$line_bytes" in
      ''|*[!0-9]*) line_bytes=0 ;;
    esac
    if [ $((total + line_bytes)) -gt "$max_bytes" ]; then
      break
    fi
    out="${out}${line}
"
    total=$((total + line_bytes))
  done < "$file"

  rm -f "$RESUME_PENDING_FLAG" "$RESUME_PROCESSING_FLAG" "$RESUME_CONTEXT_FILE" 2>/dev/null || true
  printf '%s' "$out"
}

# 清除 SSOT 同步标志（新会话开始时）
# 此标志在执行 /sync-ssot-from-memory 时创建，
# 用于 Plans.md 清理前的 SSOT 同步确认
rm -f "${STATE_DIR}/.ssot-synced-this-session" 2>/dev/null || true

# 清除 work 警告标志（新会话开始时）
# 此标志用于在 userprompt-inject-policy.sh 中仅警告一次
# 向后兼容: 清除两个标志名
rm -f "${STATE_DIR}/.work-review-warned" 2>/dev/null || true
rm -f "${STATE_DIR}/.ultrawork-review-warned" 2>/dev/null || true

# ===== Step 2.5: Harness 会话初始化 & CC session_id 映射 =====
SESSION_FILE="${STATE_DIR}/session.json"
SESSION_MAP_FILE="${STATE_DIR}/session-map.json"
ARCHIVE_DIR="${STATE_DIR}/sessions"
mkdir -p "$ARCHIVE_DIR"

# 为新会话生成 Harness session_id
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
HARNESS_SESSION_ID="session-$(date +%s)"

# 初始化 session.json（不存在时或处于 stopped 状态时）
INIT_NEW_SESSION="false"
if [ ! -f "$SESSION_FILE" ]; then
  INIT_NEW_SESSION="true"
elif command -v jq >/dev/null 2>&1; then
  CURRENT_STATE="$(jq -r '.state // "idle"' "$SESSION_FILE" 2>/dev/null)"
  if [ "$CURRENT_STATE" = "stopped" ] || [ "$CURRENT_STATE" = "completed" ] || [ "$CURRENT_STATE" = "failed" ]; then
    INIT_NEW_SESSION="true"
  fi
fi

if [ "$INIT_NEW_SESSION" = "true" ]; then
  cat > "$SESSION_FILE" <<SESSEOF
{
  "session_id": "$HARNESS_SESSION_ID",
  "parent_session_id": null,
  "state": "initialized",
  "started_at": "$NOW",
  "updated_at": "$NOW",
  "event_seq": 0,
  "last_event_id": ""
}
SESSEOF

  # 初始化事件日志
  echo "{\"type\":\"session.start\",\"ts\":\"$NOW\",\"state\":\"initialized\",\"data\":{\"cc_session_id\":\"$CC_SESSION_ID\"}}" > "${STATE_DIR}/session.events.jsonl"
else
  # 获取现有会话的 session_id
  if command -v jq >/dev/null 2>&1; then
    HARNESS_SESSION_ID="$(jq -r '.session_id // empty' "$SESSION_FILE" 2>/dev/null)"
  fi
fi

# 保存 CC session_id 和 Harness session_id 的映射
if [ -n "$CC_SESSION_ID" ] && [ -n "$HARNESS_SESSION_ID" ]; then
  if command -v jq >/dev/null 2>&1; then
    if [ -f "$SESSION_MAP_FILE" ]; then
      tmp_file=$(mktemp)
      jq --arg cc_id "$CC_SESSION_ID" --arg harness_id "$HARNESS_SESSION_ID" \
         '.[$cc_id] = $harness_id' "$SESSION_MAP_FILE" > "$tmp_file" && mv "$tmp_file" "$SESSION_MAP_FILE"
    else
      echo "{\"$CC_SESSION_ID\":\"$HARNESS_SESSION_ID\"}" > "$SESSION_MAP_FILE"
    fi
  fi
fi

# ===== Step 2.6: 会话间通信的注册 =====
# 将自己注册到 active.json（使其他会话可以识别）
if [ -f "$SCRIPT_DIR/session-register.sh" ]; then
  bash "$SCRIPT_DIR/session-register.sh" "$HARNESS_SESSION_ID" 2>/dev/null || true
fi

# 读取和显示 skills-config.json
SKILLS_INFO=""
if [ -f "$SKILLS_CONFIG_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    SKILLS_ENABLED=$(jq -r '.enabled // false' "$SKILLS_CONFIG_FILE" 2>/dev/null)
    SKILLS_LIST=$(jq -r '.skills // [] | join(", ")' "$SKILLS_CONFIG_FILE" 2>/dev/null)

    if [ "$SKILLS_ENABLED" = "true" ] && [ -n "$SKILLS_LIST" ]; then
      SKILLS_INFO="🎯 Skills Gate: 已启用 (${SKILLS_LIST})"
    fi
  fi
fi

# ===== Step 3: Plans.md 检查 =====
# 考虑 plansDirectory 设置
PLANS_PATH="Plans.md"
if [ -f "${SCRIPT_DIR}/config-utils.sh" ]; then
  source "${SCRIPT_DIR}/config-utils.sh"
  PLANS_PATH=$(get_plans_file_path)
fi

PLANS_INFO=""
if [ -f "$PLANS_PATH" ]; then
  wip_count="$(count_matches "cc:WIP\\|pm:依頼中\\|cursor:依頼中" "$PLANS_PATH")"
  todo_count="$(count_matches "cc:TODO" "$PLANS_PATH")"

  PLANS_INFO="📄 Plans.md: 进行中 ${wip_count} / 未开始 ${todo_count}"
else
  PLANS_INFO="📄 Plans.md: 未检测到"
fi

SNAPSHOT_INFO=""
if declare -F progress_snapshot_summary >/dev/null 2>&1; then
  SNAPSHOT_INFO="$(progress_snapshot_summary "${STATE_DIR}" 2>/dev/null || true)"
fi

# ===== Step 4: 模板更新检查 =====
TEMPLATE_INFO=""
TEMPLATE_TRACKER="$SCRIPT_DIR/template-tracker.sh"

if [ -f "$TEMPLATE_TRACKER" ] && [ -f "$SCRIPT_DIR/../templates/template-registry.json" ]; then
  # 如果 generated-files.json 不存在则初始化
  if [ ! -f "${STATE_DIR}/generated-files.json" ]; then
    bash "$TEMPLATE_TRACKER" init >/dev/null 2>&1 || true
    TEMPLATE_INFO="📦 模板追踪: 初始化完成"
  else
    # 更新检查（解析 JSON 输出）
    CHECK_RESULT=$(bash "$TEMPLATE_TRACKER" check 2>/dev/null || echo '{"needsCheck": false}')

    if command -v jq >/dev/null 2>&1; then
      NEEDS_CHECK=$(echo "$CHECK_RESULT" | jq -r '.needsCheck // false')
      UPDATES_COUNT=$(echo "$CHECK_RESULT" | jq -r '.updatesCount // 0')
      INSTALLS_COUNT=$(echo "$CHECK_RESULT" | jq -r '.installsCount // 0')

      if [ "$NEEDS_CHECK" = "true" ]; then
        parts=()

        # 需要更新的文件
        if [ "$UPDATES_COUNT" -gt 0 ]; then
          LOCALIZED_COUNT=$(echo "$CHECK_RESULT" | jq '[.updates[] | select(.localized == true)] | length')
          OVERWRITE_COUNT=$((UPDATES_COUNT - LOCALIZED_COUNT))

          if [ "$OVERWRITE_COUNT" -gt 0 ]; then
            parts+=("可更新: ${OVERWRITE_COUNT}")
          fi
          if [ "$LOCALIZED_COUNT" -gt 0 ]; then
            parts+=("需合并: ${LOCALIZED_COUNT}")
          fi
        fi

        # 需要新安装的文件
        if [ "$INSTALLS_COUNT" -gt 0 ]; then
          parts+=("新增: ${INSTALLS_COUNT}")
        fi

        if [ ${#parts[@]} -gt 0 ]; then
          TEMPLATE_INFO="⚠️ 模板更新: $(IFS=', '; echo "${parts[*]}") → 使用 \`/harness-update\` 确认"
        fi
      fi
    fi
  fi
fi

# ===== Step 5: 新增规则文件检查 =====
# 当质量保护规则（v2.5.30+）未安装时进行通知
MISSING_RULES_INFO=""
RULES_DIR=".claude/rules"
QUALITY_RULES=("test-quality.md" "implementation-quality.md")
MISSING_RULES=()

if [ -d "$RULES_DIR" ]; then
  for rule in "${QUALITY_RULES[@]}"; do
    if [ ! -f "$RULES_DIR/$rule" ]; then
      MISSING_RULES+=("$rule")
    fi
  done

  if [ ${#MISSING_RULES[@]} -gt 0 ]; then
    MISSING_RULES_INFO="⚠️ 质量保护规则未安装: ${MISSING_RULES[*]} → 可通过 \`/harness-update\` 添加"
  fi
elif [ -f ".claude-code-harness-version" ]; then
  # 已安装 Harness 但 rules 目录不存在的情况
  MISSING_RULES_INFO="⚠️ 质量保护规则未安装 → 可通过 \`/harness-update\` 添加"
fi

# ===== Step 6: 旧版钩子配置检测 =====
# 仅检测命令路径包含 "claude-code-harness" 的钩子（排除用户自定义钩子）
OLD_HOOKS_INFO=""
SETTINGS_FILE=".claude/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    # 插件使用的事件类型
    PLUGIN_EVENTS=("PreToolUse" "SessionStart" "UserPromptSubmit" "PermissionRequest")
    OLD_HARNESS_EVENTS=()

    for event in "${PLUGIN_EVENTS[@]}"; then
      # 仅当事件存在且命令包含 "claude-code-harness" 时
      if jq -e ".hooks.${event}" "$SETTINGS_FILE" >/dev/null 2>&1; then
        COMMANDS=$(jq -r ".hooks.${event}[]?.hooks[]?.command // .hooks.${event}[]?.command // empty" "$SETTINGS_FILE" 2>/dev/null)
        if echo "$COMMANDS" | grep -q "claude-code-harness"; then
          OLD_HARNESS_EVENTS+=("$event")
        fi
      fi
    done

    if [ ${#OLD_HARNESS_EVENTS[@]} -gt 0 ]; then
      OLD_HOOKS_INFO="⚠️ 检测到旧版 Harness 钩子配置: ${OLD_HARNESS_EVENTS[*]} → 建议通过 \`/harness-update\` 删除"
    fi
  fi
fi

# ===== 构建输出消息 =====
add_line "# [claude-code-harness] 会话初始化"
add_line ""

# SIMPLE 模式警告（也输出到 additionalContext — 复用 check-simple-mode.sh 的警告文本）
if [ "$SIMPLE_MODE" = "true" ]; then
  add_line "⚠️ **CLAUDE_CODE_SIMPLE 模式检测** (CC v2.1.50+)"
  while IFS= read -r warning_line; do
    add_line "$warning_line"
  done <<< "$(simple_mode_warning ja)"
  add_line ""
fi

MEMORY_CONTEXT=""
if [ -f "$RESUME_PENDING_FLAG" ] || [ -f "$RESUME_CONTEXT_FILE" ]; then
  MEMORY_CONTEXT="$(consume_memory_resume_context "$RESUME_CONTEXT_FILE" "$RESUME_MAX_BYTES")"
fi

if [ -n "$MEMORY_CONTEXT" ]; then
  OUTPUT="${OUTPUT}${MEMORY_CONTEXT}"
  case "$MEMORY_CONTEXT" in
    *$'\n') ;;
    *) OUTPUT="${OUTPUT}\n" ;;
  esac
  add_line ""
fi

add_line "${PLANS_INFO}"

if [ -n "${SNAPSHOT_INFO}" ]; then
  add_line "${SNAPSHOT_INFO}"
fi

if [ -n "$SKILLS_INFO" ]; then
  add_line "${SKILLS_INFO}"
fi

if [ -n "$TEMPLATE_INFO" ]; then
  add_line "${TEMPLATE_INFO}"
fi

if [ -n "$MISSING_RULES_INFO" ]; then
  add_line "${MISSING_RULES_INFO}"
fi

if [ -n "$OLD_HOOKS_INFO" ]; then
  add_line "${OLD_HOOKS_INFO}"
fi

if [ -n "$SYMLINK_INFO" ]; then
  add_line "${SYMLINK_INFO}"
fi

add_line ""
add_line "## 标记图例"
add_line "| 标记 | 状态 | 说明 |"
add_line "|---------|------|------|"
add_line "| \`cc:TODO\` | 未开始 | Impl（Claude Code）计划执行 |"
add_line "| \`cc:WIP\` | 进行中 | Impl 正在实现 |"
add_line "| \`cc:blocked\` | 阻塞中 | 等待依赖任务 |"
add_line "| \`pm:依頼中\` | PM 请求 | 2-Agent 运作时 |"
add_line ""
add_line "> **兼容**: \`cursor:依頼中\` / \`cursor:確認済\` 与 \`pm:*\` 同义。"

# ===== JSON 输出 =====
# Claude Code 的 SessionStart hook 接受 JSON 格式的 hookSpecificOutput
# additionalContext 的内容作为 system-reminder 显示

# 转义处理（JSON用）
# 换行为 \n，双引号为 \"，反斜杠为 \\
escape_json() {
  local str="$1"
  str="${str//\\/\\\\}"      # 反斜杠
  str="${str//\"/\\\"}"      # 双引号
  str="${str//$'\n'/\\n}"    # 换行
  str="${str//$'\t'/\\t}"    # 制表符
  echo "$str"
}

ESCAPED_OUTPUT=$(echo -e "$OUTPUT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"${ESCAPED_OUTPUT}"}}
EOF

exit 0
