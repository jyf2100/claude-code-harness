# Changelog

このプロジェクトのすべての注目すべき変更は、このファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [Semantic Versioning](https://semver.org/spec/v2.0.0.html) に準拠しています。

> **📝 記載ルール**: ユーザー体験に影響する変更を中心に記載。内部修正は簡潔に。

## [Unreleased]

---

## [2.16.17] - 2026-02-03

### 🎯 あなたにとって何が変わるか

**スキルの使い方ヒントがオートコンプリートに表示されるようになりました**

| Before | After |
|--------|-------|
| `/harness-review` | `/harness-review [code|plan|scope]` |
| `/troubleshoot` | `/troubleshoot [build|test|runtime]` |

### Added

- 17スキルに使い方ヒント（`argument-hint`）を追加
- セッション間通知機能（複数セッション連携時に便利）

### Internal

- CI/テスト/ドキュメントを Skills 移行後の構造に更新

---

## [2.16.14] - 2026-02-02

### 🎯 あなたにとって何が変わるか

**実装を依頼すると、自動的に Plans.md に登録されます**

| Before | After |
|--------|-------|
| 口頭依頼が Plans.md に残らない | すべてのタスクが Plans.md に記録 |
| 進捗が追いにくい | `/sync-status` で全体把握可能 |

---

## [2.16.11] - 2026-02-02

### 🎯 あなたにとって何が変わるか

**コマンドがスキルに統合されました（使い方は変わりません）**

| Before | After |
|--------|-------|
| `/work`, `/harness-review` がコマンドとして存在 | 同じ名前でスキルとして動作 |
| 内部スキル (impl, verify) がメニューに表示 | 非表示に（ノイズ軽減） |
| `dev-browser`, `docs`, `video` | `agent-browser`, `notebookLM`, `generate-video` に改名 |

### Internal

- README を VibeCoder 向けにリライト（トラブルシューティング・アンインストール追加）
- CI スクリプトを Skills 構造に対応

---

## [2.16.5] - 2026-01-31

### 🎯 あなたにとって何が変わるか

**`/generate-video` が AI 画像生成・BGM・字幕・視覚効果に対応**

| Before | After |
|--------|-------|
| 画像素材は手動で用意 | AI が自動生成（Nano Banana Pro） |
| BGM・字幕なし | 著作権フリー BGM、日本語字幕対応 |
| 基本トランジションのみ | GlitchText, Particles 等のエフェクト |

---

## [2.16.0] - 2026-01-31

### 🎯 あなたにとって何が変わるか

**`/ultrawork` で rm -rf と git push の確認回数が減りました（実験的機能）**

| Before | After |
|--------|-------|
| rm -rf で毎回確認 | 計画時に許可したパスのみ自動承認 |
| git push で毎回確認 | ultrawork 中は自動承認（force除く） |

---

## [2.15.0] - 2026-01-26

### 🎯 あなたにとって何が変わるか

**OpenCode との完全互換モードを追加**

| Before | After |
|--------|-------|
| OpenCode 向けに別途設定が必要 | `/setup-opencode` で自動セットアップ |
| skills/ 構造が異なる | 同一スキルが両環境で動作 |

---

## [2.14.0] - 2026-01-16

### 🎯 あなたにとって何が変わるか

**`/work --full` で並列タスク実行が可能に**

| Before | After |
|--------|-------|
| タスクを1つずつ実行 | `--parallel 3` で最大3並列実行 |
| 完了報告を手動で確認 | 各 worker が自律的にセルフレビュー |

---

## [2.13.0] - 2026-01-14

### 🎯 あなたにとって何が変わるか

**Codex MCP による並列レビューを追加**

| Before | After |
|--------|-------|
| Claude 単体でレビュー | Codex 4エキスパートが並列でレビュー |
| 一度に1観点 | セキュリティ/品質/パフォーマンス/a11y を同時チェック |

---

## [2.12.0] - 2026-01-10

### Added

- **Harness UI ダッシュボード** (`/harness-ui`) - ブラウザで進捗確認
- **ブラウザ自動化** (`agent-browser`) - ページ操作・スクリーンショット

---

## [2.11.0] - 2026-01-08

### Added

- **セッション間メッセージング** - 複数 Claude Code セッション間でメッセージ送受信
- **CRUD 自動生成** (`crud` スキル) - Zod バリデーション付きエンドポイント生成

---

## [2.10.0] - 2026-01-04

### Added

- **LSP 統合** - Go-to-definition, Find-references で正確なコード理解
- **AST-Grep 統合** - 構造的なコードパターン検索

---

## 過去バージョン

v2.9.x 以前の詳細は [GitHub Releases](https://github.com/Chachamaru127/claude-code-harness/releases) を参照してください。
