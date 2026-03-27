#!/bin/bash
# posttooluse-log-toolname.sh
# Phase0: 记录所有工具名到日志（用于 tool_name 发现）
# + LSP追踪: 检测 LSP 相关工具并更新 tooling-policy.json
#
# Usage: 从 PostToolUse hook 自动执行（matcher="*"）
# Input: stdin JSON (Claude Code hooks)
# Output:
#   - 追加 JSONL 到 .claude/state/tool-events.jsonl（仅 Phase0 日志启用时）
#   - 更新 .claude/state/tooling-policy.json（LSP 相关工具检测时，始终执行）
#
# 控制: 仅当 CC_HARNESS_PHASE0_LOG=1 时执行日志收集
#       （tool_name 确定后禁用，防止日志膨胀）
#       LSP 追踪始终执行（不依赖 matcher "LSP"，防止遗漏）

set +e

# ===== 常量 =====
STATE_DIR=".claude/state"
LOG_FILE="${STATE_DIR}/tool-events.jsonl"
LOCK_FILE="${STATE_DIR}/tool-events.lock"
SESSION_FILE="${STATE_DIR}/session.json"
EVENT_LOG_FILE="${STATE_DIR}/session.events.jsonl"
EVENT_LOCK_FILE="${STATE_DIR}/session-events.lock"
MAX_SIZE_BYTES=262144  # 256KB
MAX_LINES=2000
MAX_GENERATIONS=5

# ===== 工具函数 =====

# 获取锁（优先使用 flock，否则使用 mkdir 锁）
acquire_lock() {
  local lockfile="$1"
  local timeout=5
  local waited=0

  # 如果 flock 可用则使用 flock
  if command -v flock >/dev/null 2>&1; then
    exec 200>"$lockfile"
    flock -w "$timeout" 200 || return 1
    return 0
  fi

  # 如果 flock 不可用则使用 mkdir 锁（原子操作）
  while ! mkdir "$lockfile" 2>/dev/null; do
    sleep 0.1
    waited=$((waited + 1))
    if [ "$waited" -ge $((timeout * 10)) ]; then
      return 1
    fi
  done
  return 0
}

# 释放锁
release_lock() {
  local lockfile="$1"

  if command -v flock >/dev/null 2>&1; then
    exec 200>&-
  else
    rmdir "$lockfile" 2>/dev/null || true
  fi
}

# 执行日志轮转
rotate_log() {
  local logfile="$1"

  # 删除最旧的文件
  [ -f "${logfile}.${MAX_GENERATIONS}" ] && rm -f "${logfile}.${MAX_GENERATIONS}"

  # 依次重命名（.4 → .5, .3 → .4, ...）
  for i in $(seq $((MAX_GENERATIONS - 1)) -1 1); do
    [ -f "${logfile}.${i}" ] && mv "${logfile}.${i}" "${logfile}.$((i + 1))"
  done

  # 将当前日志移动到 .1
  [ -f "$logfile" ] && mv "$logfile" "${logfile}.1"

  # 创建新的日志文件
  touch "$logfile"
}

# 检查是否需要轮转
needs_rotation() {
  local logfile="$1"

  [ ! -f "$logfile" ] && return 1

  # 检查文件大小
  local size
  if command -v stat >/dev/null 2>&1; then
    # macOS/BSD
    size=$(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null || echo 0)
  else
    size=$(wc -c < "$logfile" 2>/dev/null || echo 0)
  fi

  if [ "$size" -ge "$MAX_SIZE_BYTES" ]; then
    return 0
  fi

  # 检查行数
  local lines
  lines=$(wc -l < "$logfile" 2>/dev/null || echo 0)
  if [ "$lines" -ge "$MAX_LINES" ]; then
    return 0
  fi

  return 1
}

# ===== 主处理 =====

# 创建 state 目录
mkdir -p "$STATE_DIR"

# 从 stdin 读取 JSON 输入
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

if [ -z "$INPUT" ]; then
  exit 0
fi

