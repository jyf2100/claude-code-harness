---
description: コードベースから説明動画を自動生成
---

# /generate-video - 動画自動生成

コードベースを分析し、プロダクトデモ・アーキテクチャ解説・リリースノート動画を自動生成します。

## VibeCoder Quick Reference

- "**動画作りたい**" → このコマンド
- "**プロダクト紹介動画**" → このコマンド
- "**リリース動画**" → このコマンド
- "**デモ動画**" → このコマンド

## Prerequisites

- Remotion セットアップ済み（未設定の場合は `/remotion-setup` を案内）
- Node.js 18+

---

## Usage

```bash
/generate-video
```

**引数なし**。インタラクティブフローで進行します。

---

## Execution Flow

```
/generate-video
    │
    ├─[Step 1] Remotion セットアップ確認
    │   └─ 未設定 → /remotion-setup を案内して終了
    │
    ├─[Step 2] 分析済みかチェック
    │   └─ 未分析 → analyzer.md で分析実行
    │
    ├─[Step 3] シナリオ提案 + ユーザー確認
    │   └─ planner.md でシーン構成を提案
    │   └─ AskUserQuestion で承認/編集/キャンセル
    │
    └─[Step 4] 並列生成
        └─ generator.md で Task tool 並列起動
        └─ 統合 + レンダリング
```

---

## Step 1: Remotion セットアップ確認

```bash
# remotion ディレクトリまたは依存関係を確認
ls remotion/ 2>/dev/null || grep -q '"remotion"' package.json 2>/dev/null
```

**未設定の場合**:

> ⚠️ **Remotion が未セットアップです**
>
> 動画生成には Remotion が必要です。
> `/remotion-setup` を実行してセットアップしてください。

→ **コマンド終了**

---

## Step 2: コードベース分析

**See**: [skills/video/references/analyzer.md](../../skills/video/references/analyzer.md)

分析対象:
- フレームワーク検出（Next.js, React, Vue, etc.）
- 主要機能検出（認証, 決済, ダッシュボード, API）
- UIコンポーネント数
- プロジェクト資産（package.json, README, Plans.md, CHANGELOG）
- 最近の変更点

**出力例**:

```
📊 プロジェクト分析完了

| 項目 | 結果 |
|------|------|
| プロジェクト名 | MyApp |
| フレームワーク | Next.js 14 |
| ページ数 | 12 |
| 検出機能 | 認証, ダッシュボード, API |

🎬 推奨動画タイプ: プロダクトデモ
   理由: UIコンポーネントの追加が検出されました
```

---

## Step 3: シナリオ提案 + ユーザー確認

**See**: [skills/video/references/planner.md](../../skills/video/references/planner.md)

**シナリオ提案**:

```markdown
🎬 シナリオプラン

**動画タイプ**: プロダクトデモ
**合計時間**: 45秒

| # | シーン | 時間 | 内容 | ソース |
|---|--------|------|------|--------|
| 1 | イントロ | 5秒 | MyApp - タスク管理を簡単に | テンプレート |
| 2 | 認証フロー | 15秒 | ログイン画面のデモ | Playwright |
| 3 | ダッシュボード | 20秒 | メイン機能の紹介 | Playwright |
| 4 | CTA | 5秒 | myapp.com | テンプレート |
```

**AskUserQuestion**:

```
question: "このシナリオで動画を生成しますか？"
header: "シナリオ確認"
options:
  - label: "OK、生成開始"
    description: "このシーン構成で動画を生成します"
  - label: "編集したい"
    description: "シーンの追加/削除/変更を行います"
  - label: "キャンセル"
    description: "動画生成を中止します"
```

### 編集モード

「編集したい」を選択した場合:

```
📝 シナリオ編集

以下の指示で編集できます：
- 「機能Xのデモを追加」
- 「シーン2を削除」
- 「イントロを3秒に短縮」
- 「シーン2と3を入れ替え」
- 「これでOK」で確定

何を編集しますか？
```

---

## Step 4: 並列生成

**See**: [skills/video/references/generator.md](../../skills/video/references/generator.md)

### 並列数決定

| シーン数 | 並列数 |
|---------|--------|
| 1-2 | 1-2 |
| 3-4 | 3 |
| 5+ | 5 |

### Task Tool で並列起動

各シーンに対して `video-scene-generator` サブエージェントを起動:

```
Task:
  subagent_type: "video-scene-generator"
  run_in_background: true
  prompt: |
    以下のシーンを Remotion コンポジションとして生成してください。

    シーン情報:
    - ID: {scene.id}
    - 名前: {scene.name}
    - 時間: {scene.duration}秒
    - テンプレート: {scene.template}
    - 内容: {scene.content}
```

### 進捗モニタリング

```
🎬 並列生成中... (2/4 完了)

├── [Agent 1] intro ✅ (5秒)
├── [Agent 2] auth-demo ✅ (15秒)
├── [Agent 3] dashboard ⏳ 生成中...
└── [Agent 4] cta 🔜 待機中
```

### 統合 + レンダリング

1. シーン結合（Series/TransitionSeries）
2. トランジション追加（fade）
3. 最終レンダリング

```bash
npx remotion render remotion/index.ts FullVideo out/video.mp4
```

---

## 完了報告

```markdown
✅ **動画生成完了**

📁 **出力ファイル**:
- `out/video.mp4` (45秒, 1080p, 12.3MB)

📊 **生成統計**:
| 項目 | 値 |
|------|-----|
| シーン数 | 4 |
| 並列エージェント数 | 3 |
| 生成時間 | 45秒 |
| レンダリング時間 | 30秒 |

🎬 **プレビュー**:
- Studio: `npm run remotion` → http://localhost:3000
- ファイル: `open out/video.mp4`

**次のステップ**:
- 編集: Remotion Studio で微調整
- 再生成: `/generate-video` で別のシナリオを試す
```

---

## 動画タイプ別フロー

### プロダクトデモ

```
イントロ → 機能紹介×N → UIデモ×N → CTA
```

- Playwright で実際のUI操作をキャプチャ
- アプリが起動している必要あり

### アーキテクチャ解説

```
イントロ → 概要図 → 詳細解説×N → データフロー → CTA
```

- Mermaid 図をアニメーション化
- `.claude/memory/decisions.md` から技術的背景を抽出

### リリースノート

```
イントロ → バージョン → 変更点リスト → Before/After → 新機能デモ → CTA
```

- CHANGELOG.md から変更点を抽出
- 新機能があれば Playwright デモ

---

## エラーハンドリング

### Remotion 未セットアップ

```
⚠️ Remotion が未セットアップです
→ /remotion-setup を実行してください
```

### アプリ未起動（Playwrightシーン）

```
⚠️ アプリが起動していません

Playwright によるUIキャプチャには、アプリが起動している必要があります。

対処:
1. `npm run dev` でアプリを起動
2. 再度 `/generate-video` を実行

または、UIデモシーンをスキップしますか？
```

### レンダリング失敗

```
⚠️ レンダリングエラー

原因: メモリ不足

対処:
1. 並列数を減らす
2. 解像度を下げる（720p）
3. シーンを分割
```

---

## Related Commands

- `/remotion-setup` - Remotion 環境セットアップ

---

## Technical References

- [Remotion公式ドキュメント](https://www.remotion.dev/docs)
- [Remotion Agent Skills](https://www.remotion.dev/docs/ai/skills)
- [Playwright MCP](https://github.com/anthropics/mcp-server-playwright)
