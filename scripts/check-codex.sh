#!/bin/bash
# check-codex.sh - Codex 可用性检查（用于 once hook）
# 在 /harness-review 首次执行时运行一次
#
# Usage: ./scripts/check-codex.sh

set -euo pipefail

# 项目配置文件路径
CONFIG_FILE=".claude-code-harness.config.yaml"

# 检查是否已设置 codex.enabled
if [[ -f "$CONFIG_FILE" ]]; then
    if grep -q "codex:" "$CONFIG_FILE" 2>/dev/null; then
        # 已设置则不做任何操作
        exit 0
    fi
fi

# 检查 Codex CLI 是否已安装
if ! command -v codex &> /dev/null; then
    # 没有 Codex 则不做任何操作
    exit 0
fi

# 获取 Codex 版本
CODEX_VERSION=$(codex --version 2>/dev/null | head -1 || echo "unknown")

# 从 npm 获取最新版本（超时 3 秒）
LATEST_VERSION=$(npm show @openai/codex version 2>/dev/null || echo "unknown")

# 版本比较函数
version_lt() {
    [ "$1" != "$2" ] && [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}

# 检测到 Codex 时通知用户
cat << EOF

🤖 检测到 Codex

**已安装版本**: ${CODEX_VERSION}
**最新版本**: ${LATEST_VERSION}
EOF

# 版本过旧时发出警告
if [[ "$LATEST_VERSION" != "unknown" && "$CODEX_VERSION" != "unknown" ]]; then
    # 从版本字符串中提取数字部分
    CURRENT_NUM=$(echo "$CODEX_VERSION" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0")
    LATEST_NUM=$(echo "$LATEST_VERSION" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0")

    if version_lt "$CURRENT_NUM" "$LATEST_NUM"; then
        cat << EOF

⚠️ **Codex CLI 版本过旧**

更新方法:
\`\`\`bash
npm update -g @openai/codex
\`\`\`

或请求 Claude "帮我更新 Codex"。

EOF
    fi
fi

# timeout / gtimeout 检查（macOS 兼容性）
TIMEOUT_CMD=""
if command -v timeout &> /dev/null; then
    TIMEOUT_CMD="timeout"
elif command -v gtimeout &> /dev/null; then
    TIMEOUT_CMD="gtimeout"
fi

if [[ -z "$TIMEOUT_CMD" ]]; then
    cat << 'EOF'

⚠️ **未找到 timeout 命令**

Codex CLI 并行审查使用 `timeout` 命令进行超时控制。
macOS 默认不包含此命令，请通过以下方式安装:

```bash
brew install coreutils
```

安装后可使用 `gtimeout`，Harness 将自动检测。
未安装时 Codex 仍可工作，但无法进行超时控制。

EOF
else
    echo ""
    echo "**超时命令**: \`${TIMEOUT_CMD}\` ✅"
fi

cat << 'EOF'

启用第二意见审查:

```yaml
# .claude-code-harness.config.yaml
review:
  codex:
    enabled: true
    model: gpt-5.2-codex  # 推荐模型
```

或使用 `/codex-review` 单独执行 Codex 审查

详情: skills/codex-review/SKILL.md

EOF

exit 0