# 从 JSON 中提取所需字段（优先使用 jq，否则使用 python3）
TOOL_NAME=""
SESSION_ID=""
FILE_PATH=""
COMMAND=""

if command -v jq >/dev/null 2>&1; then
  TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
  SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
  FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
  COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  eval "$(printf '%s' "$INPUT" | python3 -c '
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
tool_name = data.get("tool_name") or ""
session_id = data.get("session_id") or ""
tool_input = data.get("tool_input") or {}
file_path = tool_input.get("file_path") or ""
command = tool_input.get("command") or ""
print(f"TOOL_NAME={shlex.quote(tool_name)}")
print(f"SESSION_ID={shlex.quote(session_id)}")
print(f"FILE_PATH={shlex.quote(file_path)}")
print(f"COMMAND={shlex.quote(command)}")
' 2>/dev/null)"
fi

# 如果没有 tool_name 则跳过
[ -z "$TOOL_NAME" ] && exit 0

# 从 session.json 获取 prompt_seq
PROMPT_SEQ=0
if [ -f "$SESSION_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    PROMPT_SEQ="$(jq -r '.prompt_seq // 0' "$SESSION_FILE" 2>/dev/null)"
  elif command -v python3 >/dev/null 2>&1; then
    PROMPT_SEQ="$(python3 -c "import json; print(json.load(open('$SESSION_FILE')).get('prompt_seq', 0))" 2>/dev/null || echo 0)"
  fi
fi

# ===== LSP 追踪（始终执行，避免依赖 matcher） =====
# 检测 LSP 相关工具（tool_name 包含 "lsp" 或 "LSP" 时）
if echo "$TOOL_NAME" | grep -iq "lsp"; then
  TOOLING_POLICY_FILE="${STATE_DIR}/tooling-policy.json"
  if [ -f "$TOOLING_POLICY_FILE" ]; then
    temp_file=$(mktemp)
    if command -v jq >/dev/null 2>&1; then
      jq --arg tool_name "$TOOL_NAME" \
         --argjson prompt_seq "$PROMPT_SEQ" \
         '.lsp.last_used_prompt_seq = $prompt_seq |
          .lsp.last_used_tool_name = $tool_name |
          .lsp.used_since_last_prompt = true' \
         "$TOOLING_POLICY_FILE" > "$temp_file" && mv "$temp_file" "$TOOLING_POLICY_FILE"
    elif command -v python3 >/dev/null 2>&1; then
      python3 <<PY > "$temp_file"
import json
with open("$TOOLING_POLICY_FILE", "r") as f:
    data = json.load(f)
data["lsp"]["last_used_prompt_seq"] = $PROMPT_SEQ
data["lsp"]["last_used_tool_name"] = "$TOOL_NAME"
data["lsp"]["used_since_last_prompt"] = True
print(json.dumps(data, indent=2))
PY
      mv "$temp_file" "$TOOLING_POLICY_FILE"
    fi
  fi
fi

# ===== Phase0 日志收集（仅当 CC_HARNESS_PHASE0_LOG=1 时） =====
if [ "${CC_HARNESS_PHASE0_LOG:-0}" = "1" ]; then
  # 时间戳（UTC ISO8601）
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

  # 创建 JSONL 条目（仅包含最小字段）
  JSONL_ENTRY=$(cat <<EOF
{"v":1,"ts":"$TIMESTAMP","session_id":"$SESSION_ID","prompt_seq":$PROMPT_SEQ,"hook_event_name":"PostToolUse","tool_name":"$TOOL_NAME"}
EOF
  )

  # 获取锁
  if ! acquire_lock "$LOCK_FILE"; then
    # 如果无法获取锁则跳过（失败也无妨）
    exit 0
  fi

  # 检查是否需要轮转
  if needs_rotation "$LOG_FILE"; then
    rotate_log "$LOG_FILE"
  fi

  # 追加日志（非原子操作，但受锁保护）
  echo "$JSONL_ENTRY" >> "$LOG_FILE"

  # 释放锁
  release_lock "$LOCK_FILE"
fi

# ===== 会话事件日志（仅重要工具） =====
is_important_tool() {
  case "$1" in
    Write|Edit|Bash|Task|Skill|SlashCommand) return 0 ;;
  esac
  return 1
}

