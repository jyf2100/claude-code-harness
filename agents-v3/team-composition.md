# Team Composition (v3)

Harness v3 の3エージェント構成。
11エージェント → 3エージェントに統合。

## Team 構成図

```
Lead (Execute スキルの --breezing モード) ─ 指揮のみ
  │
  ├── Worker (claude-code-harness:worker)
  │     実装 + セルフレビュー + ビルド検証 + コミット
  │     ※ --codex 時は codex exec を内部で呼び出す
  │
  ├── [Worker #2] (claude-code-harness:worker)
  │     独立タスクを並列実行
  │
  └── Reviewer (claude-code-harness:reviewer)
        Security / Performance / Quality / Accessibility
        REQUEST_CHANGES → Lead が修正タスクを作成
```

## 旧エージェント → v3 マッピング

| 旧エージェント | v3 エージェント |
|--------------|--------------|
| task-worker | worker |
| codex-implementer | worker（--codex 内包） |
| error-recovery | worker（エラー復旧内包） |
| code-reviewer | reviewer |
| plan-critic | reviewer（plan type） |
| plan-analyst | reviewer（scope type） |
| project-analyzer | scaffolder |
| project-scaffolder | scaffolder |
| project-state-updater | scaffolder |
| ci-cd-fixer | worker（CI 復旧内包） |
| video-scene-generator | extensions/generate-video（別途） |

## ロール定義

### Lead（Execute スキルの内部）

| 項目 | 設定 |
|------|------|
| **Phase A** | 準備・タスク分解 |
| **Phase B** | delegate mode — TaskCreate/TaskUpdate/SendMessage のみ |
| **Phase C** | 完了処理・コミット・Plans.md 更新 |
| **禁止** | Phase B 中の直接 Write/Edit/Bash |

### Worker

| 項目 | 設定 |
|------|------|
| **subagent_type** | `claude-code-harness:worker` |
| **モデル** | sonnet |
| **数** | 1〜3（独立タスク数に基づく） |
| **ツール** | Read, Write, Edit, Bash, Grep, Glob |
| **禁止** | Task（再帰防止） |
| **責務** | 実装 → セルフレビュー → CI検証 → コミット |
| **エラー復旧** | 最大3回。3回失敗でエスカレーション |

### Reviewer

| 項目 | 設定 |
|------|------|
| **subagent_type** | `claude-code-harness:reviewer` |
| **モデル** | sonnet |
| **数** | 1 |
| **ツール** | Read, Grep, Glob（Read-only） |
| **禁止** | Write, Edit, Bash, Task |
| **責務** | コード/プラン/スコープのレビュー |
| **判定** | APPROVE / REQUEST_CHANGES |

### Scaffolder（セットアップ時のみ）

| 項目 | 設定 |
|------|------|
| **subagent_type** | `claude-code-harness:scaffolder` |
| **モデル** | sonnet |
| **数** | 1 |
| **ツール** | Read, Write, Edit, Bash, Grep, Glob |
| **責務** | プロジェクト分析・足場構築・状態更新 |

## 実行フロー

```
Phase A: Lead がタスクを分解
    ↓
Phase B: Worker(s) を並列 spawn
    Worker: 実装 → セルフレビュー → コミット
    ↓（全 Worker 完了後）
Phase B: Reviewer を spawn
    Reviewer: コードレビュー → APPROVE / REQUEST_CHANGES
    ↓（APPROVE の場合）
Phase C: Lead がクリーンアップ・Plans.md 更新
```

**REQUEST_CHANGES の場合**:
```
Reviewer → REQUEST_CHANGES
    ↓
Lead: 修正タスクを TaskCreate
    ↓
Worker: 修正実装 → コミット
    ↓
Reviewer: 再レビュー
```

## 権限設定（bypassPermissions）

Teammate は UI なしでバックグラウンド実行されるため、
全 Teammate spawn に `mode: "bypassPermissions"` を指定する。

安全層:
1. `disallowedTools` でツールを制限
2. spawn prompt で行動範囲を明示
3. PreToolUse hooks がガードレールを維持
4. Lead が常に監視
