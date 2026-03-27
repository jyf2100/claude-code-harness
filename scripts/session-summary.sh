#!/bin/bash
# session-summary.sh
# 会话结束时生成摘要
#
# Usage: 从 Stop hook 自动执行

set +e

STATE_FILE=".claude/state/session.json"
MEMORY_DIR=".claude/memory"
SESSION_LOG_FILE="${MEMORY_DIR}/session-log.md"
EVENT_LOG_FILE=".claude/state/session.events.jsonl"
ARCHIVE_DIR=".claude/state/sessions"
CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 如果没有状态文件则跳过
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# 如果没有 jq 则跳过
if ! command -v jq &> /dev/null; then
  exit 0
fi

# 如果已记录到内存则跳过（防止 Stop hook 重复执行）
ALREADY_LOGGED=$(jq -r '.memory_logged // false' "$STATE_FILE" 2>/dev/null)
if [ "$ALREADY_LOGGED" = "true" ]; then
  exit 0
fi

# 获取会话信息
SESSION_ID=$(jq -r '.session_id // "unknown"' "$STATE_FILE")
SESSION_START=$(jq -r '.started_at' "$STATE_FILE")
PROJECT_NAME=$(jq -r '.project_name // empty' "$STATE_FILE")
GIT_BRANCH=$(jq -r '.git.branch // empty' "$STATE_FILE")
CHANGES_COUNT=$(jq '.changes_this_session | length' "$STATE_FILE")
IMPORTANT_CHANGES=$(jq '[.changes_this_session[] | select(.important == true)] | length' "$STATE_FILE")

