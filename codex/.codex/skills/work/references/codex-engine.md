# Codex Engine

`/work` は Codex 実行時に **Codex が既定で実装を担当** する。
`--claude` を付けたときだけ Claude CLI に実装を委譲する。

互換性: `--codex` は legacy alias として受理し、既定動作（Codex 実装）から変更しない。

## Overview

```text
/work [scope]
    ├─ デフォルト: Codex が直接実装 + レビュー
    └─ --claude: Codex は PM、Claude CLI が実装
```

```text
/work --claude [scope]
    │
    ├─ Codex (PM): タスク分析・分割・レビュー
    └─ Claude CLI: 実装ワーカーとして実行
```

## Mode Matrix

| 項目 | デフォルト (`/work`) | `--claude` |
|------|----------------------|------------|
| 実装主体 | Codex | Claude CLI |
| Codex の役割 | 調整 + 実装 | PM（調整のみ） |
| `codex exec` の自己呼び出し | **禁止** | 不使用 |
| 委譲CLI | なし | `claude -p` |
| 品質保証 | セルフレビュー + Quality Gates | AGENTS_SUMMARY + Quality Gates |

## Codex 実装（デフォルト）

### 原則

- Codex 実行中は、Codex が Read/Write/Edit/Bash で直接実装する。
- **Codex から `codex exec` を呼ぶ再帰実行は禁止**（自己委譲ループ防止）。
- 複数タスク時は内部並列戦略（ワーカー分割）で処理する。

## Claude 委譲（`--claude`）

`--claude` 指定時のみ、Codex は PM モードで Claude CLI を呼び出す。

### 許可される操作（PM モード）

| 操作 | 許可 | 説明 |
|------|------|------|
| ファイル読み込み | ✅ | Read, Glob, Grep |
| Claude Worker 呼び出し | ✅ | `Bash (claude -p)` |
| レビューと判定 | ✅ | 品質ゲート、証跡検証 |
| Plans.md 更新 | ✅ | 状態マーカーの更新のみ |
| Edit/Write | ❌ | **禁止**（guard 適用） |

### Claude CLI 呼び出し例

```bash
# プロンプトファイル生成（base-instructions + タスク内容）
cat <<'CLAUDE_PROMPT' > /tmp/claude-worker-prompt.md
## プロジェクトルール
{.claude/rules/*.md 連結}

## 必須: AGENTS.md 準拠
{AGENTS_SUMMARY 証跡出力指示}

---
{タスク内容}
CLAUDE_PROMPT

TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")
$TIMEOUT 180 claude -p "$(cat /tmp/claude-worker-prompt.md)" 2>/dev/null
EXIT_CODE=$?

if [ $EXIT_CODE -eq 124 ]; then
  echo "TIMEOUT: Claude CLI timed out after 180s"
fi
```

## work-active.json

### デフォルト（Codex実装）

```json
{
  "active": true,
  "started_at": "2026-02-18T10:00:00Z",
  "strategy": "iteration",
  "codex_mode": true,
  "impl_engine": "codex",
  "bypass_guards": ["rm_rf", "git_push"],
  "allowed_rm_paths": ["node_modules", "dist", ".cache"]
}
```

### `--claude`（委譲モード）

```json
{
  "active": true,
  "started_at": "2026-02-18T10:00:00Z",
  "strategy": "iteration",
  "codex_mode": false,
  "impl_engine": "claude",
  "bypass_guards": ["rm_rf", "git_push"],
  "allowed_rm_paths": ["node_modules", "dist", ".cache"]
}
```

## AGENTS_SUMMARY Compliance

委譲モード（`--claude`）では Worker が開始時に以下を出力する必要がある:

```text
AGENTS_SUMMARY: <1行要約> | HASH:<SHA256先頭8文字>
```

- 欠落時: 即失敗 → 手動対応
- ハッシュ不一致: 最大 3 回まで再実行

## Quality Gates

| Gate | コマンド | 失敗時 | 最大リトライ |
|------|---------|--------|------------|
| lint | `npm run lint` | 自動修正指示 | 3 回 |
| type-check | `tsc --noEmit` | 型エラー修正指示 | 3 回 |
| test | `npm test` | テスト修正指示 | 3 回 |
| tamper | パターン検出 | 即停止 | 0 |

## Prerequisites

1. デフォルト（Codex 実装）: 追加要件なし
2. `--claude` 使用時: `which claude` でパスが表示されること
3. 並列実行時: `git --version` >= 2.5.0（worktree 利用時）

## Related

- [auto-iteration.md](auto-iteration.md) - 自動反復ロジック
- [parallel-execution.md](parallel-execution.md) - 並列実行戦略
