# GitHub Release Notes Rules

GitHub Releases のリリースノート作成時に適用されるフォーマットルール。

## 必須フォーマット

### 構造

```markdown
## 🎯 What's Changed for You

**1行で変更の価値を説明**

### Before → After

| Before | After |
|--------|-------|
| 変更前の状態 | 変更後の状態 |
| ... | ... |

---

## Added

- **機能名**: 説明
  - 詳細項目1
  - 詳細項目2

## Changed

- **変更内容**: 説明

## Fixed

- **修正内容**: 説明

## Requirements（必要な場合のみ）

- **Claude Code vX.X.X+** (推奨)
- リンク: [ドキュメント](URL)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### 必須要素

| 要素 | 必須 | 説明 |
|------|------|------|
| `🎯 What's Changed for You` | ✅ | 見出し（日本語: あなたにとって何が変わるか） |
| **太字サマリー** | ✅ | 1行で変更の価値を説明 |
| `Before → After` テーブル | ✅ | ユーザー視点での変化を明示 |
| `Added/Changed/Fixed` | 該当時 | 詳細な変更内容 |
| フッター | ✅ | `🤖 Generated with [Claude Code](...)` |

### 言語

- **日本語推奨**（国内ユーザー中心）
- Before/After は「Before → After」形式（矢印付き）
- 見出しは `🎯 What's Changed for You` または `🎯 あなたにとって何が変わるか`

## 禁止事項

- ❌ Before/After テーブルの省略
- ❌ フッターの省略
- ❌ 技術詳細のみの記載（ユーザー視点必須）
- ❌ 変更内容の羅列のみ（価値の説明必須）

## 良い例

```markdown
## 🎯 What's Changed for You

**`/work --full` で「実装→セルフレビュー→改善→コミット」が並列自動化されました**

### Before → After

| Before | After |
|--------|-------|
| `/work` はタスクを1つずつ実行 | `/work --full --parallel 3` で並列実行 |
| レビューは別途手動で実行 | 各 task-worker が自律的にセルフレビュー |
```

## 悪い例

```markdown
## What's New

### Added
- task-worker.md を追加
- --full オプションを追加
```

→ ユーザーにとっての価値が伝わらない

## リリース作成コマンド

```bash
gh release create vX.X.X \
  --title "vX.X.X - タイトル" \
  --notes "$(cat <<'EOF'
## 🎯 What's Changed for You
...
EOF
)"
```

## 過去リリースの編集

```bash
gh release edit vX.X.X --notes "$(cat <<'EOF'
...
EOF
)"
```

## 参照

- 良い例: v2.8.0, v2.8.2, v2.9.1
- CHANGELOG と整合性を保つこと
