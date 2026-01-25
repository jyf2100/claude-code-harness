# Video Generator - 並列シーン生成エンジン

シナリオに基づいて、マルチエージェントで並列にシーンを生成します。

---

## 概要

`/generate-video` の Step 3 で実行される生成エンジンです。
planner.md のシナリオを受けて、各シーンを並列で生成し、最終的に統合します。

## 入力

planner.md からのシナリオ:
- シーンリスト（id, name, duration, template, content）
- 動画設定（resolution, fps）

## 並列生成アーキテクチャ

```
シナリオ（N シーン）
    │
    ├─[並列数決定]
    │   └─ min(シーン数, 5) を並列数とする
    │
    ├─[並列生成フェーズ]
    │   ├── Agent 1: シーン 1 生成
    │   ├── Agent 2: シーン 2 生成
    │   ├── Agent 3: シーン 3 生成
    │   └── ... (max 5 並列)
    │
    ├─[統合フェーズ]
    │   ├── シーン結合
    │   ├── トランジション追加
    │   └── 音声同期（オプション）
    │
    └─[レンダリングフェーズ]
        └── 最終出力（mp4/webm/gif）
```

---

## 並列数決定ロジック

| シーン数 | 並列数 | 理由 |
|---------|--------|------|
| 1-2 | 1-2 | オーバーヘッドが利益を上回る |
| 3-4 | 3 | 最適なバランス |
| 5+ | 5 | これ以上はリソース競合 |

**実装**:
```javascript
const parallelCount = Math.min(scenes.length, 5);
```

---

## Task Tool による並列起動

### シーン生成エージェント起動

```
各シーンに対して Task tool を起動:

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

    出力先: remotion/scenes/{scene.name}.tsx

    完了したら以下を報告:
    - ファイルパス
    - 実際の duration (フレーム数)
    - 使用したコンポーネント
```

### 進捗モニタリング

```
🎬 並列生成中... (3/5 完了)

├── [Agent 1] intro ✅ (3秒)
├── [Agent 2] auth-demo ✅ (12秒)
├── [Agent 3] dashboard ⏳ 生成中...
├── [Agent 4] features 🔜 待機中
└── [Agent 5] cta 🔜 待機中
```

### 結果収集

```
TaskOutput で各エージェントの結果を収集:

結果:
  - scene_id: 1
    file: "remotion/scenes/intro.tsx"
    duration_frames: 150
    status: "success"

  - scene_id: 2
    file: "remotion/scenes/auth-demo.tsx"
    duration_frames: 450
    status: "success"
    notes: "Playwright capture included"
```

---

## シーン生成テンプレート

### intro テンプレート

```tsx
// remotion/scenes/intro.tsx
import { AbsoluteFill, useCurrentFrame, interpolate } from "remotion";
import { FadeIn } from "../components/FadeIn";

export const IntroScene: React.FC<{
  title: string;
  tagline: string;
}> = ({ title, tagline }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 30], [0, 1]);

  return (
    <AbsoluteFill style={{ backgroundColor: "#000", opacity }}>
      <FadeIn durationInFrames={30}>
        <h1>{title}</h1>
        <p>{tagline}</p>
      </FadeIn>
    </AbsoluteFill>
  );
};

export const DURATION = 150; // 5秒 @ 30fps
```

### ui-demo テンプレート（Playwright連携）

```tsx
// remotion/scenes/ui-demo.tsx
import { AbsoluteFill, Img, Sequence } from "remotion";

export const UIDemoScene: React.FC<{
  screenshots: string[];
  duration: number;
}> = ({ screenshots, duration }) => {
  const framePerScreenshot = Math.floor(duration / screenshots.length);

  return (
    <AbsoluteFill>
      {screenshots.map((src, i) => (
        <Sequence from={i * framePerScreenshot} durationInFrames={framePerScreenshot}>
          <Img src={src} style={{ width: "100%", height: "100%" }} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
```

### cta テンプレート

```tsx
// remotion/scenes/cta.tsx
import { AbsoluteFill, useCurrentFrame, interpolate } from "remotion";

export const CTAScene: React.FC<{
  url: string;
  text: string;
}> = ({ url, text }) => {
  const frame = useCurrentFrame();
  const scale = interpolate(frame, [0, 15], [0.8, 1], {
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ backgroundColor: "#1a1a1a" }}>
      <div style={{ transform: `scale(${scale})` }}>
        <h2>{text}</h2>
        <p>{url}</p>
      </div>
    </AbsoluteFill>
  );
};

export const DURATION = 150; // 5秒 @ 30fps
```

---

## 統合フェーズ

### シーン結合

```tsx
// remotion/FullVideo.tsx
import { Composition, Series } from "remotion";
import { IntroScene } from "./scenes/intro";
import { UIDemoScene } from "./scenes/ui-demo";
import { CTAScene } from "./scenes/cta";

export const FullVideo: React.FC = () => {
  return (
    <Series>
      <Series.Sequence durationInFrames={150}>
        <IntroScene title="MyApp" tagline="タスク管理を簡単に" />
      </Series.Sequence>
      <Series.Sequence durationInFrames={450}>
        <UIDemoScene screenshots={[...]} duration={450} />
      </Series.Sequence>
      <Series.Sequence durationInFrames={150}>
        <CTAScene url="https://myapp.com" text="今すぐ試す" />
      </Series.Sequence>
    </Series>
  );
};
```

### トランジション追加

```tsx
// トランジションコンポーネント
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";

<TransitionSeries>
  <TransitionSeries.Sequence durationInFrames={150}>
    <IntroScene {...} />
  </TransitionSeries.Sequence>
  <TransitionSeries.Transition
    presentation={fade()}
    timing={linearTiming({ durationInFrames: 15 })}
  />
  <TransitionSeries.Sequence durationInFrames={450}>
    <UIDemoScene {...} />
  </TransitionSeries.Sequence>
</TransitionSeries>
```

---

## レンダリングフェーズ

### コマンド実行

```bash
# MP4 レンダリング
npx remotion render remotion/index.ts FullVideo out/video.mp4

# GIF レンダリング（短い動画向け）
npx remotion render remotion/index.ts FullVideo out/video.gif

# WebM レンダリング（Web向け）
npx remotion render remotion/index.ts FullVideo out/video.webm --codec=vp8
```

### 出力オプション

| フォーマット | 推奨用途 | オプション |
|-------------|---------|-----------|
| MP4 | 汎用、SNS | `--codec=h264` |
| WebM | Web埋め込み | `--codec=vp8` |
| GIF | 短いループ | 15秒以下推奨 |

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
```

---

## エラーハンドリング

### シーン生成失敗

```
⚠️ シーン生成エラー

シーン「auth-demo」の生成に失敗しました。
原因: Playwright キャプチャ失敗 - アプリが起動していません

対処:
1. アプリを起動してください: `npm run dev`
2. 再生成: 「auth-demo を再生成」
3. スキップ: 「このシーンをスキップ」
```

### レンダリング失敗

```
⚠️ レンダリングエラー

原因: メモリ不足

対処:
1. 並列数を減らす: `--concurrency 2`
2. 解像度を下げる: 720p で再試行
3. シーンを分割: 長いシーンを短く分割
```

---

## Notes

- 並列生成は独立したシーンに対してのみ有効
- Playwright キャプチャは事前にアプリが起動している必要がある
- 大きな動画（3分以上）は分割レンダリングを推奨
