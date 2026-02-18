# Codex Engine (Breezing)

`/breezing` は Codex 実行時に **Codex 主導で完走** するモード。
`--claude` 指定時のみ、Implementer を Claude 側へ切り替える。

互換性: `--codex` は legacy alias として受理し、既定動作（Codex 実装）から変更しない。

## Overview

```text
/breezing [scope] [--parallel N]
    │
Phase A: Pre-delegate（準備 + breezing-active.json + Team spawn）
    │
    ↓ delegate mode ON
Phase B: Delegate
Lead ─ 指揮のみ（TaskCreate/TaskUpdate/TaskList/TaskGet/SendMessage）
  │
  ├── Codex Implementer #1 ─ 直接実装 + Quality Gates
  ├── Codex Implementer #2 ─ 同上（独立タスク）
  └── Reviewer ─ harness-review + 判定
    │
    ↓ delegate mode OFF
Phase C: Post-delegate（Plans.md 更新 + commit + cleanup）
```

`--claude` 指定時のみ Implementer を `task-worker`（Claude）へ切り替える。

## Team Matrix

| 項目 | デフォルト (`/breezing`) | `--claude` |
|------|--------------------------|------------|
| `impl_mode` | `"codex"` | `"claude"` |
| Implementer subagent_type | `claude-code-harness:codex-implementer` | `claude-code-harness:task-worker` |
| 実装主体 | Codex | Claude CLI |
| Lead の役割 | 調整専念 | 調整専念 |

## Compaction Recovery

Compaction 発生時は `.claude/state/breezing-active.json` の `impl_mode` を最優先で復元判断する。

1. `impl_mode: "codex"` → `codex-implementer` を再 spawn
2. `impl_mode: "claude"` → `task-worker` を再 spawn
3. `impl_mode` 欠落（legacy）→ Codex 既定として扱い、必要ならユーザー確認

## breezing-active.json Schema (Codex-first)

```jsonc
{
  "session_id": "breezing-codex-20260218-0300",
  "started_at": "2026-02-18T03:00:00Z",
  "team_name": "breezing-auth-feature",
  "task_range": "認証機能からユーザー管理まで",
  "impl_mode": "codex",
  "plans_md_mapping": {
    "task-1": "4.1",
    "task-2": "4.2",
    "task-3": "4.3"
  },
  "options": {
    "parallel": 2
  },
  "team": {
    "implementer_count": 2,
    "reviewer_count": 1,
    "model": "sonnet"
  },
  "review": {
    "retake_count": 0,
    "max_retakes": 3
  }
}
```

## Lead Guardrails

- Phase B では Lead の直接実装（Write/Edit/Bash）は禁止。
- `impl_mode` と `subagent_type` の不一致は禁止。
  - `impl_mode: "codex"` なのに `task-worker` を spawn しない
  - `impl_mode: "claude"` なのに `codex-implementer` を spawn しない

## Implementer Flow

```text
1. pending かつ blockedBy 空のタスクを取得
2. self-claim (in_progress)
3. 実装 + Quality Gates
4. 成功で completed 更新、次タスクへ
5. 3回失敗で Lead にエスカレーション
```

### `impl_mode: "codex"`（既定）

- Codex Implementer が直接実装する。
- Codex 実行中に `codex exec` を自分自身へ呼ぶ再帰は行わない。

### `impl_mode: "claude"`（`--claude`）

- task-worker が Claude CLI を呼び出して実装する。

```bash
TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")
$TIMEOUT 180 claude -p "$(cat /tmp/claude-impl-prompt-{id}.md)" 2>/dev/null
```

## AGENTS_SUMMARY Compliance

`--claude` モードでは Worker が開始時に次を出力する:

```text
AGENTS_SUMMARY: <1行要約> | HASH:<SHA256先頭8文字>
```

不一致/欠落時は失敗として Lead が再実行またはエスカレーションする。

## Quality Gates

| Gate | コマンド | 失敗時 | 最大リトライ |
|------|---------|--------|------------|
| lint | `npm run lint` | 自動修正指示 | 3 回 |
| type-check | `tsc --noEmit` | 型エラー修正指示 | 3 回 |
| test | `npm test` | テスト修正指示 | 3 回 |
| tamper | パターン検出 | 即停止 | 0 |

## Prerequisites

1. Agent Teams 有効化 (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
2. Plans.md に未完了タスクがあること
3. `--claude` 使用時のみ `which claude` が成功すること

## Completion Report

```markdown
🏇 Breezing Complete! (Codex-first)

- 対象: 認証機能からユーザー管理まで (3 タスク)
- 所要時間: 12 分
- Implementer: Codex 2 並列
- リテイク: 1 回
- 判定: APPROVE
```

## Related

- [team-composition.md](team-composition.md)
- [execution-flow.md](execution-flow.md)
- [review-retake-loop.md](review-retake-loop.md)
