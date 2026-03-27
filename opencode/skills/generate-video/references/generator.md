# Video Generator - 并行场景生成引擎

基于场景配置，使用多代理并行生成场景。

---

## 概述

在 `/generate-video` 的 Step 3 中执行的生成引擎。
接收 planner.md 的场景配置，并行生成各场景，最后进行整合。

## 输入

来自 planner.md 的场景配置:
- 场景列表（id, name, duration, template, content）
- 视频设置（resolution, fps）

## 并行生成架构

```
场景配置（N 个场景）
    │
    ├─[素材生成阶段] ← NEW
    │   ├── 各场景的素材必要判定
    │   ├── 用 Nano Banana Pro 生成图像（2张: 2次请求）
    │   ├── Claude 进行质量判定
    │   └─ OK → 采用 / NG → 重新生成（最多3次）
    │
    ├─[并行数决定]
    │   └─ min(场景数, 5) 作为并行数
    │
    ├─[并行生成阶段]
    │   ├── Agent 1: 场景 1 生成
    │   ├── Agent 2: 场景 2 生成
    │   ├── Agent 3: 场景 3 生成
    │   └── ... (max 5 并行)
    │
    ├─[整合阶段]
    │   ├── 场景连接
    │   ├── 添加过渡效果
    │   └─ 音频同步（可选）
    │
    └─[渲染阶段]
        └── 最终输出（mp4/webm/gif）
```

---

## 素材生成阶段（Nano Banana Pro）

在场景生成前，自动生成所需的素材图像。

### 素材必要判定

| 场景类型 | 素材必要 | 原因 |
|-------------|---------|------|
| intro | ✅ 必要 | Logo、标题卡片 |
| cta | ✅ 必要 | 行动号召横幅 |
| architecture | ✅ 必要 | 概念图、图表 |
| ui-demo | ❌ 不要 | 使用 Playwright 截图 |
| changelog | ❌ 不要 | 基于文本 |

### 判定逻辑

```javascript
const needsGeneratedAsset = (scene) => {
  // 有现有素材时跳过
  if (scene.existingAssets?.length > 0) return false;

  // Playwright 截图对象跳过
  if (scene.template === 'ui-demo') return false;

  // 基于文本的场景跳过
  if (scene.template === 'changelog') return false;

  // 其他为生成对象
  return ['intro', 'cta', 'architecture', 'feature-highlight'].includes(scene.template);
};
```

### 生成流程

```
对每个场景:
    │
    ├── needsGeneratedAsset(scene) = false
    │   └─ 跳过 → 进入下一个场景
    │
    └── needsGeneratedAsset(scene) = true
        │
        ├── [Step 1] 生成提示词
        │   └─ 从场景信息 + 品牌信息构建提示词
        │
        ├── [Step 2] 图像生成（2张: 2次请求）
        │   └─ 调用 Nano Banana Pro API（generateContent × 2）
        │   └─ → 参考 image-generator.md
        │
        ├── [Step 3] 质量判定
        │   └─ Claude 评估并选择 2 张图像
        │   └─ → 参考 image-quality-check.md
        │
        └── [Step 4] 结果处理
            ├── 成功 → out/assets/generated/{scene_name}.png
            └── 失败 → 重新生成（最多3次）或回退
```

### 生成图像的保存位置

```
out/
└── assets/
    └── generated/
        ├── intro.png
        ├── cta.png
        ├── architecture.png
        └── feature-highlight.png
```

### 整合到场景中

生成的图像会传递给场景生成代理:

```
Task:
  subagent_type: "video-scene-generator"
  prompt: |
    场景信息:
    - 名称: intro
    - 模板: intro
    - 生成图像: out/assets/generated/intro.png  ← 添加

    请将生成图像作为背景或主要元素使用。
```

### 详细文档

- [image-generator.md](./image-generator.md) - API 调用、提示词设计
- [image-quality-check.md](./image-quality-check.md) - 质量判定逻辑

---

## 并行数决定逻辑

| 场景数 | 并行数 | 原因 |
|---------|--------|------|
| 1-2 | 1-2 | 开销超过收益 |
| 3-4 | 3 | 最佳平衡 |
| 5+ | 5 | 更多会导致资源竞争 |

**实现**:
```javascript
const parallelCount = Math.min(scenes.length, 5);
```

