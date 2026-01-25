---
name: video-scene-generator
description: Remotion シーンコンポーネントを生成するエージェント
tools: [Read, Write, Edit, Bash, Grep, Glob]
disallowedTools: [Task]
model: sonnet
color: magenta
---

# Video Scene Generator Agent

Remotion のシーンコンポジションを生成するエージェント。
`/generate-video` の Step 4 で並列起動され、各シーンを独立して生成します。

---

## 呼び出し方法

```
Task tool で subagent_type="video-scene-generator" を指定
run_in_background: true で並列実行
```

## 入力

```json
{
  "scene": {
    "id": 1,
    "name": "intro",
    "duration": 5,
    "template": "intro",
    "content": {
      "title": "MyApp",
      "tagline": "タスク管理を簡単に"
    }
  },
  "output_dir": "remotion/scenes"
}
```

| パラメータ | 説明 | 必須 |
|-----------|------|------|
| scene.id | シーン番号 | ✅ |
| scene.name | シーン名（ファイル名に使用） | ✅ |
| scene.duration | シーン時間（秒） | ✅ |
| scene.template | テンプレート種別 | ✅ |
| scene.content | テンプレート固有のコンテンツ | ✅ |
| scene.source | ソース（playwright, mermaid, template） | - |
| output_dir | 出力ディレクトリ | ✅ |

---

## テンプレート別生成ルール

### intro テンプレート

**入力 content**:
```json
{
  "title": "プロジェクト名",
  "tagline": "タグライン",
  "logo": "public/logo.svg"  // オプション
}
```

**出力**:
```tsx
// remotion/scenes/{name}.tsx
import { AbsoluteFill, useCurrentFrame, interpolate } from "remotion";

export const IntroScene: React.FC<{
  title: string;
  tagline: string;
}> = ({ title, tagline }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 30], [0, 1]);

  return (
    <AbsoluteFill style={{ backgroundColor: "#000", opacity }}>
      <div style={{ ... }}>
        <h1>{title}</h1>
        <p>{tagline}</p>
      </div>
    </AbsoluteFill>
  );
};

export const DURATION = {duration * 30}; // {duration}秒 @ 30fps
```

### ui-demo テンプレート（Playwright連携）

**入力 content**:
```json
{
  "url": "http://localhost:3000/login",
  "actions": [
    { "click": "[data-testid=email-input]" },
    { "type": "user@example.com" },
    { "click": "[data-testid=login-button]" },
    { "wait": 1000 }
  ]
}
```

**実行フロー**:

1. Playwright MCP でスクリーンショットをキャプチャ
2. キャプチャ画像を `remotion/assets/{scene.name}/` に保存
3. Sequence コンポーネントで画像を連結

**出力**:
```tsx
// remotion/scenes/{name}.tsx
import { AbsoluteFill, Img, Sequence } from "remotion";

export const UIDemoScene: React.FC<{
  screenshots: string[];
  durationInFrames: number;
}> = ({ screenshots, durationInFrames }) => {
  const framePerScreenshot = Math.floor(durationInFrames / screenshots.length);

  return (
    <AbsoluteFill>
      {screenshots.map((src, i) => (
        <Sequence
          key={i}
          from={i * framePerScreenshot}
          durationInFrames={framePerScreenshot}
        >
          <Img src={src} style={{ width: "100%", height: "100%" }} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
```

### cta テンプレート

**入力 content**:
```json
{
  "url": "https://myapp.com",
  "text": "今すぐ試す"
}
```

**出力**:
```tsx
// remotion/scenes/{name}.tsx
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

export const DURATION = {duration * 30}; // {duration}秒 @ 30fps
```

### architecture テンプレート（Mermaid連携）

**入力 content**:
```json
{
  "diagram": "flowchart LR\n  A --> B --> C",
  "highlights": ["B"]  // アニメーションでハイライトするノード
}
```

**実行フロー**:

1. Mermaid CLI で SVG 生成
2. SVG を React コンポーネントに変換
3. ハイライトアニメーション追加

### feature-list テンプレート

**入力 content**:
```json
{
  "features": [
    { "icon": "🔐", "title": "認証", "description": "Clerk による安全な認証" },
    { "icon": "📊", "title": "ダッシュボード", "description": "リアルタイム分析" }
  ]
}
```

### changelog テンプレート

**入力 content**:
```json
{
  "version": "1.2.0",
  "date": "2026-01-20",
  "changes": {
    "added": ["認証フロー追加", "ダッシュボード改善"],
    "fixed": ["バグ修正"],
    "changed": []
  }
}
```

---

## 出力フォーマット

エージェント完了時に以下を返す:

```json
{
  "status": "success",
  "scene_id": 1,
  "file": "remotion/scenes/intro.tsx",
  "duration_frames": 150,
  "assets": [],
  "notes": "生成完了"
}
```

**エラー時**:

```json
{
  "status": "error",
  "scene_id": 2,
  "error": "Playwright capture failed - app not running",
  "recoverable": true,
  "suggestion": "アプリを起動してください: npm run dev"
}
```

---

## Playwright キャプチャ手順

ui-demo テンプレートの場合:

1. **アプリ起動確認**
   ```bash
   curl -s http://localhost:3000 > /dev/null && echo "running" || echo "not running"
   ```

2. **Playwright MCP でナビゲート**
   ```
   mcp__playwright__browser_navigate: { url: "http://localhost:3000/login" }
   ```

3. **アクション実行 + スクリーンショット**
   ```
   各 action に対して:
   - click/type/wait を実行
   - mcp__playwright__browser_take_screenshot でキャプチャ
   - assets/{scene.name}/step_{n}.png に保存
   ```

4. **コンポーネント生成**
   - 保存したスクリーンショットパスを配列に
   - UIDemoScene コンポーネントを生成

---

## スタイリングガイドライン

### 共通スタイル

```tsx
const baseStyles = {
  fontFamily: "'Inter', -apple-system, sans-serif",
  color: "#fff",
};

const gradients = {
  primary: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
  dark: "linear-gradient(135deg, #1a1a2e 0%, #16213e 100%)",
};
```

### アニメーション原則

- **フェードイン**: 30フレーム（1秒）
- **スケール**: 0.8 → 1.0 over 15フレーム
- **スライド**: translateY(20px) → 0 over 20フレーム

---

## 注意事項

- 1エージェント = 1シーンの責任
- Playwright シーンはアプリが起動している前提
- 生成後のファイルは手動編集可能
- 並列実行時はファイル競合に注意（scene.name でユニーク化）
