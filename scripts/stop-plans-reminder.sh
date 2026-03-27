#!/bin/bash
# stop-plans-reminder.sh
# Stop Hook 用: Plans.md 标记更新的提醒
#
# Claude Code 2.1.1 兼容: 使用 command 类型而非 prompt 类型实现
# 输出: JSON 格式 {"decision": "approve", "reason": "...", "systemMessage": "..."}

set -euo pipefail

# 判定用变量
NEED_REMINDER="false"
REASON=""
MESSAGE=""

# 检查是否有更改
HAS_CHANGES="false"

# Git 未提交更改
if [ -d ".git" ]; then
  GIT_UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo "0")
  if [ "$GIT_UNCOMMITTED" -gt 0 ]; then
    HAS_CHANGES="true"
  fi
fi

# 会话中的更改
if [ -f ".claude/state/session.json" ] && command -v jq >/dev/null 2>&1; then
  SESSION_CHANGES=$(jq '.changes_this_session // 0' .claude/state/session.json 2>/dev/null || echo "0")
  if [ "$SESSION_CHANGES" != "0" ] && [ "$SESSION_CHANGES" != "null" ]; then
    HAS_CHANGES="true"
  fi
fi

# 仅在有更改时检查 Plans.md
if [ "$HAS_CHANGES" = "true" ] && [ -f "Plans.md" ]; then
  PM_PENDING=$(( $(grep -c "pm:待处理" Plans.md 2>/dev/null || echo "0") + $(grep -c "cursor:待处理" Plans.md 2>/dev/null || echo "0") ))
  CC_WIP=$(grep -c "cc:WIP" Plans.md 2>/dev/null || echo "0")
  CC_DONE=$(grep -c "cc:已完成" Plans.md 2>/dev/null || echo "0")

  # 有来自 PM 的请求时
  if [ "$PM_PENDING" -gt 0 ]; then
    NEED_REMINDER="true"
    REASON="pm_pending_tasks > 0"
    MESSAGE="Plans.md: 有 ${PM_PENDING} 个 pm:待处理 任务。开始工作时请更新为 cc:WIP，完成时请更新为 cc:已完成"
  fi

  # 有 WIP 任务时
  if [ "$CC_WIP" -gt 0 ]; then
    NEED_REMINDER="true"
    REASON="cc_wip_tasks > 0"
    MESSAGE="Plans.md: 有 ${CC_WIP} 个 cc:WIP 任务。如果已完成，请更新为 cc:已完成"
  fi

  # 有已完成任务时（等待 PM 确认）
  if [ "$CC_DONE" -gt 0 ]; then
    NEED_REMINDER="true"
    REASON="cc_done_tasks > 0"
    MESSAGE="Plans.md: 有 ${CC_DONE} 个 cc:已完成 任务。PM 确认后请更新为 pm:已确认"
  fi
fi

# JSON 输出
if [ "$NEED_REMINDER" = "true" ]; then
  cat << EOF
{"decision": "approve", "reason": "$REASON", "systemMessage": "$MESSAGE"}
EOF
else
  cat << EOF
{"decision": "approve", "reason": "No reminder needed", "systemMessage": ""}
EOF
fi
