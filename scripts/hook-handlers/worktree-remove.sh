#!/bin/bash
# worktree-remove.sh — WorktreeRemove hook handler
# 清理 Breezing 子代理终止时 worktree 特定的资源
#
# 输入 (stdin JSON):
#   session_id, cwd, hook_event_name
#
# 设计: 仅负责 worktree 特定的临时文件
#       会话整体清理由 SessionEnd 负责

set -euo pipefail

# === 从 stdin 读取 JSON 载荷 ===
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

# 载荷为空时跳过
if [ -z "${INPUT}" ]; then
  echo '{"decision":"approve","reason":"WorktreeRemove: no payload"}'
  exit 0
fi

# === 字段提取 ===
SESSION_ID=""
CWD=""

if command -v jq >/dev/null 2>&1; then
  _jq_parsed="$(echo "${INPUT}" | jq -r '[
    (.session_id // ""),
    (.cwd // "")
  ] | @tsv' 2>/dev/null)"
  if [ -n "${_jq_parsed}" ]; then
    IFS=$'\t' read -r SESSION_ID CWD <<< "${_jq_parsed}"
  fi
  unset _jq_parsed
elif command -v python3 >/dev/null 2>&1; then
  _parsed="$(echo "${INPUT}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('session_id', ''))
    print(d.get('cwd', ''))
except:
    print('')
    print('')
" 2>/dev/null)"
  SESSION_ID="$(echo "${_parsed}" | sed -n '1p')"
  CWD="$(echo "${_parsed}" | sed -n '2p')"
fi

if [ -z "${SESSION_ID}" ]; then
  echo '{"decision":"approve","reason":"WorktreeRemove: no session_id"}'
  exit 0
fi

# === 清理 worktree 特定的临时文件 ===

# Codex 提示词临时文件（优先清理会话特定的文件）
rm -f /tmp/codex-prompt-*.md 2>/dev/null || true

# Harness Codex 日志（会话特定）
rm -f /tmp/harness-codex-*.log 2>/dev/null || true

# worktree-info.json 的清理
if [ -n "${CWD}" ] && [ -f "${CWD}/.claude/state/worktree-info.json" ]; then
  rm -f "${CWD}/.claude/state/worktree-info.json" 2>/dev/null || true
fi

# === 响应 ===
echo '{"decision":"approve","reason":"WorktreeRemove: cleaned up worktree resources"}'
exit 0
