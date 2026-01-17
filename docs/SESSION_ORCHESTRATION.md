# Deterministic Orchestration + Session Persistence (Spec)

## 目的
非決定論的な実行（Claude Code）を決定論的に包むため、状態機械とセッション永続化の仕様をSSOTとして定義する。
この文書は「設計仕様」であり、実装の前提と判断基準を固定する。

## 用語
- **State**: セッションの段階を示す固定ラベル
- **Event**: 状態を進めるトリガー（フック、コマンド、タスク結果）
- **Snapshot**: セッションの最新状態を持つ1ファイル
- **Event Log**: 状態変化の履歴（追記型）
- **Resume**: Snapshot + Event Log から復元して継続
- **Fork**: ある状態を分岐点として別セッションに分離

## 状態機械（SSOT）
### States
- `idle`: セッション未開始
- `initialized`: SessionStart 完了
- `planning`: Plan/Work の準備
- `executing`: /work 実行中
- `reviewing`: review 実行中
- `verifying`: build/test 実行中
- `escalated`: 人間確認待ち
- `completed`: 成果物確定
- `failed`: 回復不能
- `stopped`: Stop hook 到達

### Events（代表）
- `session.start`
- `plan.ready`
- `work.start`
- `work.task_complete`
- `review.start`
- `review.issue_found`
- `verify.start`
- `verify.failed`
- `escalation.requested`
- `escalation.resolved`
- `session.stop`
- `session.resume`
- `session.fork`

### Transition Rules（最小）
| From | Event | To | 失敗ポリシー |
|------|-------|----|-------------|
| idle | session.start | initialized | なし |
| initialized | plan.ready | planning | なし |
| planning | work.start | executing | 失敗時は `escalated` |
| executing | work.task_complete | reviewing | 失敗時は `escalated` |
| reviewing | review.start | reviewing | 追加指摘は `executing` に戻す |
| reviewing | review.issue_found | executing | 反復回数超過で `failed` |
| executing/reviewing | verify.start | verifying | 失敗時は `escalated` |
| verifying | verify.failed | escalated | リトライ上限で `failed` |
| any | escalation.requested | escalated | 解除で元状態へ |
| any | session.stop | stopped | なし |
| stopped | session.resume | initialized | Snapshot/Log復元 |

## 失敗・リトライ・エスカレーション
- **max_state_retries** を状態ごとに適用（既存の `safety.max_auto_retries` と整合）
- 失敗は Event Log に必ず記録
- リトライ上限超過で `escalated` → 人間判断が入るまで遷移停止
- `failed` は自動で `completed` に戻れない

## セッション永続化（MVP）
### Snapshot（単一ファイル）
保存先（標準）:
- `.claude/state/session.json`

最低限の構造:
```json
{
  "session_id": "uuid",
  "parent_session_id": null,
  "state": "executing",
  "state_version": 1,
  "started_at": "2026-01-17T12:00:00Z",
  "updated_at": "2026-01-17T12:10:00Z",
  "last_event_id": "event-00042",
  "resume_token": "opaque",
  "fork_count": 0
}
```

### Event Log（追記）
保存先（標準）:
- `.claude/state/session.events.jsonl`

1行1イベント（追記のみ）:
```json
{"id":"event-00042","type":"work.task_complete","ts":"2026-01-17T12:09:00Z","state":"executing","data":{"task":"A","status":"commit_ready"}}
```

### 生成/更新タイミング
- **SessionStart**: Snapshot 作成 + `session.start` 記録
- **PostToolUse**: 重要Eventのみ記録（Write/Edit/Task/Skill/Bashの結果）
- **Stop**: `session.stop` 記録 + Snapshot更新

## Resume / Fork の契約
### Resume
入力:
- `session_id` または `resume_token`
処理:
- Snapshot 読込 → Event Log の last_event_id 以降を適用 → 状態復元
出力:
- `state` が `initialized` に復帰し、次のイベントを待つ

### Fork
入力:
- `session_id` + `fork_reason`
処理:
- Snapshot をコピーして `parent_session_id` を設定
- Event Log を新規開始（先頭に `session.fork`）
出力:
- 新しい `session_id` を返す

### /work 導線（提案）
- `/work --resume <session_id>`
- `/work --fork <session_id> --reason "<text>"`
- `/work --resume latest`（最新の停止セッションを再開）

## フック責務（最小）
- **SessionStart**: Snapshot作成/整合性チェック/Resume検出
- **PostToolUse**: 重要Event記録、失敗時のエスカレーション記録
- **Stop**: `session.stop` を記録し Snapshot を確定

## 設定スキーマ拡張（提案）
`claude-code-harness.config.schema.json` に以下を追加:
- `orchestration.state_machine_version`
- `orchestration.max_state_retries`
- `orchestration.retry_backoff_seconds`
- `session.snapshot_path`
- `session.event_log_path`
- `session.resume_policy`
- `session.fork_policy`

## 既存フローとの対応
`/work --full` Phase1-4 は `executing → reviewing → verifying → completed` に対応させる。
Phase2 の差し戻しは `reviewing → executing` に戻すことを明示する。
