#!/bin/bash
# pretooluse-guard.sh
# Claude Code Hooks: PreToolUse guardrail for dangerous operations.
# - Deny writes/edits to protected paths (e.g., .git/, .env, keys)
# - Ask for confirmation for writes outside the project directory
# - Deny sudo, ask for confirmation for rm -rf / git push
#
# Input: stdin JSON from Claude Code hooks
# Output: JSON to control PreToolUse permission decisions
#
# Cross-platform: Supports Windows (Git Bash/MSYS2/Cygwin/WSL), macOS, Linux

set +e

# Load cross-platform path utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/path-utils.sh" ]; then
  # shellcheck source=./path-utils.sh
  source "$SCRIPT_DIR/path-utils.sh"
else
  # Fallback: define minimal path utilities if path-utils.sh not found
  is_absolute_path() {
    local p="$1"
    [[ "$p" == /* ]] && return 0
    [[ "$p" =~ ^[A-Za-z]:[\\/] ]] && return 0
    return 1
  }
  normalize_path() {
    local p="$1"
    p="${p//\\//}"
    echo "$p"
  }
  # Note: This expects already-normalized paths from caller for performance
  is_path_under() {
    local child="$1"
    local parent="$2"
    [[ "$parent" != */ ]] && parent="${parent}/"
    [[ "${child}/" == "${parent}"* ]] || [ "$child" = "${parent%/}" ]
  }
fi

detect_lang() {
  # Default to Japanese for this harness (can be overridden).
  # - CLAUDE_CODE_HARNESS_LANG=en for English
  # - CLAUDE_CODE_HARNESS_LANG=ja for Japanese
  # - CLAUDE_CODE_HARNESS_LANG=zh for Chinese
  if [ -n "${CLAUDE_CODE_HARNESS_LANG:-}" ]; then
    echo "${CLAUDE_CODE_HARNESS_LANG}"
    return 0
  fi
  echo "ja"
}

LANG_CODE="$(detect_lang)"

# ===== Work Mode Detection =====
# Skip specific confirmation prompts during /work (auto-iteration) execution
# Security: Bypass is limited by expiration (24 hours)
# Note: CWD is obtained later from JSON, so only initialization here
# Backward compatibility: ultrawork-active.json is also detected as work-active.json

WORK_MODE="false"
WORK_BYPASS_RM_RF="false"
WORK_BYPASS_GIT_PUSH="false"
WORK_MAX_AGE_HOURS=24

# ===== Codex Mode Detection =====
# In --codex mode, Claude acts as PM, and Edit/Write is prohibited
# (Implementation is delegated to Codex Worker)
# Detected by codex_mode: true in work-active.json
CODEX_MODE="false"

# ===== Breezing Role Guard =====
# Role-based access control for Agent Teams Teammates
# Identify sessions via session_id / agent_id, and restrict Write/Edit based on role
BREEZING_ROLE=""
BREEZING_OWNS=""
SESSION_ID=""
AGENT_ID=""
AGENT_TYPE=""
BREEZING_ROLE_KEY=""

# ===== Breezing-Codex Mode Detection =====
# In breezing-codex mode (impl_mode: "codex"), direct Write/Edit is blocked
# (Implementation is delegated to Codex Implementer via codex exec (CLI))
BREEZING_CODEX_MODE="false"

