---
description: 受信メッセージを確認（セッション間通信）
description-en: Check received messages (inter-session communication)
---

# /session-inbox - セッション間メッセージ受信

他のセッションからのブロードキャストメッセージを確認します。
**重要な変更通知を見逃さない**ために使用します。

## VibeCoder Quick Reference

- "**メッセージある？**" → このコマンド
- "**通知確認**" → 未読メッセージをチェック
- "**既読にして**" → 全メッセージを既読にマーク

## Deliverables

- 未読メッセージの一覧表示
- 既読マーク機能

---

## Usage

### 未読メッセージを確認

```bash
/session-inbox
```

### 既読にマーク

```bash
/session-inbox --mark
```

### 未読件数のみ確認

```bash
/session-inbox --count
```

---

## Execution Flow

### Step 1: 未読チェック実行

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-inbox-check.sh"
```

### Step 2: 結果表示

#### 未読メッセージがある場合

> 📨 **未読メッセージ 2件:**
>
> | 時刻 | 送信元 | メッセージ |
> |------|--------|------------|
> | 10:30 | session-def4 | UserAPI: userId → user に変更 |
> | 10:45 | session-def4 | テスト追加済み |
>
> 💡 `/session-inbox --mark` で既読にできます

#### 未読メッセージがない場合

> 📭 **未読メッセージはありません**
>
> 最終チェック: {timestamp}

---

## Options

| オプション | 説明 | 例 |
|------------|------|-----|
| (なし) | 未読メッセージを一覧表示 | `/session-inbox` |
| `--mark` | 全メッセージを既読にする | `/session-inbox --mark` |
| `--count` | 未読件数のみ表示 | `/session-inbox --count` |

---

## Auto-check (hooks連携)

Write/Edit 実行前に未読メッセージが**自動的に表示**されます（確認は不要）：

```
You: このファイルを編集して

📨 他セッションからのメッセージ 1件:
---
[10:30] session-def4: UserAPI: userId → user に変更
---

Claude: 承知しました。UserAPI の変更を考慮して編集します...
```

**ポイント**:
- メッセージ内容は自動で表示される（`/session-inbox` の実行は不要）
- 自動既読マークはされない（`--mark` で明示的に既読にする）
- このコマンドは詳細確認・既読マーク専用として利用

---

## How It Works

### 既読管理

- 各セッションごとに最終読み取り時刻を記録
- `.claude/sessions/.last_read_{session_id}` に保存
- この時刻より後のメッセージが「未読」として表示

### 自分のメッセージ

- 自分が送信したメッセージは inbox に表示されません
- セッションIDで送信元を判別

---

## Related Commands

- `/session-broadcast` - メッセージを送信
- `/session-list` - アクティブセッション一覧

---

## Notes

- 未読チェックはローカルファイルベースで高速
- セッション終了後も未読状態は保持されます
- `/harness-init` 実行時に自動で inbox チェックが行われます
- **v2.12.0+**: Write/Edit 実行前にメッセージ内容が自動表示されます（確認プロンプトなし）
