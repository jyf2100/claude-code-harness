#!/bin/bash
# plans-watcher.sh - 监视 Plans.md 的变更并生成 PM 通知（兼容: cursor:*）
# 从 PostToolUse 钩子调用

set +e  # 遇错不停止

# 获取变更文件（优先 stdin JSON / 兼容: $1,$2）
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

CHANGED_FILE="${1:-}"
TOOL_NAME="${2:-}"
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

  [ -z "$CHANGED_FILE" ] && CHANGED_FILE="${FILE_PATH_FROM_STDIN:-}"
  [ -z "$TOOL_NAME" ] && TOOL_NAME="${TOOL_NAME_FROM_STDIN:-}"
  CWD="${CWD_FROM_STDIN:-}"
fi

# 尽可能转换为项目相对路径
if [ -n "$CWD" ] && [ -n "$CHANGED_FILE" ] && [[ "$CHANGED_FILE" == "$CWD/"* ]]; then
  CHANGED_FILE="${CHANGED_FILE#$CWD/}"
fi

# Plans.md 路径（考虑 plansDirectory 设置）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/config-utils.sh" ]; then
  source "${SCRIPT_DIR}/config-utils.sh"
  PLANS_FILE=$(get_plans_file_path)
  plans_file_exists || PLANS_FILE=""
else
  # 后备: 传统搜索逻辑
  find_plans_file() {
      for f in Plans.md plans.md PLANS.md PLANS.MD; do
          if [ -f "$f" ]; then
              echo "$f"
              return 0
          fi
      done
      return 1
  }
  PLANS_FILE=$(find_plans_file)
fi

# 跳过 Plans.md 以外的变更
if [ -z "$PLANS_FILE" ]; then
    exit 0
fi

case "$CHANGED_FILE" in
    "$PLANS_FILE"|*/"$PLANS_FILE") ;;
    *) exit 0 ;;
esac

# 状态目录
STATE_DIR=".claude/state"
mkdir -p "$STATE_DIR"

# 获取上次状态
PREV_STATE_FILE="${STATE_DIR}/plans-state.json"

# 统计标记数量
count_markers() {
    local marker=$1
    local count=0
    if [ -f "$PLANS_FILE" ]; then
        count=$(grep -c "$marker" "$PLANS_FILE" 2>/dev/null || true)
        [ -z "$count" ] && count=0
    fi
    echo "$count"
}

# 获取当前状态（pm:* 为标准，cursor:* 为兼容同义词）
PM_PENDING=$(( $(count_markers "pm:依頼中") + $(count_markers "cursor:依頼中") ))
CC_TODO=$(count_markers "cc:TODO")
CC_WIP=$(count_markers "cc:WIP")
CC_DONE=$(count_markers "cc:完了")
PM_CONFIRMED=$(( $(count_markers "pm:確認済") + $(count_markers "cursor:確認済") ))

# 检测新任务
NEW_TASKS=""
if [ -f "$PREV_STATE_FILE" ]; then
    PREV_PM_PENDING=$(jq -r '.pm_pending // 0' "$PREV_STATE_FILE" 2>/dev/null || echo "0")
    if [ "$PM_PENDING" -gt "$PREV_PM_PENDING" ] 2>/dev/null; then
        NEW_TASKS="pm:依頼中"
    fi
fi

# 检测完成任务
COMPLETED_TASKS=""
if [ -f "$PREV_STATE_FILE" ]; then
    PREV_CC_DONE=$(jq -r '.cc_done // 0' "$PREV_STATE_FILE" 2>/dev/null || echo "0")
    if [ "$CC_DONE" -gt "$PREV_CC_DONE" ] 2>/dev/null; then
        COMPLETED_TASKS="cc:完了"
    fi
fi

# 保存状态
cat > "$PREV_STATE_FILE" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "pm_pending": $PM_PENDING,
  "cc_todo": $CC_TODO,
  "cc_wip": $CC_WIP,
  "cc_done": $CC_DONE,
  "pm_confirmed": $PM_CONFIRMED
}
EOF

# 生成通知
generate_notification() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Plans.md 更新检测"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ -n "$NEW_TASKS" ]; then
        echo "🆕 新任务: 收到 PM 的请求"
        echo "   → 请用 /sync-status 确认情况，并用 /work 开始处理"
    fi

    if [ -n "$COMPLETED_TASKS" ]; then
        echo "✅ 任务完成: 可向 PM 报告"
        echo "   → 请用 /handoff-to-pm-claude（或 /handoff-to-cursor）报告"
    fi

    echo ""
    echo "📊 当前状态:"
    echo "   pm:依頼中      : $PM_PENDING 件（兼容: cursor:依頼中）"
    echo "   cc:TODO        : $CC_TODO 件"
    echo "   cc:WIP         : $CC_WIP 件"
    echo "   cc:完了        : $CC_DONE 件"
    echo "   pm:確認済      : $PM_CONFIRMED 件（兼容: cursor:確認済）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 仅在有变更时通知
if [ -n "$NEW_TASKS" ] || [ -n "$COMPLETED_TASKS" ]; then
    generate_notification
fi

# 生成 PM 通知文件（用于双角色协作）
if [ -n "$NEW_TASKS" ] || [ -n "$COMPLETED_TASKS" ]; then
    PM_NOTIFICATION_FILE="${STATE_DIR}/pm-notification.md"
    CURSOR_NOTIFICATION_FILE="${STATE_DIR}/cursor-notification.md" # 兼容
    cat > "$PM_NOTIFICATION_FILE" << EOF
# 给 PM 的通知

**生成时间**: $(date +"%Y-%m-%d %H:%M:%S")

## 状态变更

EOF

    if [ -n "$NEW_TASKS" ]; then
        echo "### 🆕 新任务" >> "$PM_NOTIFICATION_FILE"
        echo "" >> "$PM_NOTIFICATION_FILE"
        echo "PM 请求了新任务（pm:依頼中 / 兼容: cursor:依頼中）。" >> "$PM_NOTIFICATION_FILE"
        echo "" >> "$PM_NOTIFICATION_FILE"
    fi

    if [ -n "$COMPLETED_TASKS" ]; then
        echo "### ✅ 完成任务" >> "$PM_NOTIFICATION_FILE"
        echo "" >> "$PM_NOTIFICATION_FILE"
        echo "Impl Claude 已完成任务。请进行审查（cc:完了）。" >> "$PM_NOTIFICATION_FILE"
        echo "" >> "$PM_NOTIFICATION_FILE"
    fi

    echo "---" >> "$PM_NOTIFICATION_FILE"
    echo "" >> "$PM_NOTIFICATION_FILE"
    echo "**下一步**: 在 PM Claude 中审查，如需要可重新请求（/handoff-to-impl-claude）。" >> "$PM_NOTIFICATION_FILE"

    # 兼容: 旧文件名也输出相同内容
    cp -f "$PM_NOTIFICATION_FILE" "$CURSOR_NOTIFICATION_FILE" 2>/dev/null || true
fi
