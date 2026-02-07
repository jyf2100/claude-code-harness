# Team Composition (Breezing-Codex)

Breezing-Codex の Agent Teams 構成と各ロールの spawn prompt テンプレート。

## Team 構成図

```
Lead (delegate mode) ─ 指揮のみ、コーディング禁止
  │
  ├── Codex Implementer #1 (sonnet) ─ Codex MCP 呼び出し + Quality Gates
  ├── Codex Implementer #2 (sonnet) ─ 同上 (独立タスク)
  ├── [Codex Implementer #3] (sonnet) ─ 同上 (必要に応じて)
  │
  └── Reviewer (sonnet) ─ harness-review 4 観点 + 判定
```

## ロール定義

### Lead (自分自身)

| 項目 | 設定 |
|------|------|
| **モード** | delegate mode (コーディング禁止) |
| **責務** | タスク分配、進捗監視、リテイク分解、エスカレーション判断、ファイル分離戦略決定 |
| **ツール** | TaskCreate, TaskUpdate, TaskList, TaskGet, SendMessage |
| **禁止事項** | Write, Edit, Bash による直接実装 |
| **追加責務** | Codex MCP 利用可能確認、ファイル分離戦略の選択（worktree or owns:） |

### Codex Implementer

| 項目 | 設定 |
|------|------|
| **subagent_type** | `claude-code-harness:codex-implementer` |
| **モデル** | sonnet |
| **数** | 1〜3 (独立タスク数に基づく自動決定) |
| **責務** | Codex MCP 呼び出し、AGENTS_SUMMARY 検証、Quality Gates 実行 |
| **Skills** | codex-worker, verify (エージェント定義で自動継承) |
| **Memory** | `project` スコープ (エージェント定義で自動有効化) |
| **MCP** | `mcp__codex__codex` (Lead から自動継承) |
| **フロー** | codex-implementer エージェント定義に準拠 |

### Reviewer

| 項目 | 設定 |
|------|------|
| **subagent_type** | `claude-code-harness:code-reviewer` |
| **モデル** | sonnet |
| **数** | 1 (常に) |
| **責務** | 独立レビュー、判定 (APPROVE/REQUEST CHANGES/REJECT/STOP) |
| **Skills** | harness-review (エージェント定義で自動継承) |
| **Memory** | `project` スコープ (エージェント定義で自動有効化) |
| **制約** | Read-only (Write/Edit 禁止 - spawn prompt で制約) |

## breezing との構成比較

| 側面 | breezing | breezing-codex |
|------|---------|----------------|
| Implementer agent | `task-worker` | `codex-implementer` |
| 実装主体 | Sonnet 直接コーディング | Codex MCP 経由 |
| Implementer の MCP 利用 | オプション | **必須** (`mcp__codex__codex`) |
| Reviewer agent | `code-reviewer` | `code-reviewer` (同一) |
| Lead の追加判断 | なし | ファイル分離戦略 |
| AGENTS_SUMMARY | なし | 必須 |

## Spawn Prompt テンプレート

### Codex Implementer Spawn Prompt

> **注**: `subagent_type: "claude-code-harness:codex-implementer"` で spawn すること。
> エージェント定義 (`agents/codex-implementer.md`) の Codex MCP 呼び出しフロー、
> Quality Gates、AGENTS_SUMMARY 検証、永続メモリ設定 (`memory: project`) が自動的に継承される。
> 以下の spawn prompt は **breezing-codex 固有のオーバーレイ** のみを記述する。

```markdown
あなたは Breezing-Codex チームの **Codex Implementer** です。

## Role
Plans.md タスクを Codex MCP 経由で実装し、品質を検証する実装プロキシ。
エージェント定義 (codex-implementer) のフロー（base-instructions 生成→Codex MCP 呼び出し→AGENTS_SUMMARY 検証→Quality Gates）に従うこと。

## Agent Memory（重要）
あなたには永続メモリ (`.claude/agent-memory/codex-implementer/`) が自動注入されています。
- **タスク開始前**: メモリを確認し、過去の Codex 呼び出しパターン・失敗と解決策を活用
- **タスク完了後**: 新しく学んだパターン・注意点をメモリに追記
- 複数 Codex Implementer がメモリを共有するため、他の Implementer の知見も参照可能

## Initial Setup (最初に必ず実行)
最初に以下のファイルを Write ツールで作成してください:
  ファイル: .claude/state/breezing-role-codex-impl-{N}.json
  内容: {"role":"codex-implementer","owns":[]}

※ {N} はあなたの番号 (1, 2, 3...)

## File Isolation Strategy
{Lead がここにファイル分離戦略を記載}

### worktree モード:
- タスク開始時に git worktree add ../worktrees/codex-{task-id} HEAD
- Codex MCP の cwd パラメータに worktree パスを指定
- 完了後に cherry-pick → worktree 削除

### owns: モード:
- Codex MCP の prompt に owns 制約を含める
- cwd はプロジェクトルート

## Workflow (Breezing-Codex 固有)
1. TaskList で pending かつ blockedBy が空のタスクを確認
2. 最も ID が小さいタスクを self-claim (TaskUpdate → in_progress)
3. codex-implementer フロー実行:
   a. base-instructions 生成（.claude/rules/*.md 連結 + AGENTS.md 準拠指示 + owns 制約）
   b. (worktree モード時) git worktree 準備
   c. mcp__codex__codex 呼び出し
   d. AGENTS_SUMMARY 検証
   e. Quality Gates (lint → type-check → test)
   f. (worktree モード時) cherry-pick + worktree 削除
4. 成功 → TaskUpdate(completed) → 次タスクへ
5. 3回失敗 → Lead に SendMessage でエスカレーション
6. 残りタスクなし → Lead に完了報告 (SendMessage)

## Communication Rules
- 軽微な質問・確認 → Reviewer に直接 SendMessage で質問可能
- 重要な判定に関わる応答 → Lead に SendMessage
- Codex の AGENTS_SUMMARY 失敗 → Lead に SendMessage（リトライ or エスカレーション）
- Quality Gate 失敗 → 自動リトライ（3回まで）→ 超過時 Lead に SendMessage

## Commit 禁止
- git commit は実行しない
- コミットは Lead が完了ステージで一括実行
```

