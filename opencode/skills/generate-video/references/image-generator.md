# 图像生成器 - Nano Banana Pro 图像自动生成

使用 Nano Banana Pro（Google DeepMind）自动生成视频场景用的高质量图像。

---

## 概述

在 `/generate-video` 的场景生成阶段，当判定需要素材图像时自动执行。
实现 2 张生成 → Claude 质量判定 → NG 则重新生成的质量保证循环。

## 前提条件

- `GOOGLE_AI_API_KEY` 环境变量已设置
- Google AI Studio 中 Nano Banana Pro（Gemini 3 Pro Image Preview）已启用

---

## API 规格

> **官方文档**: [Nano Banana image generation | Gemini API](https://ai.google.dev/gemini-api/docs/image-generation)

### 端点

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent
```

### 模型选择

| 模型 | 用途 | 最大分辨率 |
|--------|------|-----------|
| `gemini-3-pro-image-preview` | 专业质量（推荐） | 4K |
| `gemini-2.5-flash-image` | 高速·低成本 | 1024px |

### 认证

```bash
# x-goog-api-key 头部（Gemini API 标准方式）
x-goog-api-key: ${GOOGLE_AI_API_KEY}
```

> **注意**: Gemini API 使用 `x-goog-api-key` 头部。Query parameter 方式（`?key=...`）也可用，但推荐使用头部方式。

### 请求格式

```json
{
  "contents": [{
    "parts": [
      {"text": "A modern SaaS dashboard interface with clean design, showing analytics charts and user metrics, professional UI mockup, light theme"}
    ]
  }],
  "generationConfig": {
    "responseModalities": ["TEXT", "IMAGE"],
    "imageConfig": {
      "aspectRatio": "16:9",
      "imageSize": "2K"
    }
  }
}
```

> **注**: `responseModalities` 可指定 `["TEXT", "IMAGE"]` 或 `["IMAGE"]`。本流程为获取质量判定用文本说明，指定两者。

### 响应格式

```json
{
  "candidates": [{
    "content": {
      "parts": [
        {"text": "Here is the generated image of a modern SaaS dashboard..."},
        {
          "inline_data": {
            "mime_type": "image/png",
            "data": "iVBORw0KGgoAAAANS..."
          }
        }
      ]
    }
  }]
}
```

> **注**: REST API 使用 snake_case（`inline_data`, `mime_type`）。SDK 使用 camelCase（`inlineData`, `mimeType`）。

---

## 分辨率选项

| 设置 | 分辨率 | 用途 | 成本参考 |
|------|--------|------|-----------|
| `1K` | 1024×1024 | 预览、测试 | ~$0.02/张 |
| `2K` | 2048×2048 | 标准质量 | ~$0.06/张 |
| `4K` | 4096×4096 | 高质量、专业 | ~$0.12/张 |

### 宽高比

| 比例 | 用途 |
|------|------|
| `16:9` | 视频场景（推荐） |
| `1:1` | 图标、Logo |
| `9:16` | 竖屏视频 |
| `4:3` | 演示资料 |

---

## 提示词设计指南

### 基本结构

```
[主题] + [风格] + [质量指定] + [约束]
```

### 按场景类型的提示词模板

#### 介绍/标题场景

```
Professional product logo and title card for "{product_name}",
modern minimalist design, clean typography,
{brand_color} accent color, dark background,
cinematic quality, 4K render
```

#### UI 演示场景（辅助图像）

```
Modern web application interface showing {feature_description},
clean UI design, light theme, subtle shadows,
professional SaaS aesthetic, mockup style,
no text labels, focus on visual hierarchy
```

#### CTA 场景

```
Call-to-action banner for {product_name},
action-oriented design, prominent button,
{brand_color} gradient, professional marketing style,
clear visual hierarchy, engaging composition
```

#### 架构/概念图

```
Technical architecture diagram showing {concept},
isometric illustration style, modern tech aesthetic,
clear visual flow, connected components,
professional documentation quality, clean lines
```

### 提示词质量提升技巧

| 添加要素 | 效果 |
|---------|------|
| `professional quality` | 整体质量提升 |
| `clean design` | 减少不必要的元素 |
| `modern aesthetic` | 现代设计 |
| `cinematic lighting` | 戏剧性照明 |
| `4K render` | 高分辨率 |
| `no text` | 无文本（后续添加时） |

### 应避免的提示词

| NG 模式 | 原因 |
|------------|------|
| 模糊指示 | "感觉好的图像" → 结果不稳定 |
| 过度复杂 | 元素过多导致质量下降 |
| 文本指定 | AI 生成文本质量不稳定 |
| 版权物 | 无法生成品牌 Logo 等 |

---

## 执行流程

```
场景生成阶段
    │
    ├── [Step 1] 素材必要判定
    │   └─ 确认场景类型、现有素材有无
    │       ├── 有素材 → 跳过
    │       └─ 无素材 → 进入 Step 2
    │
    ├── [Step 2] 提示词生成
    │   ├─ 从场景信息构建提示词
    │   ├─ 反映品牌信息（颜色、风格）
    │   └─ 应用模板
    │
    ├── [Step 3] 图像生成（2 张并行）
    │   └─ 调用 Nano Banana Pro API（2 次并行执行）
    │       generateContent × 2（同时请求减少延迟）
    │
    ├── [Step 4] 质量判定
    │   └─ → 参考 image-quality-check.md
    │
    ├── [Step 5] 结果处理
    │   ├── 成功 → 保存图像、整合到场景
    │   └─ 失败 → 进入 Step 6
    │
    └── [Step 6] 重新生成循环（最多 3 次）
        ├─ 提示词改善（Claude 提案）
        └─ 返回 Step 3
```

---

## Bash 执行示例

### curl 调用 API

```bash
# 确认环境变量（确认密钥已设置）
test -n "$GOOGLE_AI_API_KEY" && echo "GOOGLE_AI_API_KEY is set" || echo "GOOGLE_AI_API_KEY is not set"

# 图像生成请求
curl -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent" \
  -H "x-goog-api-key: ${GOOGLE_AI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "parts": [
        {"text": "Modern SaaS dashboard interface, clean design, light theme, professional UI"}
      ]
    }],
    "generationConfig": {
      "responseModalities": ["TEXT", "IMAGE"],
      "imageConfig": {
        "aspectRatio": "16:9",
        "imageSize": "2K"
      }
    }
  }' \
  -o response.json

