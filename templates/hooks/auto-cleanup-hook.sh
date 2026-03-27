#!/bin/bash
# auto-cleanup-hook.sh
# PostToolUse Hook: 写入 Plans.md 等文件后自动进行大小检查
#
# 环境变量:
#   $CLAUDE_FILE_PATHS - 已更改的文件路径（空格分隔）
#
# 设置:
#   可在 .claude-code-harness.config.yaml 中自定义阈值

# 默认阈值
PLANS_MAX_LINES=${PLANS_MAX_LINES:-200}
SESSION_LOG_MAX_LINES=${SESSION_LOG_MAX_LINES:-500}
CLAUDE_MD_MAX_LINES=${CLAUDE_MD_MAX_LINES:-100}

# 如果存在配置文件则加载
CONFIG_FILE=".claude-code-harness.config.yaml"
if [ -f "$CONFIG_FILE" ]; then
  # 简易 YAML 解析
  PLANS_MAX_LINES=$(grep -A5 "plans:" "$CONFIG_FILE" | grep "max_lines:" | head -1 | awk '{print $2}' || echo $PLANS_MAX_LINES)
  SESSION_LOG_MAX_LINES=$(grep -A5 "session_log:" "$CONFIG_FILE" | grep "max_lines:" | head -1 | awk '{print $2}' || echo $SESSION_LOG_MAX_LINES)
  CLAUDE_MD_MAX_LINES=$(grep -A5 "claude_md:" "$CONFIG_FILE" | grep "max_lines:" | head -1 | awk '{print $2}' || echo $CLAUDE_MD_MAX_LINES)
fi

# 用于存储反馈的变量
FEEDBACK=""

# 检查每个文件
for file in $CLAUDE_FILE_PATHS; do
  # Plans.md 的检查
  if [[ "$file" == *"Plans.md"* ]] || [[ "$file" == *"plans.md"* ]] || [[ "$file" == *"PLANS.MD"* ]]; then
    if [ -f "$file" ]; then
      lines=$(wc -l < "$file" | tr -d ' ')
      if [ "$lines" -gt "$PLANS_MAX_LINES" ]; then
        FEEDBACK="${FEEDBACK}Plans.md 已达 ${lines} 行（上限: ${PLANS_MAX_LINES}行）。建议使用 \`/maintenance\` 归档旧任务。\n"
      fi
    fi
  fi

  # session-log.md 的检查
  if [[ "$file" == *"session-log.md"* ]]; then
    if [ -f "$file" ]; then
      lines=$(wc -l < "$file" | tr -d ' ')
      if [ "$lines" -gt "$SESSION_LOG_MAX_LINES" ]; then
        FEEDBACK="${FEEDBACK}session-log.md 已达 ${lines} 行（上限: ${SESSION_LOG_MAX_LINES}行）。建议使用 \`/maintenance\` 按月分割。\n"
      fi
    fi
  fi

  # CLAUDE.md 的检查
  if [[ "$file" == *"CLAUDE.md"* ]] || [[ "$file" == *"claude.md"* ]]; then
    if [ -f "$file" ]; then
      lines=$(wc -l < "$file" | tr -d ' ')
      if [ "$lines" -gt "$CLAUDE_MD_MAX_LINES" ]; then
        FEEDBACK="${FEEDBACK}CLAUDE.md 已达 ${lines} 行。请考虑将非常用信息分割到 docs/，并使用 \`@docs/filename.md\` 引用。\n"
      fi
    fi
  fi
done

# 如有反馈则输出（向 Claude Code 的反馈）
if [ -n "$FEEDBACK" ]; then
  echo -e "⚠️ 文件大小警告:\n${FEEDBACK}"
fi

# 始终以成功退出（不阻塞）
exit 0
