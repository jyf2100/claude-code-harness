---
name: video
description: "Generates product demo videos, architecture explanations, and release note videos. Use when user mentions video generation, product demos, or visual documentation. Requires Remotion setup."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task", "AskUserQuestion", "WebFetch"]
---

# Video Generation Skills

プロダクト説明動画の自動生成を担当するスキル群です。

---

## 概要

`/generate-video` コマンドの内部で使用されるスキルです。
コードベース分析 → シナリオ提案 → 並列生成のフローを実行します。

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **コードベース分析** | See [references/analyzer.md](references/analyzer.md) |
| **シナリオプランニング** | See [references/planner.md](references/planner.md) |
| **並列シーン生成** | See [references/generator.md](references/generator.md) |

## Prerequisites

- Remotion がセットアップ済み（`/remotion-setup`）
- Node.js 18+

## `/generate-video` フロー

```
/generate-video
    │
    ├─[Step 1] 分析（analyzer.md）
    │   ├─ フレームワーク検出
    │   ├─ 主要機能検出
    │   ├─ UIコンポーネント検出
    │   └─ プロジェクト資産解析（Plans.md, CHANGELOG等）
    │
    ├─[Step 2] シナリオ提案（planner.md）
    │   ├─ 動画タイプ自動判定
    │   ├─ シーン構成提案
    │   └─ ユーザー確認
    │
    └─[Step 3] 並列生成（generator.md）
        ├─ シーン並列生成（Task tool）
        ├─ 統合 + トランジション
        └─ 最終レンダリング
```

## 実行手順

1. ユーザーが `/generate-video` を実行
2. Remotion セットアップ確認
3. `analyzer.md` でコードベース分析
4. `planner.md` でシナリオ提案 + ユーザー確認
5. `generator.md` で並列生成
6. 完了報告

## 動画タイプ

| タイプ | 説明 | 自動判定条件 |
|--------|------|-------------|
| **プロダクトデモ** | UIフローを紹介 | 新規プロジェクト、UI変更 |
| **アーキテクチャ解説** | システム構成を可視化 | 大きな構造変更 |
| **リリースノート** | 変更点を動画化 | リリース直後、CHANGELOG更新 |
| **複合** | 複数タイプを組み合わせ | 複数条件に該当 |

## シーンテンプレート

| シーン | 推奨時間 | 内容 |
|--------|----------|------|
| イントロ | 3-5秒 | ロゴ + タグライン |
| 機能デモ | 10-30秒 | Playwrightキャプチャ |
| アーキテクチャ図 | 10-20秒 | Mermaid → アニメーション |
| CTA | 3-5秒 | URL + 連絡先 |

## Notes

- Remotion未セットアップの場合は `/remotion-setup` を案内
- 並列生成数はシーン数に応じて自動調整（max 5）
- 生成された動画は `out/` ディレクトリに出力