# Base64 解码保存（从 parts 数组提取图像数据）
cat response.json | jq -r '.candidates[0].content.parts[] | select(.inline_data) | .inline_data.data' | head -1 | base64 -d > out/assets/generated/image_1.png
```

> **注意**: 1 次请求生成 1 张图像。需要 2 张时请执行 2 次请求。

### 图像保存位置

```
out/
└── assets/
    └── generated/
        ├── intro_1.png
        ├── intro_2.png
        ├── cta_1.png
        └── cta_2.png
```

---

## 重新生成循环控制

### 最大尝试次数

```
max_attempts = 3
```

### 重新生成时的提示词改善

每次尝试中 Claude 改善提示词:

| 尝试 | 改善策略 |
|------|---------|
| 第 1 次 | 用初始提示词生成 |
| 第 2 次 | 反映质量指正，调整提示词 |
| 第 3 次 | 添加更具体指示、更改风格 |

### 生成改善提示词

```
上次图像因以下原因未被采用:
- {rejection_reason}

改善方案:
1. {improvement_1}
2. {improvement_2}

新提示词:
{improved_prompt}
```

### 3 次失败时的回退

```
⚠️ 图像生成 3 次失败

场景: {scene_name}
最后错误: {last_error}

选项:
1. "继续" → 用占位符图像继续
2. "跳过" → 不生成此场景的图像
3. "手动" → 用户提供图像
```

---

## 错误处理

### API 错误

| 错误代码 | 原因 | 处理 |
|-------------|------|------|
| `400` | 无效提示词 | 确认提示词内容 |
| `401` | 认证失败 | 确认 API 密钥 |
| `429` | 速率限制 | 等待 60 秒后重试 |
| `500` | 服务器错误 | 等待 30 秒后重试 |

### 内容政策违规

```
⚠️ 内容政策违规

提示词违反 Google 政策。
请删除/更改以下内容:
- {violation_reason}

是否尝试自动修正？ (y/n)
```

### 环境变量未设置

```
⚠️ GOOGLE_AI_API_KEY 未设置

设置方法:
1. 在 Google AI Studio 获取 API 密钥
   https://ai.google.dev/aistudio

2. 设置环境变量
   export GOOGLE_AI_API_KEY="your-api-key"

3. 或添加到 .env.local
   GOOGLE_AI_API_KEY=your-api-key
```

---

## 成本估算

### 每场景成本

```
基本: 2 张 × $0.12 = $0.24
最大（3 次重新生成）: 6 张 × $0.12 = $0.72
```

### 每视频成本参考

| 视频类型 | 场景数 | 图像生成场景 | 成本参考 |
|-----------|---------|---------------|-----------|
| 90 秒预告 | 5 | 2-3 | $0.48-$0.72 |
| 3 分钟演示 | 8 | 3-4 | $0.72-$0.96 |
| 5 分钟架构 | 12 | 4-6 | $0.96-$1.44 |

---

## 相关文档

- [image-quality-check.md](./image-quality-check.md) - 质量判定逻辑
- [generator.md](./generator.md) - 并行场景生成引擎
- [planner.md](./planner.md) - 场景规划器