---

## Task Tool 并行 JSON 生成

### 新的生成流程（JSON-schema 驱动）

```
场景配置（scenario.json）
    ↓
┌─────────────────────────────────────────────┐
│     Task 并行启动（各场景 → JSON 输出）      │
├─────────────────────────────────────────────┤
│ Agent 1 → scenes/intro.json                 │
│ Agent 2 → scenes/auth-demo.json             │
│ Agent 3 → scenes/dashboard.json             │
│ Agent 4 → scenes/features.json              │
│ Agent 5 → scenes/cta.json                   │
└─────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────┐
│         scenes/*.json → 合并                 │
├─────────────────────────────────────────────┤
│ - 按 section_id + order 排序               │
│ - 竞争检测（相同 scene_id = Critical error） │
│ - 缺失检测（段落中无场景）         │
└─────────────────────────────────────────────┘
    ↓
video-script.json（全场景整合）
    ↓
Remotion rendering
```

### 场景生成代理启动（JSON 输出）

```
对每个场景启动 Task tool:

Task:
  subagent_type: "video-scene-generator"
  run_in_background: true
  prompt: |
    请按照 scene.schema.json 生成以下场景的 JSON。

    场景信息:
    - scene_id: {scene.id}
    - section_id: {section.id}
    - order: {scene.order} （段落内顺序）
    - type: {scene.type}
    - duration_ms: {scene.duration_ms}
    - content: {scene.content}

    输出位置: out/video-{date}-{id}/scenes/{scene_id}.json

    必填项:
    - scene_id, section_id, order, type, content
    - content.duration_ms（考虑音频长度 + 余量）
    - direction（transition, emphasis, background, timing）
    - assets（使用的图像·音频文件）

    验证:
    ```bash
    node scripts/validate-scene.js out/video-{date}-{id}/scenes/{scene_id}.json
    ```

    完成报告:
    - 文件路径
    - 验证结果（PASS/FAIL）
    - 如有警告请报告
```

### 进度监控

```
🎬 并行 JSON 生成中... (3/5 完成)

├── [Agent 1] intro.json ✅ PASS
├── [Agent 2] auth-demo.json ✅ PASS
├── [Agent 3] dashboard.json ⏳ 生成中...
├── [Agent 4] features.json 🔜 等待中
└── [Agent 5] cta.json 🔜 等待中
```

### 结果收集（JSON）

```
用 TaskOutput 收集各代理的结果:

结果:
  - scene_id: "intro"
    file: "out/video-20260202-001/scenes/intro.json"
    validation: "PASS"
    status: "success"

  - scene_id: "auth-demo"
    file: "out/video-20260202-001/scenes/auth-demo.json"
    validation: "PASS"
    status: "success"
    warnings: ["duration_ms 可能短于音频长度"]
```

### JSON 输出规范

**输出文件**: `out/video-{date}-{id}/scenes/{scene_id}.json`

**Schema**: `schemas/scene.schema.json`

**必填字段**:
```json
{
  "scene_id": "intro",
  "section_id": "opening",
  "order": 0,
  "type": "intro",
  "content": {
    "title": "MyApp",
    "subtitle": "让任务管理变得简单",
    "duration_ms": 5000
  },
  "direction": {
    "transition": {
      "in": "fade",
      "out": "fade",
      "duration_ms": 500
    },
    "emphasis": {
      "level": "high"
    },
    "background": {
      "type": "gradient",
      "value": "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"
    }
  },
  "assets": [
    {
      "type": "image",
      "source": "assets/generated/intro.png",
      "generated": true
    }
  ]
}
```

### 合并阶段

所有代理完成后，执行 `scripts/merge-scenes.js`:

```bash
node scripts/merge-scenes.js out/video-20260202-001/
```

**处理内容**:
1. 读取 `scenes/*.json`
2. 按 `section_id` + `order` 排序
3. 竞争检测（相同 `scene_id` → Critical error）
4. 缺失检测（段落中无场景 → Critical error）
5. 生成 `video-script.json`

**输出**: `out/video-20260202-001/video-script.json`