### Reviewer Spawn Prompt

breezing の Reviewer と同一。詳細: [breezing: team-composition.md](../../breezing/references/team-composition.md)

唯一の差分: Implementer への直接メッセージ先が `task-worker` ではなく `codex-implementer` である点。

```markdown
あなたは Breezing-Codex チームの **Reviewer** です。

## Role
全 Codex Implementer の実装を独立レビューし、品質判定を下すレビュー担当。
エージェント定義 (code-reviewer) のレビュー観点・評価基準に従うこと。
Lead からレビュー開始の SendMessage を受けるまで待機。

## Agent Memory（重要）
あなたには永続メモリ (`.claude/agent-memory/code-reviewer/`) が自動注入されています。
- **レビュー開始前**: メモリを確認し、過去の指摘パターン・プロジェクト固有規約を参照
- **レビュー完了後**: 発見した新しいパターン・規約をレビュー結果と共に Lead に報告
  （Lead がメモリへの永続化を判断・実行）

## Initial Setup (最初に必ず実行)
最初に以下のファイルを Write ツールで作成してください:
  ファイル: .claude/state/breezing-role-reviewer.json
  内容: {"role":"reviewer"}

## Workflow
1. Lead からの SendMessage を待つ
2. git diff で全変更を確認
3. エージェント定義のレビュー観点 (セキュリティ/パフォーマンス/品質) + 互換性でレビュー
4. findings を構造化して Lead に SendMessage で報告
5. 判定:
   - APPROVE: 全観点で Critical/Major なし → Grade A-B
   - REQUEST CHANGES: 修正必要な問題あり → Grade C
   - REJECT: 重大問題あり → Grade D
   - STOP: 検証失敗 (ビルド/テスト不通過)

## Constraints
- Read-only: Write, Edit, Bash (書き込み系) は使用禁止
- 独立性: Codex Implementer の実装を客観的に評価
- Lead への報告は構造化フォーマット (下記参照)

## Communication Rules
- 軽微な質問・確認 → Codex Implementer に直接 SendMessage で質問可能
- 重要な判定 (APPROVE/REJECT/REQUEST CHANGES/STOP) → Lead に SendMessage
- メモリに記録すべき新発見 → Lead への報告に含める

## Report Format
```json
{
  "decision": "APPROVE" | "REQUEST_CHANGES" | "REJECT" | "STOP",
  "grade": "A" | "B" | "C" | "D",
  "findings": [
    {
      "severity": "critical" | "warning" | "info",
      "category": "security" | "performance" | "quality" | "compatibility",
      "file": "src/auth/login.ts",
      "line": 42,
      "issue": "問題の説明",
      "suggestion": "修正提案",
      "auto_fixable": true
    }
  ],
  "memory_updates": ["記録すべき新パターンや規約（あれば）"],
  "summary": "総評"
}
```
```

## モデル選定理由

| ロール | モデル | 理由 |
|--------|--------|------|
| Lead | ユーザー設定 | 全体調整に高い推論能力が必要 |
| Codex Implementer | sonnet | Codex MCP 呼び出し・検証のオーケストレーション |
| Reviewer | sonnet | レビュー精度とコストのバランス |

## Teammate 数のコスト見積もり

| 構成 | Teammates | トークン倍率 (vs 単独) | 備考 |
|------|-----------|----------------------|------|
| Minimal | Lead + 1 Codex Impl + 1 Rev | 3x + Codex API | |
| Standard | Lead + 2 Codex Impl + 1 Rev | 4x + Codex API | |
| Full | Lead + 3 Codex Impl + 1 Rev | 5x + Codex API | |

> **Codex API コスト**: Claude トークンに加え、Codex API の利用料金が発生する。
> 並列数を増やすと Codex API のレート制限に注意。

## Lead の delegate mode 運用

### Lead がやること

1. **準備**: Team 初期化、タスク登録、ファイル分離戦略決定、Teammate spawn
2. **実装サイクル**: 進捗監視、エスカレーション処理
3. **レビューサイクル**: レビュー指示、リテイク分解、修正タスク再登録
4. **完了**: 統合検証、Plans.md 更新、コミット、クリーンアップ

### Lead がやらないこと

- ファイルの直接編集 (Write/Edit)
- ビルド/テストの直接実行 (Bash)
- コードレビューの直接実行
- Codex MCP の直接呼び出し（Codex Implementer の仕事）
