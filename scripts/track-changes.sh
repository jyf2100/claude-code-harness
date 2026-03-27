#!/bin/bash
# track-changes.sh
# 跟踪文件变更并更新状态文件
#
# Usage: 从 PostToolUse hook 自动执行
# Input: stdin JSON (Claude Code hooks) / 兼容: $1=tool_name, $2=file_path
#
# Cross-platform: Supports Windows (Git Bash/MSYS2/Cygwin/WSL), macOS, Linux

set +e

# Load cross-platform path utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/path-utils.sh" ]; then
  # shellcheck source=./path-utils.sh
  source "$SCRIPT_DIR/path-utils.sh"
else
  # Fallback: minimal normalize_path and is_path_under
  normalize_path() {
    local p="$1"
    p="${p//\\//}"
    echo "$p"
  }
  is_path_under() {
    local child="$1"
    local parent="$2"
    child="$(normalize_path "$child")"
    parent="$(normalize_path "$parent")"
    [[ "$parent" != */ ]] && parent="${parent}/"
    [[ "${child}/" == "${parent}"* ]] || [ "$child" = "${parent%/}" ]
  }
fi

INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

TOOL_NAME="${1:-}"
FILE_PATH="${2:-}"
CWD=""

if [ -n "$INPUT" ]; then
  if command -v jq >/dev/null 2>&1; then
    TOOL_NAME_FROM_STDIN="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
    FILE_PATH_FROM_STDIN="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)"
    CWD_FROM_STDIN="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
  elif command -v python3 >/dev/null 2>&1; then
    eval "$(printf '%s' "$INPUT" | python3 -c '
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
tool_name = data.get("tool_name") or ""
cwd = data.get("cwd") or ""
tool_input = data.get("tool_input") or {}
tool_response = data.get("tool_response") or {}
file_path = tool_input.get("file_path") or tool_response.get("filePath") or ""
print(f"TOOL_NAME_FROM_STDIN={shlex.quote(tool_name)}")
print(f"CWD_FROM_STDIN={shlex.quote(cwd)}")
print(f"FILE_PATH_FROM_STDIN={shlex.quote(file_path)}")
' 2>/dev/null)"
  fi

  [ -z "$TOOL_NAME" ] && TOOL_NAME="${TOOL_NAME_FROM_STDIN:-}"
  [ -z "$FILE_PATH" ] && FILE_PATH="${FILE_PATH_FROM_STDIN:-}"
  CWD="${CWD_FROM_STDIN:-}"
fi

TOOL_NAME="${TOOL_NAME:-unknown}"

# 尽可能规范化为项目相对路径（跨平台兼容）
if [ -n "$CWD" ] && [ -n "$FILE_PATH" ]; then
  NORM_FILE_PATH="$(normalize_path "$FILE_PATH")"
  NORM_CWD="$(normalize_path "$CWD")"

  if is_path_under "$NORM_FILE_PATH" "$NORM_CWD"; then
    # Remove the CWD prefix to get relative path
    cwd_with_slash="${NORM_CWD%/}/"
    if [[ "$NORM_FILE_PATH" == "$cwd_with_slash"* ]]; then
      FILE_PATH="${NORM_FILE_PATH#$cwd_with_slash}"
    fi
  fi
fi
STATE_FILE=".claude/state/session.json"
CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 如果状态文件不存在则跳过
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# 如果没有文件路径则跳过
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 检测重要文件的变更
IMPORTANT_FILES="Plans.md CLAUDE.md AGENTS.md"
IS_IMPORTANT="false"

for important in $IMPORTANT_FILES; do
  if [[ "$FILE_PATH" == *"$important"* ]]; then
    IS_IMPORTANT="true"
    break
  fi
done

# 检测测试文件
if [[ "$FILE_PATH" == *".test."* ]] || [[ "$FILE_PATH" == *".spec."* ]] || [[ "$FILE_PATH" == *"__tests__"* ]]; then
  IS_IMPORTANT="true"
fi

# 记录变更（如有 jq 则使用，否则跳过）
if command -v jq &> /dev/null; then
  # 添加新的变更记录
  TEMP_FILE=$(mktemp 2>/dev/null) || {
    # mktemp 失败时静默跳过（因为是 PostToolUse hook，所以不中断）
    exit 0
  }
  # 保证清理
  trap 'rm -f "$TEMP_FILE"' EXIT

  if jq --arg file "$FILE_PATH" \
        --arg action "$TOOL_NAME" \
        --arg timestamp "$CURRENT_TIME" \
        --arg important "$IS_IMPORTANT" \
        '.changes_this_session += [{
          "file": $file,
          "action": $action,
          "timestamp": $timestamp,
          "important": ($important == "true")
        }]' "$STATE_FILE" > "$TEMP_FILE" 2>/dev/null; then
    mv "$TEMP_FILE" "$STATE_FILE" 2>/dev/null || true
  fi
fi

# 重要文件变更时通知
if [ "$IS_IMPORTANT" = "true" ]; then
  case "$FILE_PATH" in
    *Plans.md*)
      echo "📋 Plans.md 已更新"
      ;;
    *CLAUDE.md*)
      echo "📝 CLAUDE.md 已更新"
      ;;
    *AGENTS.md*)
      echo "📝 AGENTS.md 已更新"
      ;;
    *.test.*|*.spec.*|*__tests__*)
      echo "🧪 测试文件已更新: $(basename "$FILE_PATH")"
      ;;
  esac
fi

# ==============================================================================
# Work 模式下的 review_status 重置
# ==============================================================================
# 在 /work 执行期间如果发生 Write/Edit，将 review_status 重置为 pending
# 这确保代码变更后必须重新进行审查
# 向后兼容: 优先使用 work-active.json，回退到 ultrawork-active.json
# ==============================================================================
WORK_FILE=".claude/state/work-active.json"
if [ ! -f "$WORK_FILE" ]; then
  WORK_FILE=".claude/state/ultrawork-active.json"
fi
if [ -f "$WORK_FILE" ] && command -v jq >/dev/null 2>&1; then
  CURRENT_STATUS=$(jq -r '.review_status // "pending"' "$WORK_FILE" 2>/dev/null)

  # 仅在 passed 或 failed 时重置为 pending
  if [ "$CURRENT_STATUS" = "passed" ] || [ "$CURRENT_STATUS" = "failed" ]; then
    TEMP_UW=$(mktemp 2>/dev/null)
    if [ -n "$TEMP_UW" ]; then
      if jq '.review_status = "pending"' "$WORK_FILE" > "$TEMP_UW" 2>/dev/null; then
        mv "$TEMP_UW" "$WORK_FILE" 2>/dev/null || rm -f "$TEMP_UW"
        echo "⚠️ work: 检测到代码变更 → review_status 已重置为 pending（必须重新审查）" >&2
      else
        rm -f "$TEMP_UW"
      fi
    fi
  fi
fi

exit 0