# Work mode detection function (called after CWD is obtained)
# Prioritize work-active.json, with fallback to ultrawork-active.json for backward compatibility
check_work_mode() {
  local cwd_path="$1"
  local active_file="${cwd_path}/.claude/state/work-active.json"

  # Backward compatibility: try ultrawork-active.json if work-active.json does not exist
  if [ ! -f "$active_file" ]; then
    active_file="${cwd_path}/.claude/state/ultrawork-active.json"
  fi

  [ ! -f "$active_file" ] && return

  if ! command -v jq >/dev/null 2>&1; then
    echo "[work] Warning: jq not installed, guard bypass disabled" >&2
    return
  fi

  local is_active
  is_active=$(jq -r '.active // false' "$active_file" 2>/dev/null || echo "false")
  [ "$is_active" != "true" ] && return

  # Expiration check (must be within 24 hours from started_at)
  local started_at
  started_at=$(jq -r '.started_at // empty' "$active_file" 2>/dev/null)
  [ -z "$started_at" ] && return

  # ISO8601 parsing (compatible with both macOS/Linux)
  # Remove Z suffix for parsing
  local started_clean="${started_at%%Z*}"
  started_clean="${started_clean%%+*}"  # Remove timezone offset
  started_clean="${started_clean%%.*}"  # Remove milliseconds

  local started_epoch=0
  local current_epoch
  current_epoch=$(date +%s)

  # macOS: date -j -f, Linux: date -d
  if [[ "$OSTYPE" == "darwin"* ]]; then
    started_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$started_clean" +%s 2>/dev/null || echo 0)
  else
    started_epoch=$(date -d "${started_at}" +%s 2>/dev/null || echo 0)
  fi

  if [ "$started_epoch" -eq 0 ]; then
    echo "[work] Warning: failed to parse started_at, guard bypass disabled" >&2
    return
  fi

  # Future timestamp check (tamper prevention)
  if [ "$started_epoch" -gt "$current_epoch" ]; then
    echo "[work] Warning: started_at is in the future, guard bypass disabled" >&2
    return
  fi

  local age_hours=$(( (current_epoch - started_epoch) / 3600 ))
  if [ "$age_hours" -ge "$WORK_MAX_AGE_HOURS" ]; then
    rm -f "$active_file" 2>/dev/null || true
    echo "[work] Warning: work-active.json expired (${age_hours}h >= ${WORK_MAX_AGE_HOURS}h), removed" >&2
    return
  fi

  WORK_MODE="true"
  # Performance: extract bypass_guards and codex_mode in one jq call to avoid re-reading
  local _work_extras
  _work_extras=$(jq -r '[
    (if .bypass_guards | type == "array" then (.bypass_guards | contains(["rm_rf"])) else false end),
    (if .bypass_guards | type == "array" then (.bypass_guards | contains(["git_push"])) else false end),
    (.codex_mode // false)
  ] | @tsv' "$active_file" 2>/dev/null)
  if [ -n "$_work_extras" ]; then
    IFS=$'\t' read -r WORK_BYPASS_RM_RF WORK_BYPASS_GIT_PUSH _work_codex_mode <<< "$_work_extras"
    # Cache codex_mode for check_codex_mode to avoid re-parsing
    WORK_CACHED_CODEX_MODE="${_work_codex_mode}"
  else
    WORK_BYPASS_RM_RF="false"
    WORK_BYPASS_GIT_PUSH="false"
  fi
}

# Codex mode detection function (called after CWD is obtained)
# If codex_mode: true exists in work-active.json, block Claude's Edit/Write
# Prerequisite: CODEX_MODE is set only when WORK_MODE is true and TTL is valid
# Performance: Prefer cached value from check_work_mode
check_codex_mode() {
  # Skip if Work mode is not enabled (considering TTL expiration etc.)
  [ "$WORK_MODE" != "true" ] && return

  # Use cached value from check_work_mode if available (avoids re-reading file)
  if [ -n "${WORK_CACHED_CODEX_MODE:-}" ]; then
    [ "$WORK_CACHED_CODEX_MODE" = "true" ] && CODEX_MODE="true"
    return
  fi

  # Fallback: read file directly (for python3-only environments where jq cache wasn't set)
  local cwd_path="$1"
  local active_file="${cwd_path}/.claude/state/work-active.json"

  # Backward compatibility: try ultrawork-active.json if work-active.json does not exist
  if [ ! -f "$active_file" ]; then
    active_file="${cwd_path}/.claude/state/ultrawork-active.json"
  fi

  [ ! -f "$active_file" ] && return

  local is_codex="false"

  if command -v python3 >/dev/null 2>&1; then
    is_codex=$(python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    val = data.get("codex_mode", False)
    print("true" if val is True else "false")
except:
    print("false")
' "$active_file" 2>/dev/null || echo "false")
  fi

  [ "$is_codex" = "true" ] && CODEX_MODE="true"
}

# Breezing role detection function (called after CWD + SESSION_ID/AGENT_ID are obtained)
# Search for role from .claude/state/breezing-session-roles.json
check_breezing_role() {
  local cwd_path="$1"
  local roles_file="${cwd_path}/.claude/state/breezing-session-roles.json"

  [ -z "$SESSION_ID" ] && [ -z "$AGENT_ID" ] && return
  [ ! -f "$roles_file" ] && return

  if ! command -v jq >/dev/null 2>&1; then
    return
  fi

  local lookup_key=""
  local role=""
  local owns=""

  for lookup_key in "$AGENT_ID" "$SESSION_ID"; do
    [ -z "$lookup_key" ] && continue
    role="$(jq -r --arg sid "$lookup_key" '.[$sid].role // empty' "$roles_file" 2>/dev/null)"
    [ -z "$role" ] && continue
    owns="$(jq -r --arg sid "$lookup_key" '.[$sid].owns // empty' "$roles_file" 2>/dev/null)"
    BREEZING_ROLE="$role"
    BREEZING_OWNS="$owns"
    BREEZING_ROLE_KEY="$lookup_key"
    return
  done
}

# Breezing-Codex mode detection function (called after CWD is obtained)
# If impl_mode: "codex" exists in breezing-active.json, block direct Write/Edit
check_breezing_codex_mode() {
  local cwd_path="$1"
  local active_file="${cwd_path}/.claude/state/breezing-active.json"

  [ ! -f "$active_file" ] && return

  local is_codex="false"

  if command -v jq >/dev/null 2>&1; then
    local impl_mode
    impl_mode=$(jq -r '.impl_mode // empty' "$active_file" 2>/dev/null)
    [ "$impl_mode" = "codex" ] && is_codex="true"
  elif command -v python3 >/dev/null 2>&1; then
    is_codex=$(python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    val = data.get("impl_mode", "")
    print("true" if val == "codex" else "false")
except:
    print("false")
' "$active_file" 2>/dev/null || echo "false")
  else
    echo "[Breezing-Codex] Warning: jq/python3 not found, breezing-codex mode detection disabled" >&2
    return
  fi

  [ "$is_codex" = "true" ] && BREEZING_CODEX_MODE="true"
}

# Detection and handling of Breezing role registration Write
# Register session_id / agent_id → role mapping on Teammate's first Write (breezing-role-*.json)
try_register_breezing_role() {
  local file_path="$1"
  local cwd_path="$2"
  local roles_file="${cwd_path}/.claude/state/breezing-session-roles.json"

  # Only target Writes to breezing-role-*.json
  BASENAME_ROLE="${file_path##*/}"
  case "$BASENAME_ROLE" in
    breezing-role-*.json) ;;
    *) return 1 ;;
  esac

  # Confirm path is under .claude/state/
  case "$file_path" in
    .claude/state/breezing-role-*.json|*/.claude/state/breezing-role-*.json) ;;
    *) return 1 ;;
  esac

  [ -z "$SESSION_ID" ] && [ -z "$AGENT_ID" ] && return 1

  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi

  # Extract role information from tool_input.content
  local content role owns
  content=$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null)
  [ -z "$content" ] && return 1

  role=$(echo "$content" | jq -r '.role // empty' 2>/dev/null)
  [ -z "$role" ] && return 1

  # Security: Only allow known role values
  case "$role" in
    reviewer|implementer|lead) ;;
    *) return 1 ;;
  esac

  owns=$(echo "$content" | jq -c '.owns // []' 2>/dev/null || echo '[]')

  # Register session_id → role mapping
  mkdir -p "${cwd_path}/.claude/state" 2>/dev/null || true

  if [ ! -f "$roles_file" ]; then
    echo '{}' > "$roles_file"
  fi

  jq \
    --arg sid "$SESSION_ID" \
    --arg aid "$AGENT_ID" \
    --arg atype "$AGENT_TYPE" \
    --arg role "$role" \
    --argjson owns "$owns" \
    '
      (if $sid != "" then .[$sid] = {"role": $role, "owns": $owns, "agent_type": $atype} else . end)
      | (if $aid != "" then .[$aid] = {"role": $role, "owns": $owns, "agent_type": $atype} else . end)
    ' \
    "$roles_file" > "${roles_file}.tmp" && mv "${roles_file}.tmp" "$roles_file"

  return 0
}

