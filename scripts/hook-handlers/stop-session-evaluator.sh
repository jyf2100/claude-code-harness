#!/bin/bash
# stop-session-evaluator.sh
# Stop フックのセッション完了評価
#
# prompt type の代替として、確実に有効な JSON を出力する command type フック。
# セッション状態を検査し、停止を許可 or ブロックの判定を行う。
# CC 2.1.47+: stdin から last_assistant_message を読み取り session.json に記録する。
#
# Input:  stdin (JSON: { stop_hook_active, transcript_path, last_assistant_message, ... })
# Output: {"ok": true} or {"ok": false, "reason": "..."}
#
# Issue: #42 - Stop hook "JSON validation failed" on every turn

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# path-utils.sh の読み込み
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh"
fi

PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"

STATE_FILE="${PROJECT_ROOT}/.claude/state/session.json"

# jq がなければ即座に ok を返す（安全なフォールバック）
if ! command -v jq &> /dev/null; then
  echo '{"ok":true}'
  exit 0
fi

# stdin から Hook ペイロードを読み取る（タイムアウト付き）
PAYLOAD=""
if [ -t 0 ]; then
  # stdin が TTY の場合はスキップ（テスト実行時等）
  :
else
  PAYLOAD=$(timeout 5 cat 2>/dev/null || true)
fi

# last_assistant_message を抽出して session.json に記録
if [ -n "$PAYLOAD" ] && [ -f "$STATE_FILE" ]; then
  LAST_MSG=$(echo "$PAYLOAD" | jq -r '.last_assistant_message // ""' 2>/dev/null || true)
  if [ -n "$LAST_MSG" ] && [ "$LAST_MSG" != "null" ]; then
    # メッセージの先頭200文字を要約として記録
    SUMMARY="${LAST_MSG:0:200}"
    # session.json の last_message_summary フィールドを更新
    TMP_FILE="${STATE_FILE}.tmp"
    jq --arg summary "$SUMMARY" '.last_message_summary = $summary' "$STATE_FILE" > "$TMP_FILE" 2>/dev/null && mv "$TMP_FILE" "$STATE_FILE" || rm -f "$TMP_FILE"
  fi
fi

# 状態ファイルがなければ即座に ok を返す
if [ ! -f "$STATE_FILE" ]; then
  echo '{"ok":true}'
  exit 0
fi

# セッション状態を検査
SESSION_STATE=$(jq -r '.state // "unknown"' "$STATE_FILE" 2>/dev/null)

# 既に停止処理済みなら即座に ok
if [ "$SESSION_STATE" = "stopped" ]; then
  echo '{"ok":true}'
  exit 0
fi

# デフォルト: 停止を許可
# ユーザーが明示的に Stop を押した場合、基本的に停止を許可する
echo '{"ok":true}'
exit 0
