#!/bin/bash
# auto-cleanup-hook.sh
# PostToolUse Hook: 写入 Plans.md 等文件后自动进行大小检查
#
# 输入: 从 stdin 读取 JSON（tool_name, tool_input 等）
# 输出: 通过 additionalContext 提供反馈

set +e

# 读取输入 JSON（Claude Code hooks 通过 stdin 传递 JSON）
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

# 从 stdin JSON 获取 file_path / cwd（如果没有 jq 则尝试 python3）
FILE_PATH=""
CWD=""
if [ -n "$INPUT" ]; then
  if command -v jq >/dev/null 2>&1; then
    FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)"
    CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
  elif command -v python3 >/dev/null 2>&1; then
    eval "$(printf '%s' "$INPUT" | python3 -c '
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
cwd = data.get("cwd") or ""
tool_input = data.get("tool_input") or {}
tool_response = data.get("tool_response") or {}
file_path = tool_input.get("file_path") or tool_response.get("filePath") or ""
print(f"CWD_FROM_STDIN={shlex.quote(cwd)}")
print(f"FILE_PATH_FROM_STDIN={shlex.quote(file_path)}")
' 2>/dev/null)"
    FILE_PATH="${FILE_PATH_FROM_STDIN:-}"
    CWD="${CWD_FROM_STDIN:-}"
  fi
fi

# 如果 file_path 为空则退出
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 如果可能则规范化为项目相对路径（绝对路径也能工作，但相对路径判断更稳定）
if [ -n "$CWD" ] && [[ "$FILE_PATH" == "$CWD/"* ]]; then
  FILE_PATH="${FILE_PATH#$CWD/}"
fi

# 默认阈值
PLANS_MAX_LINES=${PLANS_MAX_LINES:-200}
SESSION_LOG_MAX_LINES=${SESSION_LOG_MAX_LINES:-500}
CLAUDE_MD_MAX_LINES=${CLAUDE_MD_MAX_LINES:-100}

# 存储反馈的变量
FEEDBACK=""

# 检查 Plans.md
if [[ "$FILE_PATH" == *"Plans.md"* ]] || [[ "$FILE_PATH" == *"plans.md"* ]]; then
  if [ -f "$FILE_PATH" ]; then
    lines=$(wc -l < "$FILE_PATH" | tr -d ' ')
    if [ "$lines" -gt "$PLANS_MAX_LINES" ]; then
      FEEDBACK="⚠️ Plans.md 已达 ${lines} 行（上限: ${PLANS_MAX_LINES} 行）。建议使用 /maintenance 将旧任务归档。"
    fi

    # Plans.md 清理（归档移动）检测时的 SSOT 同步检查
    # 如果编辑了归档部分，确认已预先执行 /memory sync
    if grep -q "📦 归档\|## 归档\|Archive" "$FILE_PATH" 2>/dev/null; then
      # Resolve repository root for consistent state directory lookup
      CWD="${CWD:-$(pwd)}"  # Fallback to pwd if empty
      REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || REPO_ROOT="$CWD"
      STATE_DIR="${REPO_ROOT}/.claude/state"

      SSOT_FLAG="${STATE_DIR}/.ssot-synced-this-session"

      if [ ! -f "$SSOT_FLAG" ]; then
        # 如果标志不存在，添加警告以提示 SSOT 同步
        SSOT_WARNING="**Plans.md 清理前请执行 /memory sync** - 重要决定或学习内容可能尚未反映到 SSOT (decisions.md/patterns.md)。"

        if [ -n "$FEEDBACK" ]; then
          FEEDBACK="${FEEDBACK} | ${SSOT_WARNING}"
        else
          FEEDBACK="⚠️ ${SSOT_WARNING}"
        fi
      fi
    fi
  fi
fi

# 检查 session-log.md
if [[ "$FILE_PATH" == *"session-log.md"* ]]; then
  if [ -f "$FILE_PATH" ]; then
    lines=$(wc -l < "$FILE_PATH" | tr -d ' ')
    if [ "$lines" -gt "$SESSION_LOG_MAX_LINES" ]; then
      FEEDBACK="⚠️ session-log.md 已达 ${lines} 行（上限: ${SESSION_LOG_MAX_LINES} 行）。建议使用 /maintenance 按月份分割。"
    fi
  fi
fi

# 检查 CLAUDE.md
if [[ "$FILE_PATH" == *"CLAUDE.md"* ]] || [[ "$FILE_PATH" == *"claude.md"* ]]; then
  if [ -f "$FILE_PATH" ]; then
    lines=$(wc -l < "$FILE_PATH" | tr -d ' ')
    if [ "$lines" -gt "$CLAUDE_MD_MAX_LINES" ]; then
      FEEDBACK="⚠️ CLAUDE.md 已达 ${lines} 行。请考虑将其拆分到 .claude/rules/，或移动到 docs/ 并通过 @docs/filename.md 引用。"
    fi
  fi
fi

# 如果有反馈则以 JSON 格式输出
if [ -n "$FEEDBACK" ]; then
  echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PostToolUse\", \"additionalContext\": \"$FEEDBACK\"}}"
fi

# 始终以成功状态退出
exit 0
