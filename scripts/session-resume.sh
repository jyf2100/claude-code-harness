#!/bin/bash
# session-resume.sh
# SessionStart Hook (resume): Harness 会话状态自动恢复
#
# 在 Claude Code 执行 /resume 命令时自动调用，
# 恢复 Harness 的会话状态（session.json, session.events.jsonl）。
#
# 输入: 从 stdin 读取 JSON（包含 session_id, source 等）
# 输出: 以 JSON 格式输出到 hookSpecificOutput.additionalContext

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_SNAPSHOT_LIB="${SCRIPT_DIR}/lib/progress-snapshot.sh"
if [ -f "${PROGRESS_SNAPSHOT_LIB}" ]; then
  # shellcheck source=/dev/null
  source "${PROGRESS_SNAPSHOT_LIB}"
fi

# ===== 横幅显示 =====
VERSION=$(cat "$SCRIPT_DIR/../VERSION" 2>/dev/null || echo "unknown")
echo -e "\033[0;36m[claude-code-harness v${VERSION}]\033[0m Session resumed" >&2

# ===== 从 stdin 读取 JSON 输入 =====
INPUT=""
if [ -t 0 ]; then
  :
else
  INPUT=$(cat 2>/dev/null || true)
fi

# ===== 获取 Claude Code session_id =====
CC_SESSION_ID=""
if [ -n "$INPUT" ] && command -v jq >/dev/null 2>&1; then
  CC_SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
fi

# ===== Harness 状态目录（以 repo root 为基准统一） =====
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || REPO_ROOT="$(pwd)"
STATE_DIR="${REPO_ROOT}/.claude/state"
SESSION_FILE="$STATE_DIR/session.json"
EVENT_LOG_FILE="$STATE_DIR/session.events.jsonl"
ARCHIVE_DIR="$STATE_DIR/sessions"
SESSION_MAP_FILE="$STATE_DIR/session-map.json"

mkdir -p "$STATE_DIR" "$ARCHIVE_DIR"

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

# ===== 累积输出消息 =====
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

# ===== 会话恢复逻辑 =====
RESTORED="false"
RESTORED_SESSION_ID=""
RESTORE_METHOD=""

# 方法1: 从会话映射中搜索
if [ -n "$CC_SESSION_ID" ] && [ -f "$SESSION_MAP_FILE" ] && command -v jq >/dev/null 2>&1; then
  HARNESS_SESSION_ID="$(jq -r --arg cc_id "$CC_SESSION_ID" '.[$cc_id] // empty' "$SESSION_MAP_FILE" 2>/dev/null)"

  if [ -n "$HARNESS_SESSION_ID" ]; then
    ARCHIVE_SESSION="$ARCHIVE_DIR/${HARNESS_SESSION_ID}.json"
    ARCHIVE_EVENTS="$ARCHIVE_DIR/${HARNESS_SESSION_ID}.events.jsonl"

    if [ -f "$ARCHIVE_SESSION" ]; then
      cp "$ARCHIVE_SESSION" "$SESSION_FILE"
      [ -f "$ARCHIVE_EVENTS" ] && cp "$ARCHIVE_EVENTS" "$EVENT_LOG_FILE"

      # 更新状态为 initialized，并记录 resume 事件
      NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      if command -v jq >/dev/null 2>&1; then
        tmp_file=$(mktemp)
        jq --arg state "initialized" \
           --arg resumed_at "$NOW" \
           '.state = $state | .resumed_at = $resumed_at' \
           "$SESSION_FILE" > "$tmp_file" && mv "$tmp_file" "$SESSION_FILE"
      fi

      # 记录 resume 事件
      echo "{\"type\":\"session.resume\",\"ts\":\"$NOW\",\"state\":\"initialized\",\"data\":{\"cc_session_id\":\"$CC_SESSION_ID\",\"method\":\"mapping\"}}" >> "$EVENT_LOG_FILE"

      RESTORED="true"
      RESTORED_SESSION_ID="$HARNESS_SESSION_ID"
      RESTORE_METHOD="mapping"
    fi
  fi
fi

