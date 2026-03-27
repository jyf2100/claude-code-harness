# Codex CLI Only Rule

调用 Codex 时 **必须使用 `codex exec` (Bash)**。

## 禁止事项

- 使用 `mcp__codex__codex`（MCP 服务器已废弃）
- 使用 ToolSearch 搜索 Codex MCP 的行为
- 通过 `claude mcp add codex` 重新注册 MCP 服务器

## 推荐阻止方法（v2.1.78+）

通过 settings.json 的 `deny` 规则直接阻止 MCP 工具是最干净的方法:

```json
{
  "permissions": {
    "deny": ["mcp__codex__*"]
  }
}
```

v2.1.77 起，PreToolUse 钩子的 `allow` 响应无法覆盖 settings.json 的 `deny`，
因此 `deny` 规则是最可靠的阻止手段。Harness 的 `.claude-plugin/settings.json` 已配置。

## 正确的调用方式

```bash
# 基本（stdin 方式 + 唯一临时文件）
CODEX_PROMPT=$(mktemp /tmp/codex-prompt-XXXXXX.md)
# 写出任务内容
cat "$CODEX_PROMPT" | ${TIMEOUT:+$TIMEOUT 120} codex exec - --sandbox workspace-write --full-auto 2>>/tmp/harness-codex-$$.log
rm -f "$CODEX_PROMPT"

# 并行执行
PROMPT1=$(mktemp /tmp/codex-prompt-XXXXXX.md)
PROMPT2=$(mktemp /tmp/codex-prompt-XXXXXX.md)
cat "$PROMPT1" | ${TIMEOUT:+$TIMEOUT 120} codex exec - --sandbox workspace-write --full-auto > /tmp/out1-$$.txt 2>>/tmp/harness-codex-$$.log &
cat "$PROMPT2" | ${TIMEOUT:+$TIMEOUT 120} codex exec - --sandbox workspace-write --full-auto > /tmp/out2-$$.txt 2>>/tmp/harness-codex-$$.log &
wait
rm -f "$PROMPT1" "$PROMPT2"
```

## 获取 timeout

```bash
TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")
```

在 macOS 上通过 `brew install coreutils` 安装 `gtimeout`。
