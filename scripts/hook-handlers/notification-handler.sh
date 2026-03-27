#!/usr/bin/env bash
# notification-handler.sh
# Notification 钩子处理器
# Claude Code 发出通知时触发
# 记录 permission_prompt、idle_prompt、auth_success 等事件
#
# Input: stdin JSON from Claude Code hooks
# Output: JSON to approve the event
# Hook event: Notification

set -euo pipefail

# === 配置 ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 加载 path-utils.sh
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh"
fi

# 检测项目根目录
PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"

# 日志文件（使用 CLAUDE_PLUGIN_DATA 时按项目隔离）
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  _project_hash="$(printf '%s' "${PROJECT_ROOT}" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null || echo "default  -"; } | cut -c1-12)"
  [ -z "${_project_hash}" ] && _project_hash="default"
  STATE_DIR="${CLAUDE_PLUGIN_DATA}/projects/${_project_hash}"
else
  STATE_DIR="${PROJECT_ROOT}/.claude/state"
fi
LOG_FILE="${STATE_DIR}/notification-events.jsonl"

# === 工具函数 ===

ensure_state_dir() {
  local state_parent
  state_parent="$(dirname "${STATE_DIR}")"

  # Security: refuse symlinked state paths to avoid overwriting arbitrary files.
  if [ -L "${state_parent}" ] || [ -L "${STATE_DIR}" ]; then
    return 1
  fi

  mkdir -p "${STATE_DIR}" 2>/dev/null || true
  chmod 700 "${STATE_DIR}" 2>/dev/null || true

  [ -d "${STATE_DIR}" ] || return 1
  [ ! -L "${STATE_DIR}" ] || return 1
  return 0
}

# JSONL 轮转（超过 500 行时截断为 400 行）
rotate_jsonl() {
  local file="$1"

  # Security: refuse symlinked log or tmp files
  if [ -L "${file}" ] || [ -L "${file}.tmp" ]; then
    return 1
  fi

  local _lines
  _lines="$(wc -l < "${file}" 2>/dev/null)" || _lines=0
  if [ "${_lines}" -gt 500 ] 2>/dev/null; then
    tail -400 "${file}" > "${file}.tmp" 2>/dev/null && \
      mv "${file}.tmp" "${file}" 2>/dev/null || true
  fi
}

get_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# === 从 stdin 读取 JSON 载荷 ===
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

# 载荷为空时跳过
if [ -z "${INPUT}" ]; then
  exit 0
fi

# === 字段提取 ===
NOTIFICATION_TYPE=""
SESSION_ID=""
AGENT_TYPE=""

if command -v jq >/dev/null 2>&1; then
  NOTIFICATION_TYPE="$(printf '%s' "${INPUT}" | jq -r '.notification_type // .type // .matcher // ""' 2>/dev/null || true)"
  SESSION_ID="$(printf '%s' "${INPUT}" | jq -r '.session_id // ""' 2>/dev/null || true)"
  AGENT_TYPE="$(printf '%s' "${INPUT}" | jq -r '.agent_type // ""' 2>/dev/null || true)"
elif command -v python3 >/dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('notification_type', d.get('type', d.get('matcher', ''))))
    print(d.get('session_id', ''))
    print(d.get('agent_type', ''))
except:
    print('')
    print('')
    print('')
" 2>/dev/null)"
  NOTIFICATION_TYPE="$(echo "${_parsed}" | sed -n '1p')"
  SESSION_ID="$(echo "${_parsed}" | sed -n '2p')"
  AGENT_TYPE="$(echo "${_parsed}" | sed -n '3p')"
fi

# === 日志记录 ===
if ! ensure_state_dir; then
  exit 0
fi
TS="$(get_timestamp)"

log_entry=""
if command -v jq >/dev/null 2>&1; then
  log_entry="$(jq -nc \
    --arg event "notification" \
    --arg notification_type "${NOTIFICATION_TYPE}" \
    --arg session_id "${SESSION_ID}" \
    --arg agent_type "${AGENT_TYPE}" \
    --arg timestamp "${TS}" \
    '{event:$event, notification_type:$notification_type, session_id:$session_id, agent_type:$agent_type, timestamp:$timestamp}')"
elif command -v python3 >/dev/null 2>&1; then
  log_entry="$(python3 -c "
import json, sys
print(json.dumps({
    'event': 'notification',
    'notification_type': sys.argv[1],
    'session_id': sys.argv[2],
    'agent_type': sys.argv[3],
    'timestamp': sys.argv[4]
}, ensure_ascii=False))
" "${NOTIFICATION_TYPE}" "${SESSION_ID}" "${AGENT_TYPE}" "${TS}" 2>/dev/null)" || log_entry=""
fi

if [ -n "${log_entry}" ]; then
  # Security: refuse symlinked log file
  if [ -L "${LOG_FILE}" ]; then
    exit 0
  fi
  echo "${log_entry}" >> "${LOG_FILE}" 2>/dev/null || true
  rotate_jsonl "${LOG_FILE}"
fi

# === Breezing 中的重要通知检测 ===
# Breezing 的后台 Worker 无法进行 UI 操作
# 通过日志记录使事后分析成为可能

# permission_prompt：Worker 无法响应权限对话框
if [ "${NOTIFICATION_TYPE}" = "permission_prompt" ] && [ -n "${AGENT_TYPE}" ]; then
  echo "Notification: permission_prompt for agent_type=${AGENT_TYPE}" >&2
fi

# elicitation_dialog：MCP 服务器的输入请求（v2.1.76+）
# 后台 Worker 无法响应 Elicitation 表单
# Elicitation 钩子已自动跳过，但通知日志中仍保留
if [ "${NOTIFICATION_TYPE}" = "elicitation_dialog" ] && [ -n "${AGENT_TYPE}" ]; then
  echo "Notification: elicitation_dialog for agent_type=${AGENT_TYPE} (auto-skipped in background)" >&2
fi

exit 0
