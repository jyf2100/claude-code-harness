# Aivis Cloud API ナレーション統合

Remotion 動画にナレーション音声を追加するための統合ガイドです。

---

## 概要

[Aivis Cloud API](https://api.aivis-project.com/v1/docs) を使用して、シーンごとにナレーション音声を生成し、Remotion 動画に統合します。

## Prerequisites

- Remotion セットアップ済み（`/remotion-setup`）
- Aivis Cloud API キー（[ダッシュボード](https://hub.aivis-project.com/cloud-api/dashboard)で取得）
- Node.js 18+

## 環境変数

```bash
# .env または環境変数で設定
AIVIS_API_KEY=aivis_xxxxxxxxxxxxxx
```

---

## アーキテクチャ

```
シーン定義（ナレーションテキスト付き）
    │
    ├─[Step 1] 音声生成（Aivis Cloud API）
    │   └─ 各シーンのテキスト → WAV ファイル
    │
    ├─[Step 2] 音声配置
    │   └─ public/audio/{composition}/ に保存
    │
    └─[Step 3] Remotion 統合
        └─ Html5Audio コンポーネントで再生
```

---

## 利用可能なモデル（商用利用OK）

| モデル名 | UUID | 声質 | ライセンス |
|---------|------|------|-----------|
| **コハク** | `22e8ed77-94fe-4ef2-871f-a86f94e9a579` | 若い女性 | ACML 1.0 |
| **まい** | `e9339137-2ae3-4d41-9394-fb757a7e61e6` | 若い女性 | ACML 1.0 |
| **にせ** | `6d11c6c2-f4a4-4435-887e-23dd60f8b8dd` | 若い男性 | ACML 1.0 |
| **fumifumi** | `71e72188-2726-4739-9aa9-39567396fb2a` | 壮年男性 | ACML 1.0 |

> モデル一覧: [AivisHub](https://hub.aivis-project.com/search)

### コハクのスタイル

| Style ID | スタイル名 |
|----------|-----------|
| 0 | ノーマル |
| 1 | 嬉しい |
| 2 | せつなめ |
| 3 | 怒り |

---

## ファイル構成

```
remotion/
├── src/
│   ├── utils/
│   │   ├── aivis-client.ts       # API クライアント
│   │   └── narration-generator.ts # ナレーション生成ロジック
│   ├── hooks/
│   │   └── useNarration.ts       # ナレーション状態管理
│   ├── components/
│   │   └── NarratedScene.tsx     # 音声付きシーンラッパー
│   └── HarnessPromoV6Narrated.tsx # ナレーション付きコンポジション
└── public/
    └── audio/
        └── v6/                    # 生成された音声ファイル
            ├── hook.wav
            ├── problems.wav
            └── manifest.json
```

---

## 使用方法

### Step 1: 依存関係インストール

```bash
cd remotion
npm install
```

### Step 2: ナレーションテキスト定義

`src/utils/narration-generator.ts` でシーンごとのナレーションを定義:

```typescript
export const HARNESS_PROMO_V6_NARRATIONS: SceneNarration[] = [
  {
    sceneId: "hook",
    text: "Claude Code、使いこなせていますか？",
    startFrame: 0,
    durationInFrames: 90, // 3秒
  },
  {
    sceneId: "problems",
    text: "コンテキストが溢れる。何度も同じ指示を繰り返す。...",
    startFrame: 90,
    durationInFrames: 210,
  },
  // ...
];
```

### Step 3: 音声生成

```bash
# 環境変数を設定してナレーション生成
AIVIS_API_KEY=your_key npm run generate-narration
```

出力例:
```
=== HarnessPromoV6 ナレーション生成 ===

出力先: /path/to/remotion/public/audio/v6

[generate] hook: "Claude Code、使いこなせていますか？"
[done] hook: public/audio/v6/hook.wav
[generate] problems: "コンテキストが溢れる..."
[done] problems: public/audio/v6/problems.wav
...

生成完了: 9 ファイル
マニフェスト: public/audio/v6/manifest.json
```

### Step 4: 動画レンダリング

```bash
# ナレーション付き動画をレンダリング
npm run render:v6-narrated
```

---

## API 仕様

### エンドポイント

```
POST https://api.aivis-project.com/v1/tts/synthesize
```

### リクエスト

```json
{
  "model_uuid": "22e8ed77-94fe-4ef2-871f-a86f94e9a579",
  "text": "ナレーションテキスト",
  "use_ssml": false,
  "output_format": "wav",
  "language": "ja",
  "style_id": 2
}
```

### ヘッダー

```
Authorization: Bearer {AIVIS_API_KEY}
Content-Type: application/json
```

### レスポンス

- 成功時: 音声データ（バイナリ）
- エラー時: JSON エラーメッセージ

---

## コンポーネント詳細

### NarratedScene

既存のシーンに音声を追加するラッパー:

```tsx
import { NarratedScene } from "./components/NarratedScene";

<NarratedScene
  narration={{
    sceneId: "hook",
    audioFile: "audio/v6/hook.wav",
    startFrame: 0,
    durationInFrames: 90,
  }}
  volume={1.0}
  enableAudio={true}
>
  <HookScene />
</NarratedScene>
```

### useNarration フック

ナレーション状態を管理:

```tsx
const { currentNarration, progress, localFrame, volume } = useNarration({
  narrations: HARNESS_PROMO_V6_TIMINGS,
  volume: 1.0,
});
```

---

## package.json スクリプト

```json
{
  "scripts": {
    "generate-narration": "npx ts-node src/utils/narration-generator.ts",
    "render:v6-narrated": "remotion render src/index.ts HarnessPromoV6Narrated out/harness-promo-v6-narrated.mp4"
  }
}
```

---

## トラブルシューティング

### "AIVIS_API_KEY 環境変数が設定されていません"

```bash
# 環境変数を設定
export AIVIS_API_KEY=aivis_xxxxxx

# または .env ファイルに追加
echo "AIVIS_API_KEY=aivis_xxxxxx" >> .env
```

### 音声が動画に含まれない

1. `public/audio/` に WAV ファイルが存在するか確認
2. `staticFile()` のパスが正しいか確認
3. `Html5Audio` コンポーネントが正しくインポートされているか確認

### API エラー 404

- `model_uuid` が正しいか確認
- [AivisHub](https://hub.aivis-project.com/search) でモデルの存在を確認

### 音声が途切れる

- シーンの `durationInFrames` が音声より短い可能性
- 音声ファイルの長さを確認: `ffprobe audio/v6/hook.wav`

---

## 料金

| プラン | 料金 | 制限 |
|--------|------|------|
| 従量課金 | 440円/10,000文字 | なし |
| サブスク | 1,980円/月 | 10リクエスト/分 |

> 詳細: [Aivis Cloud API 料金](https://hub.aivis-project.com/cloud-api/)

---

## 参考リンク

- [Aivis Cloud API ドキュメント](https://api.aivis-project.com/v1/docs)
- [AivisHub モデル検索](https://hub.aivis-project.com/search)
- [Remotion Audio ドキュメント](https://www.remotion.dev/docs/media/audio)
