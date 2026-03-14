#!/usr/bin/env bash
# post-compact.sh
# PostCompact フックハンドラ
# コンテキストコンパクション完了後に発火（PreCompact の対）
# WIP タスクがある場合は Plans.md の現在状態をサマリーとして additionalContext に注入
#
# Input: stdin JSON from Claude Code hooks
# Output: JSON with optional additionalContext for context re-injection
# Hook event: PostCompact

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

# ファイルパス
STATE_DIR="${PROJECT_ROOT}/.claude/state"
COMPACTION_LOG="${STATE_DIR}/compaction-events.jsonl"
PLANS_FILE="${PROJECT_ROOT}/Plans.md"
PRECOMPACT_SNAPSHOT="${STATE_DIR}/precompact-snapshot.json"

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

# Plans.md から WIP タスクを抽出してサマリーを生成
get_wip_summary() {
  if [ ! -f "${PLANS_FILE}" ]; then
    return 0
  fi

  local wip_lines=""

  if command -v python3 >/dev/null 2>&1; then
    wip_lines="$(python3 -c "
import sys

plans_path = sys.argv[1]
try:
    with open(plans_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    wip_tasks = []
    for line in lines:
        stripped = line.strip()
        if 'cc:WIP' in stripped or 'cc:TODO' in stripped:
            wip_tasks.append(stripped)
    if wip_tasks:
        print('\\n'.join(wip_tasks[:20]))
except Exception:
    pass
" "${PLANS_FILE}" 2>/dev/null)" || wip_lines=""
  else
    # python3 がない場合は grep でフォールバック
    wip_lines="$(grep -E 'cc:WIP|cc:TODO' "${PLANS_FILE}" 2>/dev/null | head -20)" || wip_lines=""
  fi

  printf '%s' "${wip_lines}"
}

# PreCompact スナップショットからコンテキストを復元
get_precompact_context() {
  if [ ! -f "${PRECOMPACT_SNAPSHOT}" ]; then
    return 0
  fi

  local context=""

  if command -v jq >/dev/null 2>&1; then
    local wip_tasks=""
    local recent_edits=""
    wip_tasks="$(jq -r '.wipTasks // [] | join(", ")' "${PRECOMPACT_SNAPSHOT}" 2>/dev/null)" || wip_tasks=""
    recent_edits="$(jq -r '.recentEdits // [] | .[0:10] | join(", ")' "${PRECOMPACT_SNAPSHOT}" 2>/dev/null)" || recent_edits=""

    if [ -n "${wip_tasks}" ]; then
      context="Pre-compaction WIP tasks: ${wip_tasks}"
    fi
    if [ -n "${recent_edits}" ]; then
      if [ -n "${context}" ]; then
        context="${context}. Recent edits: ${recent_edits}"
      else
        context="Recent edits: ${recent_edits}"
      fi
    fi
  elif command -v python3 >/dev/null 2>&1; then
    context="$(python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    parts = []
    wip = d.get('wipTasks', [])
    if wip:
        parts.append('Pre-compaction WIP tasks: ' + ', '.join(wip))
    edits = d.get('recentEdits', [])[:10]
    if edits:
        parts.append('Recent edits: ' + ', '.join(edits))
    print('. '.join(parts))
except Exception:
    pass
" "${PRECOMPACT_SNAPSHOT}" 2>/dev/null)" || context=""
  fi

  printf '%s' "${context}"
}

# === stdin から JSON ペイロードを読み取り ===
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

# ペイロードが空の場合はスキップ
if [ -z "${INPUT}" ]; then
  echo '{"decision":"approve","reason":"PostCompact: no payload"}'
  exit 0
fi

# === コンパクション後のコンテキスト再注入 ===
ensure_state_dir
TS="$(get_timestamp)"

# WIP タスクサマリーを取得
WIP_SUMMARY="$(get_wip_summary)"

# PreCompact スナップショットからコンテキストを復元
PRECOMPACT_CONTEXT="$(get_precompact_context)"

# === イベント記録 ===
log_entry=""
if command -v jq >/dev/null 2>&1; then
  log_entry="$(jq -nc \
    --arg event "post_compact" \
    --arg has_wip "$([ -n "${WIP_SUMMARY}" ] && echo "true" || echo "false")" \
    --arg has_snapshot "$([ -f "${PRECOMPACT_SNAPSHOT}" ] && echo "true" || echo "false")" \
    --arg timestamp "${TS}" \
    '{event:$event, has_wip:$has_wip, has_snapshot:$has_snapshot, timestamp:$timestamp}')"
elif command -v python3 >/dev/null 2>&1; then
  log_entry="$(python3 -c "
import json, sys
print(json.dumps({
    'event': 'post_compact',
    'has_wip': sys.argv[1],
    'has_snapshot': sys.argv[2],
    'timestamp': sys.argv[3]
}, ensure_ascii=False))
" "$([ -n "${WIP_SUMMARY}" ] && echo "true" || echo "false")" "$([ -f "${PRECOMPACT_SNAPSHOT}" ] && echo "true" || echo "false")" "${TS}" 2>/dev/null)" || log_entry=""
fi

if [ -n "${log_entry}" ]; then
  echo "${log_entry}" >> "${COMPACTION_LOG}" 2>/dev/null || true
  rotate_jsonl "${COMPACTION_LOG}"
fi

# === レスポンス生成 ===

# additionalContext を構築
ADDITIONAL_CONTEXT=""

if [ -n "${WIP_SUMMARY}" ]; then
  ADDITIONAL_CONTEXT="[PostCompact Re-injection] Context was just compacted. The following WIP/TODO tasks are active in Plans.md:
${WIP_SUMMARY}"
fi

if [ -n "${PRECOMPACT_CONTEXT}" ]; then
  if [ -n "${ADDITIONAL_CONTEXT}" ]; then
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}

${PRECOMPACT_CONTEXT}"
  else
    ADDITIONAL_CONTEXT="[PostCompact Re-injection] Context was just compacted. ${PRECOMPACT_CONTEXT}"
  fi
fi

# additionalContext がある場合はレスポンスに含める
if [ -n "${ADDITIONAL_CONTEXT}" ]; then
  if command -v jq >/dev/null 2>&1; then
    jq -nc \
      --arg reason "PostCompact: context re-injected" \
      --arg ctx "${ADDITIONAL_CONTEXT}" \
      '{"decision":"approve","reason":$reason,"additionalContext":$ctx}'
  else
    # jq がない場合のフォールバック
    _escaped_ctx="${ADDITIONAL_CONTEXT//\\/\\\\}"
    _escaped_ctx="${_escaped_ctx//\"/\\\"}"
    _escaped_ctx="${_escaped_ctx//$'\n'/\\n}"
    printf '{"decision":"approve","reason":"PostCompact: context re-injected","additionalContext":"%s"}\n' "${_escaped_ctx}"
  fi
else
  echo '{"decision":"approve","reason":"PostCompact: no WIP tasks to re-inject"}'
fi

exit 0
