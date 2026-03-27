#!/bin/bash
# config-change.sh
# ConfigChange 钩子处理器（CC 2.1.49+）
#
# 配置文件变更时触发。仅当 breezing 激活时记录到时间线。
# 不阻塞 Stop（始终返回 {"ok":true}）。
#
# Input:  stdin (JSON: { file_path, change_type, ... })
# Output: {"ok": true}

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 加载 path-utils.sh
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh"
fi

# 确认 detect_project_root 已定义后再调用
if declare -F detect_project_root > /dev/null 2>&1; then
  PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"
else
  PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
fi

TIMELINE_FILE="${PROJECT_ROOT}/.claude/state/breezing-timeline.jsonl"
BREEZING_STATE_FILE="${PROJECT_ROOT}/.claude/state/breezing.json"

# 若无 jq 则立即返回 ok
if ! command -v jq &> /dev/null; then
  echo '{"ok":true}'
  exit 0
fi

# 检查 breezing 是否激活
BREEZING_ACTIVE=false
if [ -f "$BREEZING_STATE_FILE" ]; then
  BREEZING_STATUS=$(jq -r '.status // "inactive"' "$BREEZING_STATE_FILE" 2>/dev/null || echo "inactive")
  if [ "$BREEZING_STATUS" = "active" ] || [ "$BREEZING_STATUS" = "running" ]; then
    BREEZING_ACTIVE=true
  fi
fi

# 便携式 timeout 检测
_TIMEOUT=""
if command -v timeout > /dev/null 2>&1; then
  _TIMEOUT="timeout"
elif command -v gtimeout > /dev/null 2>&1; then
  _TIMEOUT="gtimeout"
fi

# 从 stdin 读取 Hook 载荷（带大小限制 + 超时）
PAYLOAD=""
if [ ! -t 0 ]; then
  if [ -n "$_TIMEOUT" ]; then
    PAYLOAD=$($_TIMEOUT 5 head -c 65536 2>/dev/null || true)
  else
    # 未安装 timeout: 使用 dd 确保字节数上限（POSIX 标准）
    PAYLOAD=$(dd bs=65536 count=1 2>/dev/null || true)
  fi
fi

# 仅当 breezing 激活时记录到时间线
if [ "$BREEZING_ACTIVE" = true ] && [ -n "$PAYLOAD" ]; then
  STATE_DIR="${PROJECT_ROOT}/.claude/state"
  mkdir -p "$STATE_DIR" 2>/dev/null || true

  # 将 file_path 标准化为仓库相对路径（隐藏用户名等）
  RAW_PATH=$(echo "$PAYLOAD" | jq -r '.file_path // "unknown"' 2>/dev/null || echo "unknown")
  if [ "$RAW_PATH" != "unknown" ] && [ -n "$PROJECT_ROOT" ]; then
    FILE_PATH="${RAW_PATH#"$PROJECT_ROOT"/}"
  else
    FILE_PATH="$RAW_PATH"
  fi
  CHANGE_TYPE=$(echo "$PAYLOAD" | jq -r '.change_type // "modified"' 2>/dev/null || echo "modified")
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")

  EVENT=$(jq -n \
    --arg ts "$TIMESTAMP" \
    --arg fp "$FILE_PATH" \
    --arg ct "$CHANGE_TYPE" \
    '{type: "config_change", timestamp: $ts, file_path: $fp, change_type: $ct}' 2>/dev/null || true)

  if [ -n "$EVENT" ]; then
    echo "$EVENT" >> "$TIMELINE_FILE" 2>/dev/null || true
  fi
fi

echo '{"ok":true}'
exit 0
