#!/bin/bash
# plans-format-check.sh
# 检查 Plans.md 的格式，若存在旧格式则发出警告并建议迁移

set -uo pipefail

PLANS_FILE="${1:-Plans.md}"

# JSON 输出函数
output_json() {
  local status="$1"
  local message="$2"
  local migration_needed="${3:-false}"
  local issues="${4:-[]}"

  cat <<EOF
{
  "status": "$status",
  "message": "$message",
  "migration_needed": $migration_needed,
  "issues": $issues,
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "$message"
  }
}
EOF
}

# Plans.md 不存在时
if [ ! -f "$PLANS_FILE" ]; then
  output_json "skip" "未找到 Plans.md" "false"
  exit 0
fi

# 格式检查
ISSUES=()
MIGRATION_NEEDED=false

# 1. 检查已废弃的标记（cursor:WIP, cursor:完了）
if grep -qE 'cursor:(WIP|完了)' "$PLANS_FILE" 2>/dev/null; then
  MIGRATION_NEEDED=true
  ISSUES+=("\"cursor:WIP 和 cursor:完了 已废弃。请迁移至 pm:依頼中 / pm:確認済。\"")
fi

# 2. 检查标记说明章节
if ! grep -qE '## マーカー凡例|## Marker Legend' "$PLANS_FILE" 2>/dev/null; then
  ISSUES+=("\"缺少标记说明章节。建议从模板中添加。\"")
fi

# 3. 检查有效的 Harness 标记是否存在
# 新格式: cc:TODO, cc:WIP, cc:WORK, cc:DONE, cc:完了, cc:blocked, pm:依頼中, pm:確認済, cursor:依頼中, cursor:確認済
if ! grep -qE 'cc:(TODO|WIP|WORK|DONE|完了|blocked)|pm:(依頼中|確認済)|cursor:(依頼中|確認済)' "$PLANS_FILE" 2>/dev/null; then
  # 也检查旧格式（cursor:WIP/完了）
  if ! grep -qE 'cursor:(WIP|完了)' "$PLANS_FILE" 2>/dev/null; then
    ISSUES+=("\"未找到 Harness 标记（cc:TODO, cc:WIP 等）。\"")
  fi
fi

# 输出结果
if [ ${#ISSUES[@]} -eq 0 ]; then
  output_json "ok" "Plans.md 格式已是最新" "false"
else
  ISSUES_JSON=$(printf '%s,' "${ISSUES[@]}" | sed 's/,$//')
  if [ "$MIGRATION_NEEDED" = true ]; then
    output_json "migration_required" "Plans.md 中检测到旧格式。可通过 /harness-update 进行迁移。" "true" "[$ISSUES_JSON]"
  else
    output_json "warning" "Plans.md 存在可改进之处" "false" "[$ISSUES_JSON]"
  fi
fi
