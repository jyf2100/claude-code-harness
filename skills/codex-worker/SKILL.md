---
name: codex-worker
description: "Codex を実装ワーカーとして使用。ルーティングルールは skills/routing-rules.md を参照。"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Task"]
argument-hint: "[task description]"
---

# Codex Worker Skill

Claude Code を PM/Orchestrator として、Codex を Worker として実装を委譲するスキル。

## Philosophy

> **「Claude Code = 設計・レビュー、Codex = 実装」**
>
> 高レベルな判断は Claude Code、実装の細部は Codex に任せる分業体制。

## Routing Rules (SSOT)

> **このスキルのトリガー/除外ルールは [skills/routing-rules.md](../routing-rules.md) で一元管理されています。**
>
> ローカルにルールを重複記載しないこと。変更が必要な場合は routing-rules.md を編集してください。

## Feature Details

| Feature | Reference |
|---------|-----------|
| **Setup** | See [references/setup.md](references/setup.md) |
| **Worker Execution** | See [references/worker-execution.md](references/worker-execution.md) |
| **Task Ownership** | See [references/task-ownership.md](references/task-ownership.md) |
| **Parallel Strategy** | See [references/parallel-strategy.md](references/parallel-strategy.md) |
| **Quality Gates** | See [references/quality-gates.md](references/quality-gates.md) |
| **Review & Integration** | See [references/review-integration.md](references/review-integration.md) |

## Execution Flow

```
1. タスク受信
    ↓
2. base-instructions 生成
   - Rules 連結
   - AGENTS.md 強制読み込み指示
    ↓
3. git worktree 準備（並列時）
    ↓
4. mcp__codex__codex 呼び出し
   - prompt: タスク内容 + AGENTS_SUMMARY 証跡出力指示
   - cwd: worktree パス
   - approval-policy: never
   - sandbox: workspace-write
    ↓
5. 結果検証
   - AGENTS_SUMMARY 証跡確認
   - 不合格時: 合計3回試行
    ↓
6. Orchestrator レビュー
   - 品質ゲート（lint, test, 改ざん検出）
   - 修正指示 → 再実行ループ
    ↓
7. マージ・Plans.md 更新
```

## MCP Parameters (D20)

```json
{
  "prompt": "タスク内容 + AGENTS_SUMMARY 証跡出力指示",
  "base-instructions": "Rules 連結 + AGENTS.md 強制読み込み指示",
  "cwd": "/path/to/worktree",
  "approval-policy": "never",
  "sandbox": "workspace-write"
}
```

## AGENTS.md Compliance

Worker は実行開始時に以下を出力する必要がある:

```
AGENTS_SUMMARY: <1行要約> | HASH:<SHA256先頭8文字>
```

- 入力: AGENTS.md ファイル内容（BOM除去、全行LF正規化）
- アルゴリズム: SHA256、Hex小文字、先頭8文字
- 欠落時: 即失敗 → 手動対応

## Related Skills

- `codex-review` - Codex によるレビュー・セカンドオピニオン
- `ultrawork` - `--codex` モードで Worker 並列実行
- `impl` - Claude Code 自身による実装
