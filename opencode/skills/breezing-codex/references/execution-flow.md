# Execution Flow (Breezing-Codex)

Agent Teams + Codex MCP を活用した `/breezing-codex` の実行フロー。
Lead は状況に応じてステージ間を柔軟に判断する。

## フロー全体図

```text
/breezing-codex 認証機能からユーザー管理まで完了して
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 0: breezing-active.json 即時書き込み (impl_mode: codex) │
│  → Compaction 耐性の確保（環境チェックより前）               │
└─────────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────────┐
│ 準備（必須、最初に 1 回）                                    │
│  環境チェック → ユーザー承認 → Team 初期化 → delegate mode   │
│  Codex Implementer spawn + Reviewer spawn                    │
│  ※環境チェック失敗時は breezing-active.json を削除           │
└─────────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────────┐
│ 実装・レビューサイクル（Lead の判断で柔軟に運用）            │
│                                                              │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐       │
│  │ 実装         │ ↔ │ レビュー     │ ↔ │ リテイク     │       │
│  │ Codex Impl   │   │ Reviewer     │   │ Impl↔Rev    │       │
│  │ MCP→Codex    │   │ harness-rev  │   │ 直接対話可   │       │
│  │ QualityGates │   │ 4観点        │   │             │       │
│  └─────────────┘   └─────────────┘   └─────────────┘       │
│                                                              │
│  Lead はこのサイクルを監視し、状況に応じて:                   │
│  ・半分完了 → 部分レビューを指示                             │
│  ・軽微な問題 → Reviewer↔Codex Implementer 直接対話で解決    │
│  ・重大な問題 → タスク分解して修正タスク登録                 │
│  ・3回リテイク超過 → ユーザーにエスカレーション              │
└─────────────────────────────────────────────────────────────┘
    ↓ 全タスク完了 + APPROVE
┌─────────────────────────────────────────────────────────────┐
│ 完了                                                         │
│  統合検証 → Plans.md 更新 → git commit → メトリクスレポート  │
└─────────────────────────────────────────────────────────────┘
```

## 準備ステージ

### 0. breezing-active.json 即時書き込み（最優先）

**環境チェックよりも前に実行する。** Compaction 対策として、モード情報を永続化する。

```jsonc
// .claude/state/breezing-active.json に即時書き込み
{
  "session_id": "breezing-codex-{timestamp}",
  "started_at": "{ISO8601}",
  "impl_mode": "codex",  // ← この値が compaction 後の復元キー
  "task_range": "{ユーザー指定の範囲}"
  // 残りのフィールド (team_name, plans_md_mapping 等) は Step 3 で追記
}
```

**なぜ最初に書くか**: Compaction が準備ステージ中に発生しても、`impl_mode: "codex"` が永続化されていれば復元できる。

**環境チェック失敗時のクリーンアップ**: Step 1 の環境チェックが失敗した場合、Step 0 で書き込んだ breezing-active.json を削除する。部分的なファイルが残ると「続きやって」で誤復元されるリスクがあるため。

### 1. 環境チェック

```bash
# Agent Teams 有効化チェック
# CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 が必要

# Codex MCP 利用可能チェック（breezing-codex 固有）
# mcp__codex__codex ツールが利用可能であること
```

未設定時のメッセージ:

```text
⚠️ 前提条件を確認してください:

1. Agent Teams が有効化されていません。
   settings.json に以下を追加:
   { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }

2. Codex MCP が登録されていません。
   MCP サーバー設定で mcp__codex__codex が利用可能であることを確認してください。

Codex なしで実行する場合は /breezing を使用してください。
```

**早期中断時のクリーンアップ**: Step 0 で書き込んだ `breezing-active.json` を削除してから停止する。
部分的なファイルが残ると「続きやって」で誤復元されるリスクがあるため。

```text
以下のいずれかで中断 → breezing-active.json 削除 → 停止:
  ・環境チェック失敗（Agent Teams 未有効、Codex MCP 未登録）
  ・ユーザーが範囲確認で拒否/キャンセル
  ・Team 初期化の失敗
```

### 2. 範囲確認（ユーザー承認必須）

breezing と同一パターン。詳細: [breezing: execution-flow.md](../../breezing/references/execution-flow.md)

```text
🏇 Breezing-Codex - 範囲を確認させてください

指定: 「認証機能からユーザー管理まで」

対象タスク:
├── 3. ログイン機能の実装 (cc:TODO)
├── 4. 認証ミドルウェアの作成 (cc:TODO)
└── 5. セッション管理 (cc:TODO)

Team 構成:
├── Lead: delegate mode (調整専念)
├── Codex Implementer: 2 個 (独立タスク数に基づく)
└── Reviewer: 1 個 (Claude, harness-review)

⚡ 実装は全て Codex MCP 経由で実行されます。

計 3 タスクを Codex Implementer 2 並列で完走します。

これで合っていますか？
```

### 3. Team 初期化

1. breezing-active.json に残りフィールドを追記（Step 0 で `impl_mode: "codex"` は書き込み済み）
2. delegate mode ON → Lead は指揮専念
3. Plans.md タスクを TaskCreate で共有タスクリストに登録
   - owns: アノテーション付与
   - addBlockedBy で依存関係設定
   - Plans.md → TaskList 変換ルール: [breezing: plans-to-tasklist.md](../../breezing/references/plans-to-tasklist.md)
