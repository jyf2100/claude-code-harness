#!/bin/bash
# pretooluse-browser-guide.sh
# 当使用 MCP 浏览器工具时推荐 agent-browser 的钩子
#
# 目标工具:
#   - mcp__chrome-devtools__*
#   - mcp__playwright__* / mcp__plugin_playwright__*
#
# 行为:
#   - 如果已安装 agent-browser，推荐使用
#   - 不进行阻止（仅提供信息）
#
# Input: stdin JSON from Claude Code hooks (已通过 matcher 过滤)
# Output: JSON with hookSpecificOutput format

set -euo pipefail

# 从 stdin 读取 JSON
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

# 如果没有输入则不做任何处理
[ -z "$INPUT" ] && exit 0

# 确认 agent-browser 是否已安装
if command -v agent-browser &> /dev/null; then
  # 输出推荐消息（hookSpecificOutput 格式）
  # 已通过 matcher 过滤到 MCP 浏览器工具，无需额外的工具名检查
  if command -v jq >/dev/null 2>&1; then
    CONTEXT="💡 **建议先尝试使用 agent-browser**

agent-browser 是专为 AI 代理优化的浏览器自动化工具。

\`\`\`bash
# 基本用法
agent-browser open <url>
agent-browser snapshot -i -c  # AI 专用快照
agent-browser click @e1        # 通过元素引用点击
\`\`\`

当前的 MCP 工具也可使用，但 agent-browser 更简单且更快速。

详情: \`docs/OPTIONAL_PLUGINS.md\`"

    jq -nc --arg ctx "$CONTEXT" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext: $ctx
      }
    }'
  else
    # 如果没有 jq 则尝试使用 Python
    if command -v python3 >/dev/null 2>&1; then
      python3 - <<'PY'
import json
context = """💡 **建议先尝试使用 agent-browser**

agent-browser 是专为 AI 代理优化的浏览器自动化工具。

```bash
# 基本用法
agent-browser open <url>
agent-browser snapshot -i -c  # AI 专用快照
agent-browser click @e1        # 通过元素引用点击
```

当前的 MCP 工具也可使用，但 agent-browser 更简单且更快速。

详情: `docs/OPTIONAL_PLUGINS.md`"""
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "additionalContext": context
    }
}))
PY
    fi
  fi
fi

# agent-browser 未安装或输出完成后正常退出
exit 0
