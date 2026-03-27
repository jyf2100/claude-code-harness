#!/bin/bash
# todo-sync.sh
# TodoWrite 与 Plans.md 的双向同步
#
# 从 PostToolUse hook 调用，将 TodoWrite 的状态变更反映到 Plans.md
#
# 映射:
#   TodoWrite状态     → Plans.md标记
#   pending          → cc:TODO
#   in_progress      → cc:WIP
#   completed        → cc:done

set +e  # 遇到错误不停止

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 从 stdin 读取 JSON 输入
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat 2>/dev/null || true)
fi

# 需要 jq
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# 如果没有输入则退出
if [ -z "$INPUT" ]; then
  exit 0
fi

# 解析 TodoWrite 工具的输出
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# 忽略非 TodoWrite 的调用
if [ "$TOOL_NAME" != "TodoWrite" ]; then
  exit 0
fi

# 获取 Plans.md 的路径
if [ -f "${SCRIPT_DIR}/config-utils.sh" ]; then
  source "${SCRIPT_DIR}/config-utils.sh"
  PLANS_FILE=$(get_plans_file_path)
else
  PLANS_FILE="Plans.md"
fi

# 如果 Plans.md 不存在则退出
if [ ! -f "$PLANS_FILE" ]; then
  exit 0
fi

# 状态目录
STATE_DIR=".claude/state"
mkdir -p "$STATE_DIR"
SYNC_STATE_FILE="${STATE_DIR}/todo-sync-state.json"

# 获取 TodoWrite 的 todos 数组
TODOS=$(echo "$INPUT" | jq -r '.tool_input.todos // []' 2>/dev/null)

if [ -z "$TODOS" ] || [ "$TODOS" = "null" ] || [ "$TODOS" = "[]" ]; then
  exit 0
fi

# 保存同步状态
echo "$TODOS" | jq '{
  synced_at: (now | todate),
  todos: .
}' > "$SYNC_STATE_FILE" 2>/dev/null

# 更新 Plans.md 中的任务状态
# 注意: 在维持 Plans.md 格式的同时进行更新较为复杂，
# 因此这里仅记录到日志，实际更新交给 Claude Code 处理

# 记录到事件日志
EVENT_LOG="${STATE_DIR}/session.events.jsonl"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

PENDING_COUNT=$(echo "$TODOS" | jq '[.[] | select(.status == "pending")] | length' 2>/dev/null || echo "0")
WIP_COUNT=$(echo "$TODOS" | jq '[.[] | select(.status == "in_progress")] | length' 2>/dev/null || echo "0")
DONE_COUNT=$(echo "$TODOS" | jq '[.[] | select(.status == "completed")] | length' 2>/dev/null || echo "0")

if [ -f "$EVENT_LOG" ]; then
  echo "{\"type\":\"todo.sync\",\"ts\":\"$NOW\",\"data\":{\"pending\":$PENDING_COUNT,\"in_progress\":$WIP_COUNT,\"completed\":$DONE_COUNT}}" >> "$EVENT_LOG"
fi

# ===== Work 模式下的全部完成检测与警告 =====
WORK_WARNING=""
WORK_FILE="${STATE_DIR}/work-active.json"
# 向后兼容: 如果 work-active.json 不存在则尝试 ultrawork-active.json
if [ ! -f "$WORK_FILE" ]; then
  WORK_FILE="${STATE_DIR}/ultrawork-active.json"
fi
TOTAL_COUNT=$((PENDING_COUNT + WIP_COUNT + DONE_COUNT))

# 全部任务完成 (pending=0, WIP=0, completed>0) 且处于 Work 模式时
if [ "$PENDING_COUNT" -eq 0 ] && [ "$WIP_COUNT" -eq 0 ] && [ "$DONE_COUNT" -gt 0 ]; then
  if [ -f "$WORK_FILE" ]; then
    REVIEW_STATUS=$(jq -r '.review_status // "pending"' "$WORK_FILE" 2>/dev/null)

    if [ "$REVIEW_STATUS" != "passed" ]; then
      WORK_WARNING="\n\n⚠️ **work 完成前检查**: review_status=${REVIEW_STATUS}\n→ 完成处理前请先通过 /harness-review 获取 APPROVE"
    fi
  fi
fi

# 作为 additionalContext 输出同步信息
OUTPUT="[TodoSync] 与 Plans.md 同步: TODO=$PENDING_COUNT, WIP=$WIP_COUNT, done=$DONE_COUNT${WORK_WARNING}"

if command -v jq >/dev/null 2>&1; then
  jq -nc --arg ctx "$OUTPUT" \
    '{hookSpecificOutput:{additionalContext:$ctx}}'
else
  cat <<EOF
{"hookSpecificOutput":{"additionalContext":"[TodoSync] 与 Plans.md 同步: TODO=$PENDING_COUNT, WIP=$WIP_COUNT, done=$DONE_COUNT"}}
EOF
fi