# Git 信息
GIT_COMMITS=0
if [ -d ".git" ]; then
  # 会话开始后的提交数（估算）
  GIT_COMMITS=$(git log --oneline --since="$SESSION_START" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
fi

# Plans.md 的任务状态
COMPLETED_TASKS=0
WIP_TASK_TITLE=""
if [ -f "Plans.md" ]; then
  COMPLETED_TASKS=$(grep -c "cc:完了" Plans.md 2>/dev/null || echo "0")
  # 获取当前 WIP 任务标题（第一个）
  WIP_TASK_TITLE=$(grep -E "^\s*-\s*\[.\]\s*\*\*.*\`cc:WIP\`" Plans.md 2>/dev/null | head -1 | sed 's/.*\*\*\(.*\)\*\*.*/\1/' || true)
fi

# 从 Agent Trace 获取最近的编辑文件信息
AGENT_TRACE_FILE=".claude/state/agent-trace.jsonl"
RECENT_EDITS=""
RECENT_PROJECT=""
if [ -f "$AGENT_TRACE_FILE" ]; then
  # 从最近 10 条记录中提取编辑文件
  RECENT_EDITS=$(tail -10 "$AGENT_TRACE_FILE" 2>/dev/null | jq -r '.files[].path' 2>/dev/null | sort -u | head -5 || true)
  # 获取最新的项目信息
  RECENT_PROJECT=$(tail -1 "$AGENT_TRACE_FILE" 2>/dev/null | jq -r '.metadata.project // empty' 2>/dev/null || true)
fi

# 会话时长计算
START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$SESSION_START" "+%s" 2>/dev/null || date -d "$SESSION_START" "+%s" 2>/dev/null || echo "0")
NOW_EPOCH=$(date +%s)
DURATION_MINUTES=$(( (NOW_EPOCH - START_EPOCH) / 60 ))

# 摘要输出（仅当有变更时）
if [ "$CHANGES_COUNT" -gt 0 ] || [ "$GIT_COMMITS" -gt 0 ] || [ -n "$RECENT_EDITS" ]; then
  echo ""
  echo "📊 会话摘要"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # 项目名称（来自 Agent Trace）
  if [ -n "$RECENT_PROJECT" ]; then
    echo "📁 项目: ${RECENT_PROJECT}"
  fi

  # 当前任务（WIP）
  if [ -n "$WIP_TASK_TITLE" ]; then
    echo "🎯 当前任务: ${WIP_TASK_TITLE}"
  fi

  if [ "$COMPLETED_TASKS" -gt 0 ]; then
    echo "✅ 已完成任务: ${COMPLETED_TASKS}件"
  fi

  echo "📝 变更文件: ${CHANGES_COUNT}件"

  if [ "$IMPORTANT_CHANGES" -gt 0 ]; then
    echo "⚠️ 重要变更: ${IMPORTANT_CHANGES}件"
  fi

  if [ "$GIT_COMMITS" -gt 0 ]; then
    echo "💾 提交: ${GIT_COMMITS}件"
  fi

  if [ "$DURATION_MINUTES" -gt 0 ]; then
    echo "⏱️ 会话时长: ${DURATION_MINUTES}分钟"
  fi

  # 最近编辑的文件（来自 Agent Trace）
  if [ -n "$RECENT_EDITS" ]; then
    echo ""
    echo "📄 最近编辑:"
    echo "$RECENT_EDITS" | while read -r f; do
      [ -n "$f" ] && echo "   - $f"
    done
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

# ================================
# 自动追加到 `.claude/memory/session-log.md`（如不存在则创建）
# ================================

# 即使没有变更，有时也需要记录"已启动"的情况，
# 因此如果获取到会话开始时间，就可以写入日志（允许空会话）
if [ -n "$SESSION_START" ] && [ "$SESSION_START" != "null" ]; then
  mkdir -p "$MEMORY_DIR" 2>/dev/null || true

  if [ ! -f "$SESSION_LOG_FILE" ]; then
    cat > "$SESSION_LOG_FILE" << 'EOF'
# Session Log

会话级别的作业日志（主要用于本地操作）。
重要的决策请提升到 `.claude/memory/decisions.md`，可复用的解决方案请提升到 `.claude/memory/patterns.md`。

## Index

- （根据需要追加）

---
EOF
  fi

  # 变更文件列表（去重）
  CHANGED_FILES=$(jq -r '.changes_this_session[]?.file' "$STATE_FILE" 2>/dev/null | awk 'NF' | awk '!seen[$0]++')
  IMPORTANT_FILES=$(jq -r '.changes_this_session[]? | select(.important == true) | .file' "$STATE_FILE" 2>/dev/null | awk 'NF' | awk '!seen[$0]++')

  # WIP 任务（如存在则简要提取）
  WIP_TASKS=""
  if [ -f "Plans.md" ]; then
    WIP_TASKS=$(grep -n "cc:WIP\|pm:依赖中\|cursor:依赖中" Plans.md 2>/dev/null | head -20 || true)
  fi

  {
    echo ""
    echo "## 会话: ${CURRENT_TIME}"
    echo ""
    echo "- session_id: \`${SESSION_ID}\`"
    [ -n "$PROJECT_NAME" ] && echo "- project: \`${PROJECT_NAME}\`"
    [ -n "$GIT_BRANCH" ] && echo "- branch: \`${GIT_BRANCH}\`"
    echo "- started_at: \`${SESSION_START}\`"
    echo "- ended_at: \`${CURRENT_TIME}\`"
    [ "$DURATION_MINUTES" -gt 0 ] && echo "- duration_minutes: ${DURATION_MINUTES}"
    echo "- changes: ${CHANGES_COUNT}"
    [ "$IMPORTANT_CHANGES" -gt 0 ] && echo "- important_changes: ${IMPORTANT_CHANGES}"
    [ "$GIT_COMMITS" -gt 0 ] && echo "- commits: ${GIT_COMMITS}"
    echo ""
    echo "### 变更文件"
    if [ -n "$CHANGED_FILES" ]; then
      echo "$CHANGED_FILES" | while read -r f; do
        [ -n "$f" ] && echo "- \`$f\`"
      done
    else
      echo "- （无）"
    fi
    echo ""
    echo "### 重要变更（important=true）"
    if [ -n "$IMPORTANT_FILES" ]; then
      echo "$IMPORTANT_FILES" | while read -r f; do
        [ -n "$f" ] && echo "- \`$f\`"
      done
    else
      echo "- （无）"
    fi
    echo ""
    echo "### 下次交接（可选）"
    if [ -n "$WIP_TASKS" ]; then
      echo ""
      echo "**Plans.md 的 WIP/依赖中（摘录）**:"
      echo ""
      echo '```'
      echo "$WIP_TASKS"
      echo '```'
    else
      echo "- （根据需要追加）"
    fi
    echo ""
    echo "---"
  } >> "$SESSION_LOG_FILE" 2>/dev/null || true
fi

# 在状态文件中记录会话结束时间和已记录标志
append_event() {
  local event_type="$1"
  local event_state="$2"
  local event_time="$3"

  # 初始化事件日志
  mkdir -p ".claude/state" 2>/dev/null || true
  touch "$EVENT_LOG_FILE" 2>/dev/null || true

  if command -v jq >/dev/null 2>&1; then
    local seq
    local event_id
    seq=$(jq -r '.event_seq // 0' "$STATE_FILE" 2>/dev/null)
    seq=$((seq + 1))
    event_id=$(printf "event-%06d" "$seq")

    jq --arg state "$event_state" \
       --arg updated_at "$event_time" \
       --arg event_id "$event_id" \
       --argjson event_seq "$seq" \
       '.state = $state | .updated_at = $updated_at | .last_event_id = $event_id | .event_seq = $event_seq' \
       "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

    echo "{\"id\":\"$event_id\",\"type\":\"$event_type\",\"ts\":\"$event_time\",\"state\":\"$event_state\"}" >> "$EVENT_LOG_FILE"
  fi
}

append_event "session.stop" "stopped" "$CURRENT_TIME"

if command -v jq >/dev/null 2>&1; then
  jq --arg ended_at "$CURRENT_TIME" \
     --arg duration "$DURATION_MINUTES" \
     '. + {ended_at: $ended_at, duration_minutes: ($duration | tonumber), memory_logged: true}' \
     "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
fi

# 归档保存（用于 resume/fork）
if [ -f "$STATE_FILE" ]; then
  mkdir -p "$ARCHIVE_DIR" 2>/dev/null || true
  if command -v jq >/dev/null 2>&1; then
    ARCHIVE_ID=$(jq -r '.session_id // empty' "$STATE_FILE" 2>/dev/null)
    if [ -n "$ARCHIVE_ID" ]; then
      cp "$STATE_FILE" "$ARCHIVE_DIR/${ARCHIVE_ID}.json" 2>/dev/null || true
      if [ -f "$EVENT_LOG_FILE" ]; then
        cp "$EVENT_LOG_FILE" "$ARCHIVE_DIR/${ARCHIVE_ID}.events.jsonl" 2>/dev/null || true
      fi
    fi
  fi
fi

exit 0