msg() {
  # msg <key> [arg]
  local key="$1"
  local arg="${2:-}"

  if [ "$LANG_CODE" = "en" ]; then
    case "$key" in
      deny_path_traversal) echo "Blocked: path traversal in file_path ($arg)" ;;
      ask_write_outside_project) echo "Confirm: writing outside project directory ($arg)" ;;
      deny_protected_path) echo "Blocked: protected path ($arg)" ;;
      deny_sudo) echo "Blocked: sudo is not allowed via Claude Code hooks" ;;
      ask_git_push) echo "Confirm: git push requested ($arg)" ;;
      ask_rm_rf) echo "Confirm: rm -rf requested ($arg)" ;;
      deny_git_commit_no_review) echo "Blocked: Run /harness-review before committing. After review approval, run git commit again." ;;
      deny_codex_mode) echo "[Codex Mode] Claude is the PM. Direct Edit/Write is prohibited. Delegate implementation to Codex Worker via codex exec (CLI)." ;;
      deny_breezing_codex_mode) echo "[Breezing-Codex] Direct Edit/Write is prohibited in codex impl mode. Implementation must go through codex exec (CLI)." ;;
      deny_codex_mcp) echo "Blocked: Codex MCP is deprecated. Use 'codex exec' (Bash) instead. See .claude/rules/codex-cli-only.md" ;;
      *) echo "$key $arg" ;;
    esac
    return 0
  fi

  # ja (default)
  case "$key" in
    deny_path_traversal) echo "阻止: 可疑的路径遍历 (file_path: $arg)" ;;
    ask_write_outside_project) echo "确认: 写入项目目录外的文件 (file_path: $arg)" ;;
    deny_protected_path) echo "阻止: 操作受保护路径 (path: $arg)" ;;
    deny_sudo) echo "阻止: 不允许通过 hook 执行 sudo" ;;
    ask_git_push) echo "确认: 正在尝试执行 git push (command: $arg)" ;;
    ask_rm_rf) echo "确认: 正在尝试执行 rm -rf (command: $arg)" ;;
    deny_git_commit_no_review) echo "阻止: 提交前请先运行 /harness-review。审查通过后可再次执行 git commit。" ;;
    deny_codex_mode) echo "[Codex Mode] --codex 模式下 Claude 担任 PM 角色。禁止直接执行 Edit/Write。请通过 codex exec (CLI) 将实现委托给 Codex Worker。" ;;
    deny_breezing_codex_mode) echo "[Breezing-Codex] codex 实现模式下禁止直接执行 Edit/Write。请通过 codex exec (CLI) 进行实现。" ;;
    deny_codex_mcp) echo "阻止: Codex MCP 已废弃。请使用 'codex exec' (Bash) 代替。详情: .claude/rules/codex-cli-only.md" ;;
    *) echo "$key $arg" ;;
  esac
}

INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

[ -z "$INPUT" ] && exit 0

TOOL_NAME=""
FILE_PATH=""
COMMAND=""
CWD=""

if command -v jq >/dev/null 2>&1; then
  # Performance: extract all fields in one jq call instead of 5 separate invocations
  _jq_parsed="$(echo "$INPUT" | jq -r '[
    (.tool_name // ""),
    (.tool_input.file_path // ""),
    (.tool_input.command // ""),
    (.cwd // ""),
    (.session_id // ""),
    (.agent_id // ""),
    (.agent_type // "")
  ] | @tsv' 2>/dev/null)"
  if [ -n "$_jq_parsed" ]; then
    IFS=$'\t' read -r TOOL_NAME FILE_PATH COMMAND CWD SESSION_ID AGENT_ID AGENT_TYPE <<< "$_jq_parsed"
  fi
  unset _jq_parsed
elif command -v python3 >/dev/null 2>&1; then
  # Performance+Security: extract all fields in one python3 call (no eval)
  _py_parsed="$(echo "$INPUT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
def get_nested(d, path):
    for k in path.split('.'):
        if isinstance(d, dict):
            d = d.get(k) or ''
        else:
            return ''
    return d if isinstance(d, str) else ''
fields = ['tool_name', 'tool_input.file_path', 'tool_input.command', 'cwd', 'session_id', 'agent_id', 'agent_type']
print('\t'.join(get_nested(data, f) for f in fields))
" 2>/dev/null)"
  if [ -n "$_py_parsed" ]; then
    IFS=$'\t' read -r TOOL_NAME FILE_PATH COMMAND CWD SESSION_ID AGENT_ID AGENT_TYPE <<< "$_py_parsed"
  fi
  unset _py_parsed
fi

[ -z "$TOOL_NAME" ] && exit 0

# ===== Work mode detection execution (after CWD is obtained) =====
if [ -n "$CWD" ]; then
  check_work_mode "$CWD"
  check_codex_mode "$CWD"
  check_breezing_role "$CWD"
  check_breezing_codex_mode "$CWD"
fi

# ===== Cost Control: Track tool call count per session =====
CONFIG_FILE=".claude-code-harness.config.yaml"
STATE_DIR=".claude/state"
COST_STATE_FILE="$STATE_DIR/cost-state.json"

check_cost_control() {
  local tool="$1"

  # cost_control.enabled check
  if [ ! -f "$CONFIG_FILE" ]; then
    return 0
  fi

  local cost_enabled
  cost_enabled=$(grep -E "^  enabled:" "$CONFIG_FILE" 2>/dev/null | head -n 1 | awk '{print $2}' || echo "false")
  if [ "$cost_enabled" != "true" ]; then
    return 0
  fi

  # Initialize cost-state.json if it doesn't exist
  # Security: refuse if state dir or file is a symlink (prevents symlink-based overwrites)
  if [ -L "$STATE_DIR" ] || [ -L "$COST_STATE_FILE" ]; then
    return 0
  fi
  if [ ! -f "$COST_STATE_FILE" ]; then
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    echo '{"total_tool_calls":0,"edit_calls":0,"bash_calls":0}' > "$COST_STATE_FILE"
  fi

  if command -v jq >/dev/null 2>&1; then
    # Get current counts
    local total_calls edit_calls bash_calls
    total_calls=$(jq -r '.total_tool_calls // 0' "$COST_STATE_FILE" 2>/dev/null || echo 0)
    edit_calls=$(jq -r '.edit_calls // 0' "$COST_STATE_FILE" 2>/dev/null || echo 0)
    bash_calls=$(jq -r '.bash_calls // 0' "$COST_STATE_FILE" 2>/dev/null || echo 0)

    # Get limits from config
    local total_limit edit_limit bash_limit warn_percent
    total_limit=$(grep -A5 "session_limits:" "$CONFIG_FILE" 2>/dev/null | grep "total_tool_calls:" | awk '{print $2}' || echo 500)
    edit_limit=$(grep -A5 "session_limits:" "$CONFIG_FILE" 2>/dev/null | grep "edit_calls:" | awk '{print $2}' || echo 100)
    bash_limit=$(grep -A5 "session_limits:" "$CONFIG_FILE" 2>/dev/null | grep "bash_calls:" | awk '{print $2}' || echo 200)
    warn_percent=$(grep "warn_threshold_percent:" "$CONFIG_FILE" 2>/dev/null | awk '{print $2}' || echo 80)

    # Increment counts
    total_calls=$((total_calls + 1))
    case "$tool" in
      Write|Edit) edit_calls=$((edit_calls + 1)) ;;
      Bash) bash_calls=$((bash_calls + 1)) ;;
    esac

    # Update cost-state.json
    jq --argjson t "$total_calls" --argjson e "$edit_calls" --argjson b "$bash_calls" \
      '.total_tool_calls = $t | .edit_calls = $e | .bash_calls = $b' \
      "$COST_STATE_FILE" > "${COST_STATE_FILE}.tmp" && mv "${COST_STATE_FILE}.tmp" "$COST_STATE_FILE"

    # Check limits
    if [ "$total_calls" -ge "$total_limit" ]; then
      echo "[Cost Control] Session tool call limit ($total_limit) reached. Please start a new session."
      return 1
    fi

    case "$tool" in
      Write|Edit)
        if [ "$edit_calls" -ge "$edit_limit" ]; then
          echo "[Cost Control] Edit/Write call limit ($edit_limit) reached."
          return 1
        fi
        ;;
      Bash)
        if [ "$bash_calls" -ge "$bash_limit" ]; then
          echo "[Cost Control] Bash call limit ($bash_limit) reached."
          return 1
        fi
        ;;
    esac

    # Warning threshold check (warning via additionalContext)
    local warn_total=$((total_limit * warn_percent / 100))
    local warn_edit=$((edit_limit * warn_percent / 100))
    local warn_bash=$((bash_limit * warn_percent / 100))

    local warnings=""
    if [ "$total_calls" -ge "$warn_total" ] && [ "$total_calls" -lt "$total_limit" ]; then
      warnings="${warnings}[Cost Warning] Total tool calls: ${total_calls}/${total_limit} (${warn_percent}% exceeded)\n"
    fi
    case "$tool" in
      Write|Edit)
        if [ "$edit_calls" -ge "$warn_edit" ] && [ "$edit_calls" -lt "$edit_limit" ]; then
          warnings="${warnings}[Cost Warning] Edit/Write: ${edit_calls}/${edit_limit}\n"
        fi
        ;;
      Bash)
        if [ "$bash_calls" -ge "$warn_bash" ] && [ "$bash_calls" -lt "$bash_limit" ]; then
          warnings="${warnings}[Cost Warning] Bash: ${bash_calls}/${bash_limit}\n"
        fi
        ;;
    esac

    if [ -n "$warnings" ]; then
      echo -e "$warnings"
      return 2  # Warning (not blocked)
    fi
  fi

  return 0
}

