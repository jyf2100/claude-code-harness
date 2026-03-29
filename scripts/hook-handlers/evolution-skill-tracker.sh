#!/usr/bin/env bash
# scripts/hook-handlers/evolution-skill-tracker.sh
# PostToolUse hook: 记录技能使用指标到 SQLite
#
# 用法: 作为 PostToolUse hook，在 Skill 工具调用后触发
# 读取 stdin JSON，提取技能信息，写入 skill_usage_metrics 表

set -euo pipefail

# ============================================================
# 配置
# ============================================================

STATE_DB="${PROJECT_ROOT:-$(pwd)}/.harness/state.db"
TIMEOUT_CMD=$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || echo "")

# ============================================================
# 读取 stdin JSON
# ============================================================

INPUT=$(cat)
if [[ -z "$INPUT" ]]; then
  exit 0
fi

# 提取字段
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

# 仅跟踪 Skill 工具调用
if [[ "$TOOL_NAME" != "Skill" ]]; then
  exit 0
fi

# 提取技能名
SKILL_NAME=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null || echo "")
if [[ -z "$SKILL_NAME" ]]; then
  exit 0
fi

# 提取工具结果中的成功/失败
TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // empty' 2>/dev/null || echo "")
SUCCESS=1
ERROR_MSG=""

if [[ "$TOOL_OUTPUT" == *"error"* ]] || [[ "$TOOL_OUTPUT" == *"Error"* ]]; then
  SUCCESS=0
  ERROR_MSG=$(echo "$TOOL_OUTPUT" | head -c 500)
fi

# ============================================================
# 写入 SQLite
# ============================================================

if [[ ! -f "$STATE_DB" ]]; then
  # 数据库不存在，跳过（进化引擎尚未初始化）
  exit 0
fi

NOW=$(date +%s)

sqlite3 "$STATE_DB" "
  INSERT INTO skill_usage_metrics(
    session_id, skill_name, skill_version, invocation_type,
    tool_name, success, error_message, recorded_at, context_json
  ) VALUES (
    '$(echo "$SESSION_ID" | sed "s/'/''/g")',
    '$(echo "$SKILL_NAME" | sed "s/'/''/g")',
    'unknown',
    'skill',
    'Skill',
    $SUCCESS,
    $(if [[ -n "$ERROR_MSG" ]]; then echo "'$(echo "$ERROR_MSG" | sed "s/'/''/g")'"; else echo "NULL"; fi),
    $NOW,
    '{}'
  );
" 2>/dev/null || true

exit 0
