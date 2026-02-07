---
name: breezing-codex
description: "Codex に全実装を委託して楽勝で流す。Claude は Lead とレビューに専念。Use when user mentions '/breezing-codex', 'Codex で breezing', 'Codex に全部やらせて', or 'breezing codex mode'. Do NOT load for: single codex tasks, codex review only, standard breezing without codex."
description-en: "Delegate all implementation to Codex while Claude focuses on Lead and Review. Use when user mentions '/breezing-codex', 'Codex で breezing', 'Codex に全部やらせて', or 'breezing codex mode'. Do NOT load for: single codex tasks, codex review only, standard breezing without codex."
description-ja: "Codex に全実装を委託して楽勝で流す。Claude は Lead とレビューに専念。Use when user mentions '/breezing-codex', 'Codex で breezing', 'Codex に全部やらせて', or 'breezing codex mode'. Do NOT load for: single codex tasks, codex review only, standard breezing without codex."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task"]
argument-hint: "[natural language range] [--parallel N]"
disable-model-invocation: true
---

# Breezing-Codex Skill

> **CRITICAL (compaction-resistant): このスキルでは Lead は絶対にコードを直接書かない。**
> **実装は必ず Agent Teams の codex-implementer Teammate 経由で Codex MCP に委託する。**
> **Compaction 後は `.claude/state/breezing-active.json` を Read し、`impl_mode: "codex"` を確認してから続行する。**

Agent Teams を活用して Plans.md の未完了タスクを**チーム協調で完全自動完走**する。
**実装は全て Codex に委託**し、Claude は Lead（指揮）と Reviewer（品質保証）に専念する。

## Compaction Recovery

**Compaction が発生した場合（コンテキストが圧縮された場合）の復元手順:**

1. `.claude/state/breezing-active.json` を Read する（ファイルが存在しない/読めない場合は停止してユーザーに確認）
2. `impl_mode` が `"codex"` であることを確認
3. `team_name` で TaskList が存在するか確認（`~/.claude/tasks/{team_name}/`）
4. Team が消失していれば再作成:
   - TeamCreate → delegate mode ON
   - codex-implementer Teammate を `team.implementer_count` 個 spawn
   - code-reviewer Teammate を spawn
5. `team_name` がまだない（準備ステージ中の compaction）場合は、準備ステージの範囲確認から再開
6. TaskList で未完了タスクを確認し、サイクルを再開

**絶対禁止**: breezing-active.json に `impl_mode: "codex"` がある限り、Lead が Write/Edit でリポジトリのソースコードを直接書くことは禁止。
（Lead が編集してよいもの: breezing-active.json, Plans.md のマーカー更新のみ）

## Philosophy

> **「Claude は指揮とレビュー、Codex が手を動かす」**
>
> delegate mode で Lead は調整に専念。
> 実装は Codex MCP 経由で Codex Implementer が実行。
> レビューは独立 Reviewer。三者分離の完全自律。

## Quick Reference

```bash
/breezing-codex 全部やって                    # Plans.md 全タスクを完走（Codex 実装）
/breezing-codex 認証機能からユーザー管理まで    # 範囲指定
/breezing-codex --parallel 2 ログイン機能      # 並列数指定
/breezing-codex 続きやって                     # 前回中断から再開
```

## `/breezing` との違い

| 特徴 | `/breezing` | `/breezing-codex` |
|------|------------|-------------------|
| 実装担当 | **Claude (task-worker)** | **Codex (codex-implementer)** |
| 実装の仕組み | Sonnet が直接コーディング | Codex MCP 経由で委託 |
| レビュー担当 | Claude (code-reviewer) | Claude (code-reviewer) |
| Lead の役割 | delegate mode（調整専念） | delegate mode（調整専念） |
| 品質保証 | セルフレビュー 4 観点 | AGENTS_SUMMARY + Quality Gates |
| ファイル分離 | owns: アノテーション | Lead 判断（worktree or owns:） |
| コスト特性 | Claude トークン消費 | Codex API + Claude レビュー |

## Feature Details

| Feature | Reference |
|---------|-----------|
| **Execution Flow** | See [references/execution-flow.md](references/execution-flow.md) |
| **Team Composition** | See [references/team-composition.md](references/team-composition.md) |
| **Codex Impl Flow** | See [references/codex-impl-flow.md](references/codex-impl-flow.md) |
| **Review/Retake Loop** | See [breezing: review-retake-loop.md](../breezing/references/review-retake-loop.md) |
| **Plans.md → TaskList** | See [breezing: plans-to-tasklist.md](../breezing/references/plans-to-tasklist.md) |
| **Session Resilience** | See [breezing: session-resilience.md](../breezing/references/session-resilience.md) |
| **Guardrails Inheritance** | See [breezing: guardrails-inheritance.md](../breezing/references/guardrails-inheritance.md) |

## Prerequisites

1. **Agent Teams 有効化**: `settings.json` に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
2. **Codex MCP サーバー登録済み**: `mcp__codex__codex` が利用可能
3. **Plans.md** が存在し、未完了タスクがあること

## Execution Flow Summary

```
/breezing-codex [range] [--parallel N]
    │
準備: 範囲確認 → ユーザー承認 → Team 初期化 → delegate mode
    │  Codex Implementer spawn + Reviewer spawn
    │
実装・レビューサイクル (Lead の判断で柔軟に運用):
  ├── 実装: Codex Implementer が TaskList からタスク取得 → Codex MCP 呼び出し → Quality Gates
  ├── レビュー: Reviewer 独立レビュー (harness-review 4 観点)
  └── リテイク: findings → 修正タスク → Codex Implementer が再取得 → Codex に修正依頼
    │
完了: 全タスク完了 + APPROVE → 統合検証 → commit → cleanup
```

## Completion Conditions

以下を**全て**満たしたとき完了:

1. 指定範囲の全タスクが `cc:done`
2. 全タスクの AGENTS_SUMMARY 検証通過
3. 統合ビルド成功
4. 全テスト通過
5. Reviewer が最終 APPROVE (Critical/Major findings = 0)

## VibeCoder Hints

| What You Want | How to Say |
|---------------|------------|
| 全部終わらせて（Codex 実装） | `/breezing-codex 全部やって` |
| この機能だけ | `/breezing-codex ログイン機能を完了して` |
| ここからここまで | `/breezing-codex 認証からユーザー管理まで` |
| 前回の続きから | `/breezing-codex 続きやって` |
| Codex 不要なら | `/breezing 全部やって` (標準 breezing) |

## Related Skills

- `breezing` - Claude が直接実装する標準版
- `codex-worker` - 単発の Codex 実装委託
- `codex-review` - Codex によるセカンドオピニオンレビュー
