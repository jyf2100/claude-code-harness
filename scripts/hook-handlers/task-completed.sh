#!/bin/bash
# task-completed.sh
# TaskCompleted フックハンドラ
# タスクが完了した時にタイムラインに記録する
#
# Input: stdin JSON from Claude Code hooks
# Output: JSON to approve the event

set -euo pipefail

# === 設定 ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# path-utils.sh の読み込み
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh"
fi

# プロジェクトルートを検出
PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"

# タイムラインファイル
STATE_DIR="${PROJECT_ROOT}/.claude/state"
TIMELINE_FILE="${STATE_DIR}/breezing-timeline.jsonl"

# === ユーティリティ関数 ===

ensure_state_dir() {
  mkdir -p "${STATE_DIR}" 2>/dev/null || true
  chmod 700 "${STATE_DIR}" 2>/dev/null || true
}

# JSONL ローテーション（500 行超過時に 400 行に切り詰め）
rotate_jsonl() {
  local file="$1"
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

# === stdin から JSON ペイロードを読み取り ===
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

# ペイロードが空の場合はスキップ
if [ -z "${INPUT}" ]; then
  echo '{"decision":"approve","reason":"TaskCompleted: no payload"}'
  exit 0
fi

# === フィールド抽出 ===
TEAMMATE_NAME=""
TASK_ID=""
TASK_SUBJECT=""
TASK_DESCRIPTION=""

if command -v jq >/dev/null 2>&1; then
  _jq_parsed="$(echo "${INPUT}" | jq -r '[
    (.teammate_name // .agent_name // ""),
    (.task_id // ""),
    (.task_subject // .subject // ""),
    ((.task_description // .description // "" | tostring)[0:100])
  ] | @tsv' 2>/dev/null)"
  if [ -n "${_jq_parsed}" ]; then
    IFS=$'\t' read -r TEAMMATE_NAME TASK_ID TASK_SUBJECT TASK_DESCRIPTION <<< "${_jq_parsed}"
  fi
  unset _jq_parsed
elif command -v python3 >/dev/null 2>&1; then
  _parsed="$(echo "${INPUT}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('teammate_name', d.get('agent_name', '')))
    print(d.get('task_id', ''))
    print(d.get('task_subject', d.get('subject', '')))
    print(str(d.get('task_description', d.get('description', '')))[:100])
except:
    print('')
    print('')
    print('')
    print('')
" 2>/dev/null)"
  TEAMMATE_NAME="$(echo "${_parsed}" | sed -n '1p')"
  TASK_ID="$(echo "${_parsed}" | sed -n '2p')"
  TASK_SUBJECT="$(echo "${_parsed}" | sed -n '3p')"
  TASK_DESCRIPTION="$(echo "${_parsed}" | sed -n '4p')"
fi

# === タイムライン記録（jq -nc で安全な JSON 構築） ===
ensure_state_dir
TS="$(get_timestamp)"

if command -v jq >/dev/null 2>&1; then
  log_entry="$(jq -nc \
    --arg event "task_completed" \
    --arg teammate "${TEAMMATE_NAME}" \
    --arg task_id "${TASK_ID}" \
    --arg subject "${TASK_SUBJECT}" \
    --arg description "${TASK_DESCRIPTION}" \
    --arg timestamp "${TS}" \
    '{event:$event, teammate:$teammate, task_id:$task_id, subject:$subject, description:$description, timestamp:$timestamp}')"
else
  # フォールバック: python3 で安全にエスケープ
  log_entry="$(python3 -c "
import json, sys
print(json.dumps({
    'event': 'task_completed',
    'teammate': sys.argv[1],
    'task_id': sys.argv[2],
    'subject': sys.argv[3],
    'description': sys.argv[4],
    'timestamp': sys.argv[5]
}, ensure_ascii=False))
" "${TEAMMATE_NAME}" "${TASK_ID}" "${TASK_SUBJECT}" "${TASK_DESCRIPTION}" "${TS}" 2>/dev/null)" || log_entry=""
fi

if [ -n "${log_entry}" ]; then
  echo "${log_entry}" >> "${TIMELINE_FILE}" 2>/dev/null || true
  rotate_jsonl "${TIMELINE_FILE}"
fi

# === レスポンス ===
echo '{"decision":"approve","reason":"TaskCompleted tracked"}'
exit 0