4. **ファイル分離戦略の判断**（Lead が決定）
   - 並列タスクが多い or ファイル競合リスクが高い → worktree 分離を指示
   - シンプルなタスク or 直列実行 → owns: アノテーションのみ
5. Codex Implementer Teammates spawn (N 個)
   - `subagent_type: "claude-code-harness:codex-implementer"` で spawn
   - エージェント定義の `memory: project` により永続メモリが自動注入
   - spawn prompt でファイル分離戦略を指示
6. Reviewer Teammate spawn (1 個)
   - `subagent_type: "claude-code-harness:code-reviewer"` で spawn
   - エージェント定義の `memory: project` により永続メモリが自動注入

詳細: [team-composition.md](team-composition.md)

### breezing-active.json スキーマ (breezing-codex 版)

**ファイル**: `.claude/state/breezing-active.json`

```jsonc
{
  "session_id": "breezing-codex-20260207-0300",
  "started_at": "2026-02-07T03:00:00Z",
  "team_name": "breezing-codex-auth-feature",
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
    "implementer_count": 2,   // impl_mode で implementer 種別を判断
    "reviewer_count": 1,
    "model": "sonnet"
  },
  "isolation": {
    "strategy": "worktree",   // "worktree" or "owns_only"
    "worktree_base": "../worktrees"
  },
  "review": {
    "retake_count": 0,
    "max_retakes": 3
  }
}
```

### Codex Implementer 数の自動決定

```
独立タスク数 = 依存関係なしで並列実行可能なタスク数

Codex Implementer 数 = min(独立タスク数, --parallel N, 3)

デフォルト上限: 3 (Codex API レート制限 + トークンコスト抑制)
```

## 実装・レビューサイクル

### Lead の運用ガイドライン

Lead はサイクル内で以下を**自律的に判断**する:

| 状況 | Lead の判断 |
|------|------------|
| 全タスク未着手 | Codex Implementer にタスク消化を開始させる |
| 半数のタスクが完了 | 部分レビューを Reviewer に指示可能 |
| 全タスク完了 | 全体レビューを Reviewer に指示 |
| Reviewer から質問 | Reviewer↔Codex Implementer 直接対話を許可 |
| REQUEST CHANGES | findings を修正タスクに分解、Codex Implementer に指示 |
| 3回リテイク超過 | ユーザーにエスカレーション |
| AGENTS_SUMMARY 失敗 | Codex Implementer にリトライ指示 or エスカレーション |

### Codex Implementer の自律ループ

各 Codex Implementer は以下を独立して繰り返す:

```
1. TaskList で pending かつ blockedBy が空のタスクを検索
2. 最も ID が小さいタスクを self-claim (TaskUpdate → in_progress)
3. codex-implementer フロー実行:
   - base-instructions 生成
   - (worktree 指示時) git worktree 準備
   - mcp__codex__codex 呼び出し
   - AGENTS_SUMMARY 検証
   - Quality Gates (lint → type-check → test)
   - (worktree 使用時) cherry-pick + worktree 削除
4. 成功 → TaskUpdate(completed)
5. 失敗 (3回) → Lead にエスカレーション (SendMessage)
6. 残りタスクあり → Step 1 へ
7. 残りタスクなし → Lead に完了報告 (SendMessage)
```

詳細: [codex-impl-flow.md](codex-impl-flow.md)

### ファイル競合回避

breezing と同一ルール + worktree 分離オプション:

```
Lead が準備ステージで検出:
  タスク A: src/auth/login.ts を編集
  タスク B: src/auth/login.ts を編集

owns: のみモード:
  → B に addBlockedBy: [A] を設定

worktree モード:
  → 各タスクが独立 worktree で実行
  → cherry-pick 時に競合検出 → ユーザー判断
```

### レビューのタイミング

breezing と同一パターン。詳細: [breezing: execution-flow.md](../../breezing/references/execution-flow.md)

### リテイクループ

breezing と同一フレームワーク。
ただし Codex Implementer がリテイクタスクを消化する際、Reviewer の findings を Codex prompt に含める。

詳細: [breezing: review-retake-loop.md](../../breezing/references/review-retake-loop.md)

## 完了ステージ

breezing と同一。詳細: [breezing: execution-flow.md](../../breezing/references/execution-flow.md)

### 完了レポート (breezing-codex 版)

```markdown
🏇 Breezing-Codex Complete!

## Summary
- 対象: 認証機能からユーザー管理まで (3 タスク)
- 所要時間: 12 分
- Codex Implementer: 2 並列
- 分離戦略: worktree
- リテイク: 1 回

## Tasks
✅ 3. ログイン機能の実装 (Codex → Quality Gates pass)
✅ 4. 認証ミドルウェアの作成 (Codex → Quality Gates pass)
✅ 5. セッション管理 (Codex → Quality Gates pass)

## AGENTS_SUMMARY Compliance
- 全タスク検証通過: 3/3

## Review
- 判定: APPROVE (Grade: A)

## Build & Test
- ビルド: ✅ 成功
- テスト: ✅ 12/12 通過

## Commit
- abc1234: feat: implement auth flow (login, middleware, session)

Codex が手を動かし、Claude がチェック。楽勝でした 🐎⚡
```
