---
description: Generate completion report for OpenCode (PM)
description-en: Generate completion report for OpenCode (PM)
---

# /handoff-to-opencode - OpenCode への作業完了報告

Claude Code での作業完了時に、OpenCode（PM）への引き継ぎ報告を生成します。
Plans.md を更新し、次のアクションを明確にします。
Cursor PM への報告は **`/handoff-to-cursor`** を使用してください。

## VibeCoder Quick Reference

- 「**OpenCode に完了報告を書いて**」→ このコマンドを実行
- 「**OpenCode PM に報告**」→ このコマンドを実行
- 「**何を書けばいいかわからない**」→ 必要項目（やったこと / 変わったこと / 検証方法）をヒアリングします

## Deliverables

- 「概要 / 完了タスク / 変更ファイル / 検証結果 / リスク / 次のアクション」を **PM に伝わる形式** で1ドキュメントにまとめる
- Plans.md の該当タスクが `cc:完了` になっていることを確認・整合させる

## Steps

1. **完了タスクを特定**
   - Plans.md の該当チェックボックスを確認
   - 作業内容を要約

2. **Plans.md を更新**
   ```markdown
   # 更新前
   - [ ] タスク名 `pm:依頼中`

   # 更新後
   - [x] タスク名 `cc:完了` (YYYY-MM-DD)
   ```

3. **変更内容を把握**
   ```bash
   git status -sb
   git diff --stat
   ```

4. **CI/CD 状況を確認**（該当する場合）
   ```bash
   gh run list --limit 3
   ```

5. **下記フォーマットで報告を生成**

## Output Format

OpenCode に直接ペーストできる形式で出力してください。

```markdown
## Completion Report

### 概要
- （実施内容を 1〜3 行で）

### 完了タスク
- **タスク名**: [タスクの説明]

### 変更ファイル
| ファイル | 変更内容 |
|---------|---------|
| `path/to/file1` | [変更概要] |
| `path/to/file2` | [変更概要] |

### 検証結果
- [x] ビルド成功
- [x] テスト通過
- [x] 動作確認完了

### リスク / 注意点
- （あれば記載）

### 次のアクション（OpenCode 向け）
1. [ ] [PM が次にやるべきこと]
2. [ ] [オプション]
```

## 注意事項

- 2-Agent モード（`pm:依頼中` 検出時）で `/work` 完了後に実行される
- Solo モードでは handoff は不要（review ループのみ）
- Plans.md のマーカーは `cc:完了` を使用すること（英語マーカーは不可）