trim_text() {
  local text="$1"
  local max_len="${2:-120}"
  if [ "${#text}" -gt "$max_len" ]; then
    echo "${text:0:$max_len}"
  else
    echo "$text"
  fi
}

append_session_event() {
  local tool="$1"
  local timestamp="$2"
  local data_json="$3"

  [ ! -f "$SESSION_FILE" ] && return 0

  # 获取锁
  if ! acquire_lock "$EVENT_LOCK_FILE"; then
    return 0
  fi

  # 初始化事件日志
  touch "$EVENT_LOG_FILE" 2>/dev/null || true

  if command -v jq >/dev/null 2>&1; then
    local seq
    local event_id
    local current_state
    seq=$(jq -r '.event_seq // 0' "$SESSION_FILE" 2>/dev/null)
    seq=$((seq + 1))
    event_id=$(printf "event-%06d" "$seq")
    current_state=$(jq -r '.state // "executing"' "$SESSION_FILE" 2>/dev/null)

    # 更新 session.json
    tmp_file=$(mktemp)
    jq --arg updated_at "$timestamp" \
       --arg event_id "$event_id" \
       --argjson event_seq "$seq" \
       '.updated_at = $updated_at | .last_event_id = $event_id | .event_seq = $event_seq' \
       "$SESSION_FILE" > "$tmp_file" && mv "$tmp_file" "$SESSION_FILE"

    # 追加事件日志（SESSION_ORCHESTRATION.md 统一模式）
    if [ -n "$data_json" ]; then
      echo "{\"id\":\"$event_id\",\"type\":\"tool.$tool\",\"ts\":\"$timestamp\",\"state\":\"$current_state\",\"data\":$data_json}" >> "$EVENT_LOG_FILE"
    else
      echo "{\"id\":\"$event_id\",\"type\":\"tool.$tool\",\"ts\":\"$timestamp\",\"state\":\"$current_state\"}" >> "$EVENT_LOG_FILE"
    fi
  fi

  release_lock "$EVENT_LOCK_FILE"
}

if is_important_tool "$TOOL_NAME"; then
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
  DATA_JSON=""

  if [ -n "$FILE_PATH" ]; then
    FILE_PATH_SAFE=$(trim_text "$FILE_PATH" 200)
    DATA_JSON="{\"file_path\":\"$FILE_PATH_SAFE\"}"
  elif [ -n "$COMMAND" ]; then
    COMMAND_SAFE=$(trim_text "$COMMAND" 200)
    DATA_JSON="{\"command\":\"$COMMAND_SAFE\"}"
  fi

  append_session_event "$(echo "$TOOL_NAME" | tr '[:upper:]' '[:lower:]')" "$TIMESTAMP" "$DATA_JSON"
fi


# ===== Skill 追踪（按会话记录技能使用） =====
SESSION_SKILLS_USED_FILE="${STATE_DIR}/session-skills-used.json"

if [ "$TOOL_NAME" = "Skill" ]; then
  mkdir -p "$STATE_DIR"

  # 如果文件不存在则初始化
  if [ ! -f "$SESSION_SKILLS_USED_FILE" ]; then
    echo '{"used": [], "session_start": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$SESSION_SKILLS_USED_FILE"
  fi

  if command -v jq >/dev/null 2>&1; then
    # 从 tool_input 获取技能名
    SKILL_NAME=""
    if [ -n "$INPUT" ]; then
      SKILL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // "unknown"' 2>/dev/null)
    fi

    # 添加到 used 数组
    temp_file=$(mktemp)
    jq --arg skill "$SKILL_NAME" \
       --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.used += [$skill] | .last_used = $ts' \
       "$SESSION_SKILLS_USED_FILE" > "$temp_file" && mv "$temp_file" "$SESSION_SKILLS_USED_FILE"
  fi
fi

exit 0
