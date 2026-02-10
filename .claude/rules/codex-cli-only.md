# Codex CLI Only Rule

Codex の呼び出しには **必ず `codex exec` (Bash)** を使用すること。

## 禁止事項

- `mcp__codex__codex` の使用（MCP サーバーは廃止済み）
- ToolSearch で Codex MCP を検索する行為
- `claude mcp add codex` による MCP サーバー再登録

## 正しい呼び出し方

```bash
# 基本
$TIMEOUT 120 codex exec "$(cat /tmp/codex-prompt.md)" 2>/dev/null

# 並列実行
$TIMEOUT 120 codex exec "$(cat /tmp/prompt1.md)" > /tmp/out1.txt 2>/dev/null &
$TIMEOUT 120 codex exec "$(cat /tmp/prompt2.md)" > /tmp/out2.txt 2>/dev/null &
wait
```

## timeout の取得

```bash
TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")
```

macOS では `brew install coreutils` で `gtimeout` をインストール。