**格式**:
```json
{
  "scenes": [
    { "scene_id": "intro", "section_id": "opening", "order": 0, ... },
    { "scene_id": "hook", "section_id": "opening", "order": 1, ... },
    { "scene_id": "demo", "section_id": "main", "order": 0, ... }
  ],
  "metadata": {
    "total_duration_ms": 180000,
    "scene_count": 12,
    "generated_at": "2026-02-02T12:34:56Z"
  }
}
```

---

## 场景生成模板

### intro 模板

```tsx
// remotion/src/scenes/intro.tsx
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

### ui-demo 模板（Playwright 联动）

```tsx
// remotion/src/scenes/ui-demo.tsx
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

### cta 模板

```tsx
// remotion/src/scenes/cta.tsx
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

## 音频同步规则（重要）

生成带旁白的视频时，必须遵守以下规则。

### 1. 事先确认音频文件长度

```bash
# 确认各音频文件的长度
for f in public/audio/*.wav; do
  name=$(basename "$f" .wav)
  dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$f")
  frames=$(echo "$dur * 30" | bc | cut -d. -f1)
  echo "$name: ${dur}秒 = ${frames}帧"
done
```

### 2. 场景长度计算公式

```
场景长度 = 1秒等待(30f) + 音频长度 + 过渡前余量(20f以上)
```

| 要素 | 帧数 | 说明 |
|------|-----------|------|
| 1秒等待 | 30f | 场景开始后，视觉上稳定后再开始音频 |
| 音频长度 | 可变 | 事先用 ffprobe 确认 |
| 余量 | 20f以上 | 过渡开始前音频结束 |

### 3. 音频开始时机

```
音频开始 = 场景开始帧 + 30帧（1秒等待）
```

### 4. 场景开始帧计算（使用 TransitionSeries 时）

```
场景开始帧 = 前一场景开始 + 前一场景长度 - 过渡长度
```

**示例（过渡 15 帧时）**:
```
hook:       0
problem:    175 - 15 = 160
solution:   160 + 415 - 15 = 560
workPlan:   560 + 340 - 15 = 885
...
```

### 5. 实现模板

```tsx
const SCENE_DURATIONS = {
  hook: 175,      // 30 + 121(音频) + 24(余量)
  problem: 415,   // 30 + 360(音频) + 25(余量)
  solution: 340,  // 30 + 286(音频) + 24(余量)
  // ...
};
const TRANSITION = 15;

// 场景开始帧（累计计算）
// hook:0, problem:160, solution:560, ...

const audioTimings = {
  hook: 30,       // 场景0 + 30
  problem: 190,   // 场景160 + 30
  solution: 590,  // 场景560 + 30
  // ...
};
```

### 6. 常见问题与对策

| 问题 | 原因 | 对策 |
|------|------|------|
| 音频重叠 | 前一个音频结束前开始下一个音频 | 确认音频长度，调整场景长度 |
| 幻灯片切换与音频不同步 | 未考虑 TransitionSeries 的重叠 | 场景开始 = 前场景开始 + 前场景长 - 过渡长 |
| 音频中途截断 | 场景长度 < 音频长度 | 调整场景长度为音频长度 + 余量 |
| 无音时间过长 | 音频开始太晚 | 统一使用场景开始 + 30f |

---

## 整合阶段

### 场景连接

```tsx
// remotion/src/FullVideo.tsx
import { Composition, Series } from "remotion";
import { IntroScene } from "./scenes/intro";
import { UIDemoScene } from "./scenes/ui-demo";
import { CTAScene } from "./scenes/cta";

export const FullVideo: React.FC = () => {
  return (
    <Series>
      <Series.Sequence durationInFrames={150}>
        <IntroScene title="MyApp" tagline="让任务管理变得简单" />
      </Series.Sequence>
      <Series.Sequence durationInFrames={450}>
        <UIDemoScene screenshots={[...]} duration={450} />
      </Series.Sequence>
      <Series.Sequence durationInFrames={150}>
        <CTAScene url="https://myapp.com" text="立即试用" />
      </Series.Sequence>
    </Series>
  );
};
```

### 添加过渡效果

```tsx
// 过渡组件
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

## 渲染阶段

### 命令执行

```bash
# MP4 渲染
npx remotion render remotion/index.ts FullVideo out/video.mp4

# GIF 渲染（适用于短视频）
npx remotion render remotion/index.ts FullVideo out/video.gif

# WebM 渲染（适用于 Web）
npx remotion render remotion/index.ts FullVideo out/video.webm --codec=vp8
```

### 输出选项

| 格式 | 推荐用途 | 选项 |
|-------------|---------|-----------|
| MP4 | 通用、社交媒体 | `--codec=h264` |
| WebM | Web 嵌入 | `--codec=vp8` |
| GIF | 短循环 | 推荐 15 秒以下 |

---

## 完成报告

```markdown
✅ **视频生成完成**

📁 **输出文件**:
- `out/video.mp4` (45秒, 1080p, 12.3MB)

📊 **生成统计**:
| 项目 | 值 |
|------|-----|
| 场景数 | 4 |
| 并行代理数 | 3 |
| 生成时间 | 45秒 |
| 渲染时间 | 30秒 |

🎬 **预览**:
- Studio: `npm run remotion` → http://localhost:3000
- 文件: `open out/video.mp4`
```

---

## 错误处理

### 场景生成失败

```
⚠️ 场景生成错误

场景"auth-demo"生成失败。
原因: Playwright 截图失败 - 应用未启动

处理:
1. 请启动应用: `npm run dev`
2. 重新生成: "重新生成 auth-demo"
3. 跳过: "跳过此场景"
```

### 渲染失败

```
⚠️ 渲染错误

原因: 内存不足

处理:
1. 减少并行数: `--concurrency 2`
2. 降低分辨率: 用 720p 重试
3. 分割场景: 将长场景分割为更短的片段
```

---

## BGM 支持

### 实现方法

在 composition 中添加 `bgmPath` 和 `bgmVolume` 属性:

```tsx
export const VideoComposition: React.FC<{
  enableAudio?: boolean;
  volume?: number;
  bgmPath?: string;      // BGM 文件路径（staticFile 相对路径）
  bgmVolume?: number;    // BGM 音量（0.0-1.0）
}> = ({ enableAudio = true, volume = 1, bgmPath, bgmVolume = 0.25 }) => {
  return (
    <AbsoluteFill>
      {/* 场景内容 */}

      {/* BGM（比旁白更轻） */}
      {enableAudio && bgmPath && (
        <Audio src={staticFile(bgmPath)} volume={bgmVolume} />
      )}
    </AbsoluteFill>
  );
};
```

### BGM 音量指南

| 有无旁白 | 推荐 bgmVolume |
|-----------------|----------------|
| 有 | 0.20 - 0.30 |
| 无 | 0.50 - 0.80 |

### 免版权 BGM 获取来源

- [DOVA-SYNDROME](https://dova-s.jp/) - 日语、免费
- [甘茶的音乐工房](https://amachamusic.chagasi.com/) - 日语、免费
- [Pixabay Music](https://pixabay.com/music/) - 英语、免费

---

## 字幕支持

### 实现方法

```tsx
// 字体嵌入（推荐 Base64）
const FontStyle: React.FC = () => (
  <style>
    {`
      @font-face {
        font-family: 'CustomFont';
        src: url('${FONT_DATA_URL}') format('opentype');
        font-weight: normal;
        font-style: normal;
      }
    `}
  </style>
);

