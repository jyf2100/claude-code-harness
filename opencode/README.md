# Harness for OpenCode

Claude Code Harness の opencode.ai 互換版です。

## セットアップ

### 1. コマンドをプロジェクトにコピー

```bash
# Harness をクローン
git clone https://github.com/Chachamaru127/claude-code-harness.git

# opencode 用コマンドをコピー
cp -r claude-code-harness/opencode/commands/ your-project/.opencode/commands/
cp claude-code-harness/opencode/AGENTS.md your-project/AGENTS.md
```

### 2. MCP サーバーをセットアップ（オプション）

```bash
# MCP サーバーをビルド
cd claude-code-harness/mcp-server
npm install
npm run build

# opencode.json をプロジェクトにコピーしてパスを調整
cp claude-code-harness/opencode/opencode.json your-project/
# opencode.json 内のパスを実際のパスに変更
```

### 3. 利用開始

```bash
cd your-project
opencode
```

## 利用可能なコマンド

| コマンド | 説明 |
|----------|------|
| `/harness-init` | プロジェクトセットアップ |
| `/plan-with-agent` | 開発プラン作成 |
| `/work` | タスク実行 |
| `/harness-review` | コードレビュー |

## MCP ツール

MCP サーバー経由で以下のツールが利用可能です：

| ツール | 説明 |
|--------|------|
| `harness_workflow_plan` | プラン作成 |
| `harness_workflow_work` | タスク実行 |
| `harness_workflow_review` | コードレビュー |
| `harness_session_broadcast` | セッション間通知 |
| `harness_status` | 状態確認 |

## 制限事項

- Harness プラグインシステム（`.claude-plugin/`）は opencode では使用できません
- フックは opencode 側で別途設定が必要です

## 関連リンク

- [Claude Code Harness](https://github.com/Chachamaru127/claude-code-harness)
- [OpenCode Documentation](https://opencode.ai/docs/)
