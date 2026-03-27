#!/bin/bash
# stop-cleanup-check.sh
# Stop Hook 用：在会话结束时判断是否建议清理
#
# Claude Code 2.1.1 兼容：使用 command 类型而非 prompt 类型实现
# 输出：JSON 格式 {"decision": "approve", "reason": "...", "systemMessage": "..."}

set -euo pipefail

# 判断用变量
RECOMMEND_CLEANUP="false"
REASON=""
MESSAGE=""

# 分析 Plans.md
if [ -f "Plans.md" ]; then
  PLANS_LINES=$(wc -l < "Plans.md" | tr -d ' ')
  COMPLETED_TASKS=$(grep -c "\[x\].*cc:完了\|pm:確認済\|cursor:確認済" Plans.md 2>/dev/null || echo "0")

  # 判断条件1：已完成任务超过10件
  if [ "$COMPLETED_TASKS" -ge 10 ]; then
    RECOMMEND_CLEANUP="true"
    REASON="completed_tasks >= 10"
    MESSAGE="建议整理：已完成任务有 ${COMPLETED_TASKS} 件（输入「整理」启动 maintenance 技能）"
  fi

  # 判断条件2：Plans.md 超过200行
  if [ "$PLANS_LINES" -gt 200 ]; then
    RECOMMEND_CLEANUP="true"
    REASON="Plans.md > 200 lines"
    MESSAGE="建议整理：Plans.md 已膨胀至 ${PLANS_LINES} 行（输入「整理」启动 maintenance 技能）"
  fi
fi

# 判断条件3：session-log.md 超过500行
if [ -f ".claude/memory/session-log.md" ]; then
  SESSION_LOG_LINES=$(wc -l < ".claude/memory/session-log.md" | tr -d ' ')
  if [ "$SESSION_LOG_LINES" -gt 500 ]; then
    RECOMMEND_CLEANUP="true"
    REASON="session-log.md > 500 lines"
    MESSAGE="建议整理：session-log.md 已膨胀至 ${SESSION_LOG_LINES} 行（输入「整理」启动 maintenance 技能）"
  fi
fi

# 判断条件4：CLAUDE.md 超过100行
if [ -f "CLAUDE.md" ]; then
  CLAUDE_MD_LINES=$(wc -l < "CLAUDE.md" | tr -d ' ')
  if [ "$CLAUDE_MD_LINES" -gt 100 ]; then
    RECOMMEND_CLEANUP="true"
    REASON="CLAUDE.md > 100 lines"
    MESSAGE="建议整理：CLAUDE.md 有 ${CLAUDE_MD_LINES} 行（建议拆分到 .claude/rules/）"
  fi
fi

# JSON 输出
if [ "$RECOMMEND_CLEANUP" = "true" ]; then
  cat << EOF
{"decision": "approve", "reason": "$REASON", "systemMessage": "$MESSAGE"}
EOF
else
  cat << EOF
{"decision": "approve", "reason": "No cleanup needed", "systemMessage": ""}
EOF
fi