// 字幕组件
const Subtitle: React.FC<{ text: string }> = ({ text }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 10], [0, 1], {
    extrapolateRight: "clamp",
  });

  return (
    <>
      <FontStyle />
      <div
        style={{
          position: "absolute",
          bottom: 80,
          left: 0,
          right: 0,
          display: "flex",
          justifyContent: "center",
          padding: "0 60px",
        }}
      >
        <div
          style={{
            fontFamily: "'CustomFont', sans-serif",
            fontSize: 32,
            color: "#FFFFFF",
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: "14px 28px",
            borderRadius: 8,
            textAlign: "center",
            maxWidth: 1000,
            lineHeight: 1.5,
            opacity,
          }}
        >
          {text}
        </div>
      </div>
    </>
  );
};
```

### 字幕时机规则

| 项目 | 值 |
|------|-----|
| 字幕开始 | 与音频开始同一时机 |
| 字幕 duration | 音频长 + 10f（余量） |

### 字体嵌入（Base64）

为确保自定义字体加载，使用 Base64 嵌入:

```typescript
// src/utils/custom-font.ts
import fs from "fs";
import path from "path";

// 构建时 Base64 编码
const fontPath = path.join(__dirname, "../../public/font/MyFont.otf");
const fontBuffer = fs.readFileSync(fontPath);
export const FONT_DATA_URL = `data:font/otf;base64,${fontBuffer.toString("base64")}`;
```

### 字幕数据结构

```tsx
const SUBTITLES = [
  { id: "hook", text: "字幕文本", start: 30, duration: 120 },
  { id: "problem", text: "下一个字幕", start: 175, duration: 178 },
  // ...
];

