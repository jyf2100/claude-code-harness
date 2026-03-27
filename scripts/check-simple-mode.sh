#!/bin/bash
# check-simple-mode.sh
# CLAUDE_CODE_SIMPLE 模式检测工具
#
# Usage:
#   source scripts/check-simple-mode.sh
#   if is_simple_mode; then echo "SIMPLE mode"; fi
#
# Environment:
#   CLAUDE_CODE_SIMPLE=1  → skills/memory/agents 将被禁用 (CC v2.1.50+)
#
# Returns:
#   0 (true)  如果 SIMPLE 模式已激活
#   1 (false) 如果是普通模式

# SIMPLE 模式判定
# 当 CLAUDE_CODE_SIMPLE=1 时，Claude Code 会剥离 skills/memory/agents
is_simple_mode() {
  [ "${CLAUDE_CODE_SIMPLE:-0}" = "1" ]
}

# 生成 SIMPLE 模式警告消息（中文/英文）
# 参数: $1 = lang (zh|en)
# 输出: 警告消息字符串
simple_mode_warning() {
  local lang="${1:-zh}"

  if [ "$lang" = "en" ]; then
    cat <<'MSG'
WARNING: CLAUDE_CODE_SIMPLE mode detected (CC v2.1.50+)
- Skills DISABLED: /work, /breezing, /plan-with-agent, /harness-review unavailable
- Agents DISABLED: task-worker, code-reviewer, parallel execution unavailable
- Memory DISABLED: project memory and cross-session learning unavailable
- Hooks ACTIVE: safety guards and session management continue to operate
→ See docs/SIMPLE_MODE_COMPATIBILITY.md for details
MSG
  else
    cat <<'MSG'
警告: 检测到 CLAUDE_CODE_SIMPLE 模式 (CC v2.1.50+)
- 技能已禁用: /work, /breezing, /plan-with-agent, /harness-review 不可用
- 代理已禁用: task-worker, code-reviewer, 并行执行不可用
- 内存已禁用: 项目内存和跨会话学习不可用
- 钩子已启用: 安全防护和会话管理继续运行
→ 详情请参阅 docs/SIMPLE_MODE_COMPATIBILITY.md
MSG
  fi
}