# Cost control check is executed after emit_deny is defined (executed later)

emit_decision() {
  local decision="$1"
  local reason="$2"
  local additional_context="${3:-}"

  if command -v jq >/dev/null 2>&1; then
    if [ -n "$additional_context" ]; then
      jq -nc --arg decision "$decision" --arg reason "$reason" --arg ctx "$additional_context" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:$decision, permissionDecisionReason:$reason, additionalContext:$ctx}}'
    else
      jq -nc --arg decision "$decision" --arg reason "$reason" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:$decision, permissionDecisionReason:$reason}}'
    fi
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    DECISION="$decision" REASON="$reason" ADDITIONAL_CONTEXT="$additional_context" python3 - <<'PY'
import json, os
output = {
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": os.environ.get("DECISION", ""),
    "permissionDecisionReason": os.environ.get("REASON", ""),
  }
}
ctx = os.environ.get("ADDITIONAL_CONTEXT", "")
if ctx:
    output["hookSpecificOutput"]["additionalContext"] = ctx
print(json.dumps(output))
PY
    return 0
  fi

  # Fallback: omit reason and additionalContext to avoid JSON escaping issues.
  printf '%s' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"${decision}\"}}"
}

emit_deny() {
  # Record hook blocking event (non-blocking, fire-and-forget)
  local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -x "$SCRIPT_DIR/record-usage.js" ] && command -v node >/dev/null 2>&1; then
    node "$SCRIPT_DIR/record-usage.js" hook pretooluse-guard --blocked >/dev/null 2>&1 &
  fi
  emit_decision "deny" "$1"
}
emit_ask() { emit_decision "ask" "$1"; }

# ===== Codex MCP Block (deprecated) =====
# MCP server has been removed. Fail-safe for text edits that slip through.
if [[ "$TOOL_NAME" == mcp__codex__* ]]; then
  emit_deny "$(msg deny_codex_mcp)"
  exit 0
fi

# ===== Cost control check execution =====
COST_CHECK_MSG=""
COST_CHECK_MSG=$(check_cost_control "$TOOL_NAME")
COST_CHECK_RESULT=$?

if [ "$COST_CHECK_RESULT" -eq 1 ]; then
  # Limit reached -> deny
  emit_deny "$COST_CHECK_MSG"
  exit 0
fi
# For warnings (result=2), include in additionalContext in subsequent processing

# ===== additionalContext guideline generation (Claude Code v2.1.9+) =====
# Return guidelines based on file path for Write/Edit operations

TEST_QUALITY_GUIDELINE="[Test Quality Guidelines]
- Do not change to it.skip() / test.skip()
- Do not remove or relax assertions
- Do not add eslint-disable comments"

IMPL_QUALITY_GUIDELINE="[Implementation Quality Guidelines]
- Do not hardcode test expected values
- No stubs, mocks, or empty implementations
- Must implement meaningful logic"