// 使用
{SUBTITLES.map((sub) => (
  <Sequence key={sub.id} from={sub.start} durationInFrames={sub.duration}>
    <Subtitle text={sub.text} />
  </Sequence>
))}
```

---

## Notes

- 并行生成仅适用于独立场景
- Playwright 截图需要事先启动应用
- 大型视频（3 分钟以上）推荐分割渲染
- BGM 应设置得比旁白轻
- 自定义字体使用 Base64 嵌入确保加载

---

## Phase 10: 未来扩展（角色对话视频）

### 概述

当前的视频生成是**单一旁白**形式，但将来可扩展为以下**角色对话视频**：

| 现在 | Phase 10 扩展后 |
|------|----------------|
| 单一旁白者 | 多个角色的对话 |
| 静态幻灯片 + 音频 | 角色显示 + 对话演出 |
| TTS: 仅 1 个音频 | TTS: 按角色区分音频 |

### 用例示例

```
[入门视频示例]

旁白:  "今天介绍新功能"
用户:    "这个能做什么？"
AI 向导:  "让我简单说明一下"
```

```
[技术讲解视频示例]

采访者: "这个架构的特点是什么？"
专家:      "重视可扩展性"
审查者:    "让我们看看具体数字"
```

### 扩展点（仅设计）

#### 1. Character 定义（`schemas/character.schema.json`）

**已实现**的 schema，定义以下内容：

```json
{
  "character_id": "narrator",
  "name": "旁白者",
  "role": "narrator",
  "voice": {
    "provider": "google-cloud-tts",
    "voice_id": "ja-JP-Neural2-B",
    "language": "ja",
    "speed": 1.1,
    "style": "professional"
  },
  "appearance": {
    "type": "avatar",
    "position": "left"
  }
}
```

**扩展项**:
- `voice`: TTS 设置（提供商、音色 ID、速度、风格）
- `appearance`: 视觉设置（头像、图标、位置）
- `dialogue_style`: 对话演出（气泡样式、动画）
- `personality`: 性格特征（用于未来 AI 对话生成）

#### 2. Dialogue 场景定义（未来规格）

**dialogue.json** 的结构（Phase 10 以后实现）:

```json
{
  "scene_id": "intro-dialogue",
  "type": "dialogue",
  "content": {
    "duration_ms": 15000,
    "exchanges": [
      {
        "character_id": "user",
        "text": "这个功能能做什么？",
        "timing_ms": 0,
        "duration_ms": 3000,
        "emotion": "curious"
      },
      {
        "character_id": "guide",
        "text": "简单说明一下。首先...",
        "timing_ms": 3500,
        "duration_ms": 5000,
        "emotion": "friendly"
      },
      {
        "character_id": "narrator",
        "text": "让我们看看实际画面",
        "timing_ms": 9000,
        "duration_ms": 3000,
        "emotion": "neutral"
      }
    ]
  },
  "characters": [
    {
      "$ref": "characters/user.json"
    },
    {
      "$ref": "characters/guide.json"
    },
    {
      "$ref": "characters/narrator.json"
    }
  ],
  "direction": {
    "layout": "split-screen",
    "transition_between_speakers": "highlight"
  }
}
```

#### 3. TTS 联动的扩展方法

**现在（单一音频）**:
```javascript
// 播放一个音频文件
<Audio src={staticFile('narration.wav')} />
```

**Phase 10 扩展后（按角色区分音频）**:
```javascript
// 按角色调用 TTS
async function generateDialogue(exchanges, characters) {
  const audioFiles = await Promise.all(
    exchanges.map(async (exchange) => {
      const character = characters.find(c => c.character_id === exchange.character_id);

      // 调用 TTS API（根据提供商分支）
      const audioBuffer = await ttsProvider.synthesize({
        text: exchange.text,
        voiceId: character.voice.voice_id,
        speed: character.voice.speed,
        emotion: exchange.emotion,
      });

      return {
        character_id: exchange.character_id,
        audio: audioBuffer,
        timing_ms: exchange.timing_ms,
        duration_ms: exchange.duration_ms,
      };
    })
  );

  return audioFiles;
}
```

**TTS 提供商联动**:

| 提供商 | API 调用示例 |
|-------------|---------------|
| Google Cloud TTS | `textToSpeech.synthesizeSpeech({ voice, input })` |
| ElevenLabs | `elevenlabs.textToSpeech({ voiceId, text })` |
| OpenAI TTS | `openai.audio.speech.create({ voice, input })` |
| AWS Polly | `polly.synthesizeSpeech({ VoiceId, Text })` |

#### 4. 视觉演出的扩展

**角色显示（Remotion 组件示例）**:

```tsx
// 未来实现: DialogueScene.tsx
const DialogueScene: React.FC<{
  exchanges: Exchange[];
  characters: Character[];
}> = ({ exchanges, characters }) => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill>
      {/* 背景 */}
      <Background />

      {/* 角色显示 */}
      <CharacterDisplay
        characters={characters}
        activeCharacterId={getCurrentSpeaker(frame, exchanges)}
      />

      {/* 对话文本（气泡） */}
      <DialogueBubble
        exchange={getCurrentExchange(frame, exchanges)}
      />

      {/* 音频播放 */}
      {exchanges.map((ex, i) => (
        <Sequence from={ex.timing_ms / 33.33} durationInFrames={ex.duration_ms / 33.33}>
          <Audio src={staticFile(`dialogue/${ex.character_id}_${i}.wav`)} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
```

**动画示例**:
- 高亮正在说话的角色
- 不说话的角色半透明
- 气泡淡入/淡出
- 角色头像口型同步（可选）

#### 5. 实现路线图（Phase 10 以后）

| Phase | 实现内容 | 优先级 |
|-------|---------|--------|
| **Phase 10.1** | `character.schema.json` 实现 | ✅ 完成 |
| **Phase 10.2** | TTS 提供商联动（Google Cloud TTS） | High |
| **Phase 10.3** | `DialogueScene` Remotion 组件 | High |
| **Phase 10.4** | `dialogue.json` schema 定义 | Medium |
| **Phase 10.5** | 角色显示 UI（头像/图标） | Medium |
| **Phase 10.6** | 气泡动画 | Low |
| **Phase 10.7** | 多 TTS 提供商支持（ElevenLabs, OpenAI） | Low |
| **Phase 10.8** | AI 对话生成（基于 personality 自动生成） | Future |

#### 6. 兼容性维护

扩展设计**保持向后兼容**：

```
现有 video-script.json（单一旁白）
    ↓ 原样工作
新的 dialogue.json（对话形式）
    ↓ 作为新场景类型添加
两者可共存
```

**scene.schema.json 的添加**:
```json
{
  "type": {
    "enum": [
      "intro",
      "ui-demo",
      "dialogue",  // ← Phase 10 添加
      "..."
    ]
  }
}
```

#### 7. 参考实现

现有项目示例:
- **Manim Community**: 角色动画
- **Remotion Templates**: 对话形式模板
- **Google Cloud TTS**: 多语言·多音色支持

---

### Phase 10 实现时的检查清单

未来实现时请确认：

- [ ] `character.schema.json` 有效（已在 Phase 10.1 完成）
- [ ] TTS API 密钥已设置（推荐 Google Cloud TTS）
- [ ] 定义 `dialogue.json` schema
- [ ] 实现 `DialogueScene.tsx` Remotion 组件
- [ ] 统一角色音频文件命名规范
- [ ] 气泡样式的品牌一致性
- [ ] 与现有场景（intro, ui-demo 等）的共存测试
- [ ] 性能: 多音频同时渲染优化

---

### 总结（Phase 10）

**现状**: 支持单一旁白视频
**Phase 10 设计**: 明确角色对话视频的扩展点
**已实现**: `character.schema.json`（角色定义）
**未实现**: TTS 联动、对话场景、视觉演出（未来实现）

通过此设计，将来可以实现：
- 多角色对话形式视频
- 按角色区分的音色风格
- 视觉上的角色显示和对话演出
- AI 对话生成（基于 personality 设置）
