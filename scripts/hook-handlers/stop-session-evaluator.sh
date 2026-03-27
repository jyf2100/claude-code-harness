#!/bin/bash
# stop-session-evaluator.sh
# Stop 钩子的会话完成评估
#
# 作为 prompt type 的替代方案，输出可靠有效 JSON 的 command type 钩子。
# 检查会话状态，判断是否允许或阻止停止。
# CC 2.1.47+: 从 stdin 读取 last_assistant_message 并记录到 session.json。
#
# Input:  stdin (JSON: { stop_hook_active, transcript_path, last_assistant_message, ... })
# Output: {"ok": true} or {"ok": false, "reason": "..."}
#
# Issue: #42 - Stop hook "JSON validation failed" on every turn

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 加载 path-utils.sh
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh"
fi

# 确认 detect_project_root 是否定义后再调用
if declare -F detect_project_root > /dev/null 2>&1; then
  PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"
else
  PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
fi

STATE_FILE="${PROJECT_ROOT}/.claude/state/session.json"

# 如果没有 jq 则立即返回 ok（安全回退）
if ! command -v jq &> /dev/null; then
  echo '{"ok":true}'
  exit 0
fi

# 可移植 timeout 检测
_TIMEOUT=""
if command -v timeout > /dev/null 2>&1; then
  _TIMEOUT="timeout"
elif command -v gtimeout > /dev/null 2>&1; then
  _TIMEOUT="gtimeout"
fi

# 从 stdin 读取 Hook 负载（带大小限制和超时）
PAYLOAD=""
if [ -t 0 ]; then
  # 当 stdin 是 TTY 时跳过（如测试运行时）
  :
else
  if [ -n "$_TIMEOUT" ]; then
    PAYLOAD=$($_TIMEOUT 5 head -c 65536 2>/dev/null || true)
  else
    # 未安装 timeout: 使用 dd 保证字节数上限（POSIX 标准）
    PAYLOAD=$(dd bs=65536 count=1 2>/dev/null || true)
  fi
fi

# 将 last_assistant_message 的元数据记录到 session.json（内容进行哈希处理）
if [ -n "$PAYLOAD" ] && [ -f "$STATE_FILE" ]; then
  LAST_MSG=$(echo "$PAYLOAD" | jq -r '.last_assistant_message // ""' 2>/dev/null || true)
  if [ -n "$LAST_MSG" ] && [ "$LAST_MSG" != "null" ]; then
    # 仅记录消息长度和哈希（不保存明文内容）
    MSG_LENGTH=${#LAST_MSG}
    # 可移植哈希: shasum (macOS) / sha256sum (Linux) / fallback
    if command -v shasum > /dev/null 2>&1; then
      MSG_HASH=$(printf '%s' "$LAST_MSG" | shasum -a 256 | cut -c1-16)
    elif command -v sha256sum > /dev/null 2>&1; then
      MSG_HASH=$(printf '%s' "$LAST_MSG" | sha256sum | cut -c1-16)
    else
      MSG_HASH="no-hash"
    fi
    # 原子写入: mktemp + mv
    STATE_DIR="$(dirname "$STATE_FILE")"
    TMP_FILE=$(mktemp "${STATE_DIR}/session.json.XXXXXX" 2>/dev/null || echo "")
    if [ -n "$TMP_FILE" ]; then
      trap 'rm -f "$TMP_FILE"' EXIT
      jq --argjson len "$MSG_LENGTH" --arg hash "$MSG_HASH" \
        '.last_message_length = $len | .last_message_hash = $hash' \
        "$STATE_FILE" > "$TMP_FILE" 2>/dev/null && mv "$TMP_FILE" "$STATE_FILE" || rm -f "$TMP_FILE"
      trap - EXIT
    fi
  fi
fi

# 如果没有状态文件则立即返回 ok
if [ ! -f "$STATE_FILE" ]; then
  echo '{"ok":true}'
  exit 0
fi

# 检查会话状态
SESSION_STATE=$(jq -r '.state // "unknown"' "$STATE_FILE" 2>/dev/null)

# 如果已经处理过停止则立即返回 ok
if [ "$SESSION_STATE" = "stopped" ]; then
  echo '{"ok":true}'
  exit 0
fi

# 默认: 允许停止
# 如果用户明确按下 Stop，基本上允许停止
echo '{"ok":true}'
exit 0