# 方法2: 自动恢复最新的 stopped 会话（无映射时）
if [ "$RESTORED" = "false" ]; then
  LATEST_ARCHIVE=$(ls -t "$ARCHIVE_DIR"/*.json 2>/dev/null | head -n 1 || true)

  if [ -n "$LATEST_ARCHIVE" ] && [ -f "$LATEST_ARCHIVE" ]; then
    HARNESS_SESSION_ID=$(basename "$LATEST_ARCHIVE" .json)
    ARCHIVE_EVENTS="$ARCHIVE_DIR/${HARNESS_SESSION_ID}.events.jsonl"

    cp "$LATEST_ARCHIVE" "$SESSION_FILE"
    [ -f "$ARCHIVE_EVENTS" ] && cp "$ARCHIVE_EVENTS" "$EVENT_LOG_FILE"

    NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    if command -v jq >/dev/null 2>&1; then
      tmp_file=$(mktemp)
      jq --arg state "initialized" \
         --arg resumed_at "$NOW" \
         '.state = $state | .resumed_at = $resumed_at' \
         "$SESSION_FILE" > "$tmp_file" && mv "$tmp_file" "$SESSION_FILE"
    fi

    echo "{\"type\":\"session.resume\",\"ts\":\"$NOW\",\"state\":\"initialized\",\"data\":{\"cc_session_id\":\"$CC_SESSION_ID\",\"method\":\"latest\"}}" >> "$EVENT_LOG_FILE"

    RESTORED="true"
    RESTORED_SESSION_ID="$HARNESS_SESSION_ID"
    RESTORE_METHOD="latest"
  fi
fi

# 方法3: 无恢复目标时进行新初始化
if [ "$RESTORED" = "false" ]; then
  # 执行与 session-init.sh 相当的初始化
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  NEW_SESSION_ID="session-$(date +%s)"

  cat > "$SESSION_FILE" <<EOF
{
  "session_id": "$NEW_SESSION_ID",
  "parent_session_id": null,
  "state": "initialized",
  "started_at": "$NOW",
  "updated_at": "$NOW",
  "resumed_at": "$NOW",
  "event_seq": 0,
  "last_event_id": ""
}
EOF

  echo "{\"type\":\"session.start\",\"ts\":\"$NOW\",\"state\":\"initialized\",\"data\":{\"cc_session_id\":\"$CC_SESSION_ID\",\"note\":\"no_archive_found\"}}" > "$EVENT_LOG_FILE"

  RESTORED_SESSION_ID="$NEW_SESSION_ID"
  RESTORE_METHOD="new"
fi

# ===== 保存与 Claude Code session_id 的映射 =====
if [ -n "$CC_SESSION_ID" ] && [ -n "$RESTORED_SESSION_ID" ]; then
  if command -v jq >/dev/null 2>&1; then
    if [ -f "$SESSION_MAP_FILE" ]; then
      tmp_file=$(mktemp)
      jq --arg cc_id "$CC_SESSION_ID" --arg harness_id "$RESTORED_SESSION_ID" \
         '.[$cc_id] = $harness_id' "$SESSION_MAP_FILE" > "$tmp_file" && mv "$tmp_file" "$SESSION_MAP_FILE"
    else
      echo "{\"$CC_SESSION_ID\":\"$RESTORED_SESSION_ID\"}" > "$SESSION_MAP_FILE"
    fi
  fi
fi

# ===== 会话间通信的注册 =====
# 将自己注册到 active.json（使其他会话可以识别）
if [ -f "$SCRIPT_DIR/session-register.sh" ]; then
  bash "$SCRIPT_DIR/session-register.sh" "$RESTORED_SESSION_ID" 2>/dev/null || true
fi

# ===== Skills Gate 初始化（与 session-init.sh 相同） =====
SESSION_SKILLS_USED_FILE="${STATE_DIR}/session-skills-used.json"
echo '{"used": [], "session_start": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$SESSION_SKILLS_USED_FILE"

# ===== 清除 SSOT 同步标志（新会话/恢复会话开始时） =====
# 此标志在执行 /sync-ssot-from-memory 时创建，
# 用于 Plans.md 清理前的 SSOT 同步确认
rm -f "${STATE_DIR}/.ssot-synced-this-session" 2>/dev/null || true

# 清除 ultrawork 警告标志（会话恢复时）
# 此标志用于在 userprompt-inject-policy.sh 中仅警告一次
# 恢复时清除，以便在恢复后的第一个提示中重新显示警告
# 向后兼容：清除两个标志名
rm -f "${STATE_DIR}/.work-review-warned" 2>/dev/null || true
rm -f "${STATE_DIR}/.ultrawork-review-warned" 2>/dev/null || true

# ===== Plans.md 检查 =====
PLANS_INFO=""
if [ -f "Plans.md" ]; then
  wip_count="$(count_matches "cc:WIP\\|pm:依頼中\\|cursor:依頼中" "Plans.md")"
  todo_count="$(count_matches "cc:TODO" "Plans.md")"
  PLANS_INFO="📄 Plans.md: 进行中 ${wip_count} / 未开始 ${todo_count}"
else
  PLANS_INFO="📄 Plans.md: 未检测到"
fi

SNAPSHOT_INFO=""
if declare -F progress_snapshot_summary >/dev/null 2>&1; then
  SNAPSHOT_INFO="$(progress_snapshot_summary "${STATE_DIR}" 2>/dev/null || true)"
fi

# ===== active_skill 检测（检查是否需要重启技能） =====
ACTIVE_SKILL_INFO=""
if [ -f "$SESSION_FILE" ] && command -v jq >/dev/null 2>&1; then
  ACTIVE_SKILL=$(jq -r '.active_skill // empty' "$SESSION_FILE" 2>/dev/null)
  ACTIVE_SKILL_STARTED=$(jq -r '.active_skill_started_at // "未知"' "$SESSION_FILE" 2>/dev/null)

  if [ -n "$ACTIVE_SKILL" ]; then
    ACTIVE_SKILL_INFO="
## ⚠️ MANDATORY: ${ACTIVE_SKILL} Session Recovery

**上次会话中 \`/${ACTIVE_SKILL}\` 正在运行（开始: ${ACTIVE_SKILL_STARTED}）**

**必须操作:**
1. 使用 \`/${ACTIVE_SKILL} 继续\` 重启技能
2. 请勿在未重启技能的情况下直接开始实现
3. 没有技能上下文时 review_status 保护将无法正常工作

如果不重启技能:
- 强制审查将无法工作
- 上次失败的学习内容将不会被继承
- 完成检查将不完整
"
  fi
fi

# ===== Work 模式检测和 harness-review 必须的再注入 =====
WORK_INFO=""
WORK_FILE="${STATE_DIR}/work-active.json"
# 向后兼容: 如果没有 work-active.json 则尝试 ultrawork-active.json
if [ ! -f "$WORK_FILE" ]; then
  WORK_FILE="${STATE_DIR}/ultrawork-active.json"
fi
if [ -f "$WORK_FILE" ] && command -v jq >/dev/null 2>&1; then
  REVIEW_STATUS=$(jq -r '.review_status // "pending"' "$WORK_FILE" 2>/dev/null)
  STARTED_AT=$(jq -r '.started_at // "未知"' "$WORK_FILE" 2>/dev/null)

  case "$REVIEW_STATUS" in
    "passed")
      WORK_INFO="⚡ **work 模式继续中** (开始: ${STARTED_AT})\n   ✅ review_status: passed → 可进行完成处理"
      ;;
    "failed")
      WORK_INFO="⚡ **work 模式继续中** (开始: ${STARTED_AT})\n   ❌ review_status: failed → 修正后请重新执行 /harness-review"
      ;;
    *)
      WORK_INFO="⚡ **work 模式继续中** (开始: ${STARTED_AT})\n   ⚠️ review_status: pending → **完成前请通过 /harness-review 获得 APPROVE**"
      ;;
  esac
fi

# ===== 构建输出消息 =====
add_line "# [claude-code-harness] 会话恢复"
add_line ""

case "$RESTORE_METHOD" in
  "mapping")
    add_line "✅ 已恢复会话状态（从映射中检测）"
    add_line "   Harness Session: ${RESTORED_SESSION_ID}"
    ;;
  "latest")
    add_line "✅ 已恢复最新的会话状态"
    add_line "   Harness Session: ${RESTORED_SESSION_ID}"
    ;;
  "new")
    add_line "ℹ️ 无可恢复的会话，已进行新初始化"
    add_line "   Harness Session: ${RESTORED_SESSION_ID}"
    ;;
esac

add_line ""

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

# 添加 active_skill 重启指示（最优先显示）
if [ -n "$ACTIVE_SKILL_INFO" ]; then
  add_line ""
  add_line "$ACTIVE_SKILL_INFO"
fi

# 添加 ultrawork 模式信息
if [ -n "$WORK_INFO" ]; then
  add_line ""
  add_line "$WORK_INFO"
fi

# ===== JSON 输出 =====
ESCAPED_OUTPUT=$(echo -e "$OUTPUT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"${ESCAPED_OUTPUT}"}}
EOF

exit 0