# Return guidelines based on file path
# Arguments: $1 = file path (relative or absolute)
# Returns: guideline string (empty if not applicable)
get_guideline_for_path() {
  local path="$1"

  # Test file patterns
  case "$path" in
    tests/*|test/*|__tests__/*|*.spec.ts|*.spec.tsx|*.spec.js|*.spec.jsx|*.test.ts|*.test.tsx|*.test.js|*.test.jsx)
      echo "$TEST_QUALITY_GUIDELINE"
      return 0
      ;;
  esac

  # Implementation file patterns
  case "$path" in
    src/*.ts|src/*.tsx|src/*.js|src/*.jsx|lib/*.ts|lib/*.tsx|lib/*.js|lib/*.jsx)
      echo "$IMPL_QUALITY_GUIDELINE"
      return 0
      ;;
  esac

  # Not applicable
  echo ""
}

# Explicitly return "allow" with additionalContext
# Omitting permissionDecision causes ambiguous behavior and prompts even in bypass mode
# Explicitly allow with permissionDecision: "allow" to skip prompts
emit_approve_with_context() {
  local context="$1"
  if [ -n "$context" ]; then
    if command -v jq >/dev/null 2>&1; then
      jq -nc --arg ctx "$context" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"allow", additionalContext:$ctx}}'
    elif command -v python3 >/dev/null 2>&1; then
      ADDITIONAL_CONTEXT="$context" python3 -c '
import json, os
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":os.environ["ADDITIONAL_CONTEXT"]}}))
'
    fi
  fi
  # If context is empty, output nothing (default behavior)
}

is_path_traversal() {
  local p="$1"
  [[ "$p" == ".." ]] && return 0
  [[ "$p" == "../"* ]] && return 0
  [[ "$p" == *"/../"* ]] && return 0
  [[ "$p" == *"/.." ]] && return 0
  return 1
}

# Resolve symlinks and return the canonical (real) path.
# Falls back to the input path if realpath is unavailable or the path doesn't exist yet.
resolve_real_path() {
  local p="$1"
  local base_dir="${2:-}"

  # If relative path and base_dir given, prepend it
  if [ -n "$base_dir" ] && ! is_absolute_path "$p"; then
    p="${base_dir}/${p}"
  fi

  # Try realpath (GNU/macOS) first, then readlink -f (Linux), then Python fallback
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p" 2>/dev/null && return 0
  fi
  if command -v readlink >/dev/null 2>&1; then
    readlink -f "$p" 2>/dev/null && return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$p" 2>/dev/null && return 0
  fi

  # Fallback: return normalized input
  echo "$p"
}

is_protected_path() {
  local p="$1"
  case "$p" in
    .git/*|*/.git/*) return 0 ;;
    .env|.env.*|*/.env|*/.env.*) return 0 ;;
    secrets/*|*/secrets/*) return 0 ;;
    *.pem|*.key|*id_rsa*|*id_ed25519*|*/.ssh/*) return 0 ;;
  esac
  return 1
}


if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  [ -z "$FILE_PATH" ] && exit 0

  if is_path_traversal "$FILE_PATH"; then
    emit_deny "$(msg deny_path_traversal "$FILE_PATH")"
    exit 0
  fi

  # ===== Symlink bypass protection =====
  # Resolve the real path to prevent symlink-based bypasses of protected path checks.
  # Example: attacker creates symlink "safe.txt -> ../../.env" to bypass is_protected_path.
  RESOLVED_FILE_PATH="$(resolve_real_path "$FILE_PATH" "$CWD")"

  # If the resolved path differs from the original, re-check for path traversal
  if [ "$RESOLVED_FILE_PATH" != "$FILE_PATH" ]; then
    # Check if symlink target points to a protected path
    RESOLVED_REL_PATH="$RESOLVED_FILE_PATH"
    if [ -n "$CWD" ]; then
      RESOLVED_NORM_CWD="$(normalize_path "$CWD")"
      RESOLVED_CWD_SLASH="${RESOLVED_NORM_CWD%/}/"
      if [[ "$RESOLVED_FILE_PATH" == "$RESOLVED_CWD_SLASH"* ]]; then
        RESOLVED_REL_PATH="${RESOLVED_FILE_PATH#$RESOLVED_CWD_SLASH}"
      fi
    fi
    if is_protected_path "$RESOLVED_REL_PATH"; then
      emit_deny "$(msg deny_protected_path "$FILE_PATH -> $RESOLVED_REL_PATH")"
      exit 0
    fi
    # Check if symlink escapes project directory
    if [ -n "$CWD" ] && is_absolute_path "$RESOLVED_FILE_PATH"; then
      if ! is_path_under "$RESOLVED_FILE_PATH" "$CWD"; then
        emit_deny "$(msg deny_path_traversal "$FILE_PATH -> $RESOLVED_FILE_PATH")"
        exit 0
      fi
    fi
  fi

  # ===== Codex Mode: PM is prohibited from Edit/Write (Plans.md is allowed) =====
  if [ "$CODEX_MODE" = "true" ]; then
    # Allow Plans.md state marker updates (legitimate PM operation)
    # Strict pattern: only allow exact "Plans.md" ending
    # Reject symbolic links (security measure)
    if [ -L "$FILE_PATH" ]; then
      emit_deny "[Codex Mode] Symbolic links are not allowed for Plans.md"
      exit 0
    fi
    # Do not use local as this is outside a function
    BASENAME_FILE="${FILE_PATH##*/}"
    if [ "$BASENAME_FILE" = "Plans.md" ]; then
      : # Allow (exact Plans.md only)
    else
      emit_deny "$(msg deny_codex_mode)"
      exit 0
    fi
  fi

  # ===== Breezing-Codex Mode: Block direct Edit/Write =====
  if [ "$BREEZING_CODEX_MODE" = "true" ]; then
    if [ -L "$FILE_PATH" ]; then
      emit_deny "[Breezing-Codex] Symbolic links are not allowed"
      exit 0
    fi
    # Allowlist: breezing related state, review state, *.md (documents)
    # Security: Do not allow control files like ultrawork-active.json
    case "$FILE_PATH" in
      .claude/state/breezing*|*/.claude/state/breezing*) ;; # breezing state is allowed
      .claude/state/review*|*/.claude/state/review*) ;; # review state is allowed
      *.md) ;; # document files are allowed
      *)
        emit_deny "$(msg deny_breezing_codex_mode)"
        exit 0
        ;;
    esac
  fi

  # ===== Breezing Role Guard: Teammate 的基于角色的访问控制 =====
  if { [ -n "$SESSION_ID" ] || [ -n "$AGENT_ID" ]; } && [ -n "$CWD" ]; then
    # 检测角色注册 Write（对 breezing-role-*.json 的 Write 是注册处理）
    if try_register_breezing_role "$FILE_PATH" "$CWD" 2>/dev/null; then
      exit 0  # 注册 Write 允许
    fi

    # Reviewer: 阻止 Write/Edit（.claude/state/ 允许）
    if [ "$BREEZING_ROLE" = "reviewer" ]; then
      case "$FILE_PATH" in
        .claude/state/*|*/.claude/state/*) ;; # state 文件允许
        *)
          emit_deny "[Breezing] Reviewer 是 Read-only 的。代码修正是 Implementer 的职责。"
          exit 0
          ;;
      esac
    fi

    # Implementer: 阻止对 owns 外文件的 Write/Edit
    if [ "$BREEZING_ROLE" = "implementer" ] && [ -n "$BREEZING_OWNS" ] && [ "$BREEZING_OWNS" != "null" ]; then
      # .claude/state/ 始终允许
      case "$FILE_PATH" in
        .claude/state/*|*/.claude/state/*) ;; # state 文件允许
        *.md) ;; # 文档文件允许
        *)
          # owns 路径匹配
          BREEZING_FILE_ALLOWED="false"

          # 从 CWD 计算相对路径（REL_PATH 此时未定义）
          BREEZING_REL_PATH="$FILE_PATH"
          if [ -n "$CWD" ]; then
            BREEZING_REL_PATH="${FILE_PATH#${CWD}/}"
          fi

          # 用 jq 获取 owns 数组并匹配
          if [ -f "${CWD}/.claude/state/breezing-session-roles.json" ]; then
            ROLE_KEY="${BREEZING_ROLE_KEY:-$SESSION_ID}"
            while IFS= read -r OWNED_PATTERN; do
              [ -z "$OWNED_PATTERN" ] && continue
              # 绝对路径匹配
              case "$FILE_PATH" in
                $OWNED_PATTERN*) BREEZING_FILE_ALLOWED="true"; break ;;
              esac
              # 相对路径匹配
              case "$BREEZING_REL_PATH" in
                $OWNED_PATTERN*) BREEZING_FILE_ALLOWED="true"; break ;;
              esac
            done < <(jq -r --arg sid "$ROLE_KEY" '.[$sid].owns[]? // empty' \
              "${CWD}/.claude/state/breezing-session-roles.json" 2>/dev/null)
          fi

          if [ "$BREEZING_FILE_ALLOWED" = "false" ]; then
            emit_deny "[Breezing] 此文件在 owns 范围外: $FILE_PATH"
            exit 0
          fi
          ;;
      esac
    fi
  fi

  # Normalize paths for cross-platform comparison
  NORM_FILE_PATH="$(normalize_path "$FILE_PATH")"
  NORM_CWD="$(normalize_path "$CWD")"

  # If absolute and outside project cwd, ask for confirmation.
  # Supports both Unix (/path) and Windows (C:/path, C:\path) absolute paths
  if [ -n "$NORM_CWD" ] && is_absolute_path "$NORM_FILE_PATH"; then
    if ! is_path_under "$NORM_FILE_PATH" "$NORM_CWD"; then
      emit_ask "$(msg ask_write_outside_project "$FILE_PATH")"
      exit 0
    fi
  fi

  # Normalize to relative when possible for pattern matching.
  REL_PATH="$NORM_FILE_PATH"
  if [ -n "$NORM_CWD" ] && is_path_under "$NORM_FILE_PATH" "$NORM_CWD"; then
    # Remove the CWD prefix to get relative path
    # 在函数外所以不使用 local
    CWD_WITH_SLASH="${NORM_CWD%/}/"
    if [[ "$NORM_FILE_PATH" == "$CWD_WITH_SLASH"* ]]; then
      REL_PATH="${NORM_FILE_PATH#$CWD_WITH_SLASH}"
    fi
  fi

  if is_protected_path "$REL_PATH"; then
    emit_deny "$(msg deny_protected_path "$REL_PATH")"
    exit 0
  fi

  # ===== LSP/Skills 门控 (Phase0+) =====
  STATE_DIR=".claude/state"
  SESSION_FILE="$STATE_DIR/session.json"
  TOOLING_POLICY_FILE="$STATE_DIR/tooling-policy.json"
  SKILLS_POLICY_FILE="$STATE_DIR/skills-policy.json"
  SKILLS_CONFIG_FILE="$STATE_DIR/skills-config.json"
  SESSION_SKILLS_USED_FILE="$STATE_DIR/session-skills-used.json"

  # 默认排除模式（即使没有 policy file 也应用）
  is_default_excluded() {
    local path="$1"
    # .md, .txt, .json 文件始终排除（文档/配置文件）
    case "$path" in
      *.md|*.txt|*.json) return 0 ;;
    esac
    # .claude/ 下始终排除
    case "$path" in
      .claude/*) return 0 ;;
    esac
    # docs/, templates/, benchmarks/ 始终排除
    case "$path" in
      docs/*|templates/*|benchmarks/*) return 0 ;;
    esac
    return 1
  }

  # 排除路径检查函数
  is_excluded_path() {
    local path="$1"
    local policy_file="$2"

    # 首先检查默认排除
    is_default_excluded "$path" && return 0

    # 如果没有 policy file 则仅用默认判断结束
    [ ! -f "$policy_file" ] && return 1

    if command -v jq >/dev/null 2>&1; then
      # 检查 skills_gate.exclude_paths
      local exclude_paths
      exclude_paths=$(jq -r '.skills_gate.exclude_paths[]? // empty' "$policy_file" 2>/dev/null)

      while IFS= read -r pattern; do
        [ -z "$pattern" ] && continue
        case "$path" in
          $pattern*) return 0 ;;
        esac
        case "$pattern" in
          \*.*)
            local ext="${pattern#\*}"
            [[ "$path" == *"$ext" ]] && return 0
            ;;
        esac
      done <<< "$exclude_paths"

      # 检查 exclude_extensions
      local exclude_exts
      exclude_exts=$(jq -r '.skills_gate.exclude_extensions[]? // empty' "$policy_file" 2>/dev/null)
      local file_ext=".${path##*.}"

      while IFS= read -r ext; do
        [ -z "$ext" ] && continue
        [ "$file_ext" = "$ext" ] && return 0
      done <<< "$exclude_exts"
    fi

    return 1
  }

  # ===== Skills Gate: 按会话检查技能使用 =====
  # 仅当 skills-config.json 存在且 enabled=true 时应用门控
  if [ -f "$SKILLS_CONFIG_FILE" ]; then
    if command -v jq >/dev/null 2>&1; then
      SKILLS_GATE_ACTIVE=$(jq -r '.enabled // false' "$SKILLS_CONFIG_FILE" 2>/dev/null || echo "false")
      
      if [ "$SKILLS_GATE_ACTIVE" = "true" ]; then
        # 检查排除路径
        if is_excluded_path "$REL_PATH" "$SKILLS_POLICY_FILE"; then
          : # 排除路径 -> 跳过
        else
          # 检查 session-skills-used.json
          SKILL_USED_THIS_SESSION="false"
          if [ -f "$SESSION_SKILLS_USED_FILE" ]; then
            USED_COUNT=$(jq -r '.used | length' "$SESSION_SKILLS_USED_FILE" 2>/dev/null || echo "0")
            if [ "$USED_COUNT" -gt 0 ]; then
              SKILL_USED_THIS_SESSION="true"
            fi
          fi
          
          if [ "$SKILL_USED_THIS_SESSION" = "false" ]; then
            # 技能未使用 -> 阻止
            AVAILABLE_SKILLS=$(jq -r '.skills // [] | join(", ")' "$SKILLS_CONFIG_FILE" 2>/dev/null || echo "impl, harness-review")
            DENY_MSG="[Skills Gate] 请在代码编辑前使用技能。

本项目已启用 Skills Gate。
代码更改前请使用 Skill 工具调用适当的技能。

可用技能: ${AVAILABLE_SKILLS}

示例: 使用 Skill 工具调用 'impl' 或 'harness-review'

使用技能后，请再次执行 Write/Edit。"
            emit_deny "$DENY_MSG"
            exit 0
          fi
        fi
      fi
    fi
  fi

  # ===== LSP Gate: 语义变更时推荐使用 LSP =====
  if [ -f "$SESSION_FILE" ] && [ -f "$TOOLING_POLICY_FILE" ]; then
    if command -v jq >/dev/null 2>&1; then
      CURRENT_PROMPT_SEQ=$(jq -r '.prompt_seq // 0' "$SESSION_FILE" 2>/dev/null || echo 0)
      INTENT=$(jq -r '.intent // "literal"' "$SESSION_FILE" 2>/dev/null || echo "literal")
      LSP_AVAILABLE=$(jq -r '.lsp.available // false' "$TOOLING_POLICY_FILE" 2>/dev/null || echo false)
      LSP_LAST_USED_SEQ=$(jq -r '.lsp.last_used_prompt_seq // 0' "$TOOLING_POLICY_FILE" 2>/dev/null || echo 0)

      FILE_EXT="${FILE_PATH##*.}"
      LSP_AVAILABLE_FOR_EXT=$(jq -r ".lsp.available_by_ext[\"$FILE_EXT\"] // false" "$TOOLING_POLICY_FILE" 2>/dev/null || echo false)

      if [ "$INTENT" = "semantic" ] && [ "$LSP_AVAILABLE" = "true" ] && [ "$LSP_AVAILABLE_FOR_EXT" = "true" ]; then
        if [ "$LSP_LAST_USED_SEQ" != "$CURRENT_PROMPT_SEQ" ]; then
          DENY_MSG="[LSP Policy] 代码更改前请使用 LSP 工具分析影响范围。

推荐 LSP 工具:
- 用 Go-to-definition 确认符号定义
- 用 Find-references 确认使用位置
- 用 Diagnostics 检测类型错误

使用 LSP 工具掌握变更影响范围后，请再次执行 Write/Edit。"
          emit_deny "$DENY_MSG"
          exit 0
        fi
      fi
    fi
  fi

  # ===== additionalContext 输出 (Claude Code v2.1.9+) =====
  # 通过所有检查后，根据文件路径返回指南
  GUIDELINE="$(get_guideline_for_path "$REL_PATH")"
  if [ -n "$GUIDELINE" ]; then
    emit_approve_with_context "$GUIDELINE"
  fi

  exit 0
fi


if [ "$TOOL_NAME" = "Bash" ]; then
  [ -z "$COMMAND" ] && exit 0

  if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])sudo([[:space:]]|$)'; then
    emit_deny "$(msg deny_sudo)"
    exit 0
  fi

  # ===== Breezing Role Guard: Bash 命令限制 =====
  if [ -n "$BREEZING_ROLE" ]; then
    # Reviewer: 阻止写入类 Bash 命令
    if [ "$BREEZING_ROLE" = "reviewer" ]; then
      # 只读命令（cat, grep, ls, git status/diff/log, echo）允许
      # 写入类（重定向、sed -i、tee、mv、cp、rm、git commit/push）阻止
      # 2># 2>2>2>&1（stderr→stdout）は読み取り安全なので除外1（stderr→stdout）是只读安全的，所以排除1（stderr→stdout）是只读安全的所以排除1（stderr→stdout）是只读安全的所以排除
      BREEZING_SANITIZED_CMD=$(echo "$COMMAND" | sed 's/2>&1//g; s/>&2//g')
      if echo "$BREEZING_SANITIZED_CMD" | grep -Eq '(>|>>|2>|&>|(^|[[:space:]])tee([[:space:]]|$)|sed[[:space:]]+-i)'; then
        emit_deny "[Breezing] Reviewer 不能执行写入类 Bash 命令。"
        exit 0
      fi
      if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])(mv|cp|rm|mkdir|touch)[[:space:]]'; then
        emit_deny "[Breezing] Reviewer 不能执行文件操作命令。"
        exit 0
      fi
      if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])git[[:space:]]+(commit|push|add|checkout|reset|rebase|merge|cherry-pick)([[:space:]]|$)'; then
        emit_deny "[Breezing] Reviewer 不能执行 git 变更命令。"
        exit 0
      fi
    fi

    # Implementer: 阻止 git commit（提交仅限 Lead）
    if [ "$BREEZING_ROLE" = "implementer" ]; then
      if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
        emit_deny "[Breezing] Implementer 不能执行 git commit。提交由 Lead 在完成阶段统一执行。"
        exit 0
      fi
      if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])git[[:space:]]+push([[:space:]]|$)'; then
        emit_deny "[Breezing] Implementer 不能执行 git push。"
        exit 0
      fi
    fi
  fi

  # ===== Breezing-Codex Mode: 限制 Bash 写入类命令 =====
  if [ "$BREEZING_CODEX_MODE" = "true" ]; then
    # 阻止重定向/原地编辑（2># 阻止重定向和就地编辑（排除 2>リダイレクト・インプレース編集をブロック（2>&1 は読み取り安全なので除外）1，因为它是只读安全的）1 是只读安全的所以排除）
    BREEZING_CODEX_SANITIZED_CMD=$(echo "$COMMAND" | sed 's/2>&1//g; s/>&2//g')
    if echo "$BREEZING_CODEX_SANITIZED_CMD" | grep -Eq '(>|>>|2>|&>|(^|[[:space:]])tee([[:space:]]|$)|sed[[:space:]]+-i|awk[[:space:]]+-i[[:space:]]+inplace)'; then
      emit_deny "$(msg deny_breezing_codex_mode)"
      exit 0
    fi
    # 阻止文件操作命令
    if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])(mv|cp|rm|mkdir|touch)[[:space:]]'; then
      emit_deny "[Breezing-Codex] File operation commands are prohibited in codex impl mode."
      exit 0
    fi
    # 阻止 git 变更命令
    if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])git[[:space:]]+(commit|push|add|checkout|reset|rebase|merge|cherry-pick|apply|am|switch|restore|stash|pull|clean|rm|mv|submodule)([[:space:]]|$)'; then
      emit_deny "[Breezing-Codex] Git mutation commands are prohibited in codex impl mode."
      exit 0
    fi
  fi

  # ===== Codex Mode: PM 也限制 Bash 写入类命令 =====
  if [ "$CODEX_MODE" = "true" ]; then
    # 检测写入类模式
    # - 重定向: >, >>, 2>, &>
    # - tee 命令
    # - sed -i（原地编辑）
    # - awk -i inplace
    # 注意: 只读命令（cat, grep, ls, git status 等）允许
    # 注意: rm 在后面的 rm -rf 白名单中处理所以这里排除
    # 2># 2>2>2>&1（stderr→stdout）は読み取り安全なので除外1（stderr→stdout）是只读安全的，所以排除1（stderr→stdout）是只读安全的所以排除1（stderr→stdout）是只读安全的所以排除
    CODEX_SANITIZED_CMD=$(echo "$COMMAND" | sed 's/2>&1//g; s/>&2//g')
    if echo "$CODEX_SANITIZED_CMD" | grep -Eq '(>|>>|2>|&>|(^|[[:space:]])tee([[:space:]]|$)|sed[[:space:]]+-i|awk[[:space:]]+-i[[:space:]]+inplace)'; then
      emit_deny "$(msg deny_codex_mode)"
      exit 0
    fi
    # mv, cp 需要确认（ask）
    # rm 在后面的 rm -rf 白名单中处理（避免顺序问题）
    if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])(mv|cp)[[:space:]]'; then
      emit_ask "[Codex Mode] 确定要在 PM 模式下执行文件操作（mv/cp）吗？建议将实现委托给 Codex Worker。"
      exit 0
    fi
  fi

  # ===== Commit Guard: 阻止审查完成前的提交 =====
  if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
    REVIEW_STATE_FILE=".claude/state/review-approved.json"
    COMMIT_GUARD_ENABLED="true"

    # 检查是否在配置文件中禁用
    CONFIG_FILE=".claude-code-harness.config.yaml"
    if [ -f "$CONFIG_FILE" ] && command -v grep >/dev/null 2>&1; then
      if grep -q "commit_guard:[[:space:]]*false" "$CONFIG_FILE" 2>/dev/null; then
        COMMIT_GUARD_ENABLED="false"
      fi
    fi

    if [ "$COMMIT_GUARD_ENABLED" = "true" ]; then
      # 检查审查批准状态
      REVIEW_APPROVED="false"
      if [ -f "$REVIEW_STATE_FILE" ]; then
        if command -v jq >/dev/null 2>&1; then
          APPROVED_AT=$(jq -r '.approved_at // empty' "$REVIEW_STATE_FILE" 2>/dev/null)
          JUDGMENT=$(jq -r '.judgment // empty' "$REVIEW_STATE_FILE" 2>/dev/null)
          if [ -n "$APPROVED_AT" ] && [ "$JUDGMENT" = "APPROVE" ]; then
            REVIEW_APPROVED="true"
          fi
        fi
      fi

      if [ "$REVIEW_APPROVED" = "false" ]; then
        emit_deny "$(msg deny_git_commit_no_review)"
        exit 0
      fi

      # 提交后清除批准状态（下次提交前要求重新审查）
      # Note: 这应该在 PostToolUse 中进行，但这里只是警告
    fi
  fi

  if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])git[[:space:]]+push([[:space:]]|$)'; then
    # Work 模式下可绕过
    if [ "$WORK_MODE" = "true" ] && [ "$WORK_BYPASS_GIT_PUSH" = "true" ]; then
      : # 跳过（自动批准）
    else
      emit_ask "$(msg ask_git_push "$COMMAND")"
      exit 0
    fi
  fi

  # 检测 rm 的危险递归删除模式
  # 注意: 仅 rm -rf 或 rm -r -f 可绕过。其他标志组合需要确认
  if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])rm[[:space:]]+-[a-z]*r[a-z]*[[:space:]]' || \
     echo "$COMMAND" | grep -Eiq '(^|[[:space:]])rm[[:space:]]+--recursive'; then

    # ===== Work 白名单方式（Codex 已批准） =====
    # 默认: 需要确认
    RM_AUTO_APPROVE="false"

    # 仅在 Work 模式启用且允许 rm_rf 绕过时检查
    if [ "$WORK_MODE" = "true" ] && [ "$WORK_BYPASS_RM_RF" = "true" ]; then

      # 0. 仅允许的标志格式（rm -rf 或 rm -r -f）
      # rm -rfv, rm -fr, rm --recursive 等其他格式需要确认
      if ! echo "$COMMAND" | grep -Eq '(^|[[:space:]])rm[[:space:]]+(-rf|-r[[:space:]]+-f)[[:space:]]+'; then
        : # 需要确认（不允许的标志格式）
      # 1. 包含危险 shell 语法时需要确认（* ? $ ( ) { } ; | & < > \ `）
      elif echo "$COMMAND" | grep -Eq '[\*\?\$\(\)\{\};|&<>\\`]'; then
        : # 需要确认
      # 2. 包含 sudo/xargs/find 时需要确认
      elif echo "$COMMAND" | grep -Eiq '(sudo|xargs|find)[[:space:]]'; then
        : # 需要确认
      else
        # 提取 rm 目标（去除标志部分）
        RM_TARGET=$(echo "$COMMAND" | sed -E 's/^.*rm[[:space:]]+(-rf|-r[[:space:]]+-f)[[:space:]]+//' | sed 's/[[:space:]].*//')

        # 3. 单目标检查（空格分隔的多个目标不被允许）
        RM_TARGET_COUNT=$(echo "$COMMAND" | sed -E 's/^.*rm[[:space:]]+(-rf|-fr|-r[[:space:]]+-f|-f[[:space:]]+-r)[[:space:]]+//' | wc -w | tr -d ' ')
        if [ "$RM_TARGET_COUNT" -eq 1 ]; then

          # 4. 仅相对路径（不以 / 或 ~ 开头）
          # 5. 无父目录引用（不包含 ..）
          # 6. 无末尾斜杠
          # 7. 无路径分隔符（仅允许 basename）
          # 8. 不包含 . 或 //
          case "$RM_TARGET" in
            /*|~*|*..*)
              : # 需要确认
              ;;
            */)
              : # 需要确认（末尾斜杠）
              ;;
            *//*|*/.*)
              : # 需要确认（包含 // 或 /.）
              ;;
            */*)
              : # 需要确认（包含路径分隔符）
              ;;
            .)
              : # 需要确认（当前目录）
              ;;
            *)
              # 9. 保护路径检查
              case "$RM_TARGET" in
                .git*|.env*|*secrets*|*keys*|*.pem|*.key|*id_rsa*|*id_ed25519*|.ssh*|.npmrc*|.aws*|.gitmodules*)
                  : # 需要确认（保护路径）
                  ;;
                *)
                  # 10. 白名单检查
                  if [ -n "$CWD" ]; then
                    WORK_FILE="$CWD/.claude/state/work-active.json"
                    # Backward compatibility: try ultrawork-active.json if work-active.json does not exist
                    if [ ! -f "$WORK_FILE" ]; then
                      WORK_FILE="$CWD/.claude/state/ultrawork-active.json"
                    fi
                    if [ -f "$WORK_FILE" ] && command -v jq >/dev/null 2>&1; then
                      # 从 allowed_rm_paths 获取白名单
                      ALLOWED_PATHS=$(jq -r '.allowed_rm_paths[]? // empty' "$WORK_FILE" 2>/dev/null)
                      if [ -n "$ALLOWED_PATHS" ]; then
                        while IFS= read -r ALLOWED; do
                          if [ "$RM_TARGET" = "$ALLOWED" ]; then
                            RM_AUTO_APPROVE="true"
                            break
                          fi
                        done <<< "$ALLOWED_PATHS"
                      fi
                    fi
                  fi
                  ;;
              esac
              ;;
          esac
        fi
      fi
    fi

    # 非自动批准时需要确认
    if [ "$RM_AUTO_APPROVE" != "true" ]; then
      # Codex 模式时添加 PM 专用消息
      if [ "$CODEX_MODE" = "true" ]; then
        emit_ask "[Codex Mode] 确定要在 PM 模式下执行 rm -rf 吗？建议将实现委托给 Codex Worker。($COMMAND)"
      else
        emit_ask "$(msg ask_rm_rf "$COMMAND")"
      fi
      exit 0
    fi
    # else: 自动批准（无输出通过）
  fi

  # ===== Codex Mode: 简单 rm（不含 -r）也需要确认 =====
  if [ "$CODEX_MODE" = "true" ]; then
    if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])rm[[:space:]]'; then
      emit_ask "[Codex Mode] 确定要在 PM 模式下执行 rm 吗？建议将实现委托给 Codex Worker。"
      exit 0
    fi
  fi

  exit 0
fi

exit 0
