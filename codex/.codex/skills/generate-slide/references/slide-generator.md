# Slide Generator - Nano Banana Pro 幻灯片图像生成

使用 Nano Banana Pro（Google DeepMind）自动生成项目介绍幻灯片图像。

---

## 概要

在 `/generate-slide` 的 Step 3 中执行的图像生成逻辑。
为 3 种设计模式各生成 2 张，质量检查后选出最佳 1 张。

## 前提条件

- `GOOGLE_AI_API_KEY` 环境变量已设置
- Google AI Studio 中已启用 Nano Banana Pro（Gemini 3 Pro Image Preview）

---

## API 规格

> **共同规格**: 使用与 `generate-video/references/image-generator.md` 相同的 Nano Banana Pro API。

### 端点

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent
```

### 认证

```bash
x-goog-api-key: ${GOOGLE_AI_API_KEY}
```

### 请求格式

```json
{
  "contents": [{
    "parts": [
      {"text": "<slide prompt here>"}
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

### 响应格式

```json
{
  "candidates": [{
    "content": {
      "parts": [
        {"text": "Description of the generated slide..."},
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

---

## 默认设置

| 设置 | 值 | 说明 |
|------|-----|------|
| 模型 | `gemini-3-pro-image-preview` | 专业品质（推荐） |
| 宽高比 | `16:9` | 演示文稿标准 |
| 分辨率 | `2K` | 2048px、标准品质 |
| responseModalities | `["TEXT", "IMAGE"]` | 文本说明 + 图像 |

### 宽高比选项

| 比例 | 用途 |
|------|------|
| `16:9` | 演示/屏幕（推荐） |
| `4:3` | 传统演示 |
| `1:1` | SNS 发布、图标用 |

---

## 3 种设计模式

### Pattern A: Minimalist

**概念**: 以留白和排版为主。精致印象。

**提示词模板**:

```
Create a minimalist project introduction slide for "{project_name}".

Project description: {project_description}
Key features: {features}

Design style:
- Clean whitespace-dominant layout
- Typography-driven hierarchy with bold project name
- Subtle accent color: {accent_color}
- {tone} aesthetic
- No cluttered elements, elegant simplicity
- Professional presentation quality, 2K resolution

Important: This is a single slide image, not a deck. Focus on clear visual hierarchy with the project name prominent and key value proposition visible.
```

**视觉印象**:
```
+------------------------------------------+
|                                          |
|                                          |
|        PROJECT NAME                      |
|        _______________                   |
|                                          |
|        One-line description              |
|                                          |
|        * Feature 1                       |
|        * Feature 2                       |
|        * Feature 3                       |
|                                          |
+------------------------------------------+
```

### Pattern B: Infographic

**概念**: 数据或流程可视化。信息量大但有条理。

**提示词模板**:

```
Create an infographic-style project introduction slide for "{project_name}".

Project description: {project_description}
Key features: {features}
Tech stack: {tech_stack}

Design style:
- Data visualization and structured layout
- Icons and visual elements for each feature
- Flow or architecture diagram elements
- Metrics and key numbers highlighted
- {tone} color palette with {accent_color} accents
- Professional infographic quality, 2K resolution

Important: This is a single slide image. Organize information visually with icons, sections, and clear data hierarchy. Make the project's value immediately understandable through visual structure.
```

**视觉印象**:
```
+------------------------------------------+
|  PROJECT NAME          [icon] [icon]     |
|  ================                        |
|                                          |
|  [Feature 1]    [Feature 2]    [Feat 3]  |
|  +----------+   +----------+   +------+  |
|  | icon     |   | icon     |   | icon |  |
|  | detail   |   | detail   |   | det  |  |
|  +----------+   +----------+   +------+  |
|                                          |
|  Tech: [TS] [Node] [React]    v1.0      |
+------------------------------------------+
```

### Pattern C: Hero Visual

**概念**: 大视觉和标语，强调冲击力。

**提示词模板**:

```
Create a hero-style project introduction slide for "{project_name}".

Project description: {project_description}
Key value: {key_value_proposition}

Design style:
- Bold, impactful hero image as background
- Large catchy headline text
- Dramatic visual composition
- {tone} mood with cinematic lighting
- Strong visual metaphor representing the project's purpose
- Professional marketing quality, 2K resolution

Important: This is a single slide image. Prioritize visual impact and emotional resonance. The project name and core value should be immediately visible with a compelling visual backdrop.
```

**视觉印象**:
```
+------------------------------------------+
|                                          |
|    ==============================        |
|    ||  PROJECT NAME            ||        |
|    ||                          ||        |
|    ||  "Catchy tagline here"   ||        |
|    ||                          ||        |
|    ==============================        |
|                                          |
|         [ Bold Visual BG ]               |
|                                          |
+------------------------------------------+
```

---

## 提示词构成

### 基本结构

```
[项目概要] + [设计风格] + [品质指定] + [约束]
```

### 按风格的修饰语

| 风格 | 修饰语 |
|--------|--------|
| 技术 | `dark theme, code-inspired, terminal aesthetic, neon accents` |
| 休闲 | `bright colors, friendly, playful, approachable` |
| 商务 | `formal, trustworthy, blue tones, clean lines, business` |
| 创意 | `bold, artistic, gradient, unconventional layout` |

### 品质提升关键词

| 关键词 | 效果 |
|-----------|------|
| `professional presentation quality` | 演示品质 |
| `clean design` | 减少不必要元素 |
| `2K resolution` | 高分辨率 |
| `clear visual hierarchy` | 视觉层次 |
| `modern aesthetic` | 现代设计 |

### 应避免的提示词

| NG 模式 | 原因 |
|------------|------|
| 模糊指示 | "好看点的幻灯片" → 结果不稳定 |
| 过于复杂 | 元素太多会降低质量 |
| 指定长文本 | AI 生成的文本质量不稳定。只用关键词 |
| 有版权物 | 无法生成品牌 logo 等 |

---

## Bash 执行示例

### 确认环境变量

```bash
test -n "$GOOGLE_AI_API_KEY" && echo "GOOGLE_AI_API_KEY is set" || { echo "GOOGLE_AI_API_KEY is not set"; exit 1; }
```

### 创建输出目录

```bash
mkdir -p out/slides/selected
```

### 用 curl 生成图像

```bash
PROMPT='Create a minimalist project introduction slide for "My Project". Clean whitespace-dominant layout, typography-driven, professional presentation quality, 2K resolution.'

curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent" \
  -H "x-goog-api-key: ${GOOGLE_AI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"contents\": [{
      \"parts\": [
        {\"text\": \"${PROMPT}\"}
      ]
    }],
    \"generationConfig\": {
      \"responseModalities\": [\"TEXT\", \"IMAGE\"],
      \"imageConfig\": {
        \"aspectRatio\": \"16:9\",
        \"imageSize\": \"2K\"
      }
    }
  }" \
  -o /tmp/slide_response.json

# Base64 解码保存为 PNG
cat /tmp/slide_response.json | jq -r '.candidates[0].content.parts[] | select(.inline_data) | .inline_data.data' | head -1 | base64 -d > out/slides/minimalist_1.png
```

> **注意**: 一次请求生成一张图像。需要 2 张时请执行 2 次请求。

### 并行生成（6 张批量）

```bash
mkdir -p out/slides/selected

generate_slide() {
  local pattern=$1
  local index=$2
  local prompt=$3
  local aspect_ratio=${4:-"16:9"}
  local image_size=${5:-"2K"}

  curl -s -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent" \
    -H "x-goog-api-key: ${GOOGLE_AI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"contents\": [{
        \"parts\": [
          {\"text\": \"${prompt}\"}
        ]
      }],
      \"generationConfig\": {
        \"responseModalities\": [\"TEXT\", \"IMAGE\"],
        \"imageConfig\": {
          \"aspectRatio\": \"${aspect_ratio}\",
          \"imageSize\": \"${image_size}\"
        }
      }
    }" \
    -o "/tmp/slide_${pattern}_${index}.json"

  # Base64 解码
  cat "/tmp/slide_${pattern}_${index}.json" \
    | jq -r '.candidates[0].content.parts[] | select(.inline_data) | .inline_data.data' \
    | head -1 \
    | base64 -d > "out/slides/${pattern}_${index}.png"
}

# 并行执行（后台作业）
generate_slide "minimalist" "1" "$MINIMALIST_PROMPT" &
generate_slide "minimalist" "2" "$MINIMALIST_PROMPT" &
generate_slide "infographic" "1" "$INFOGRAPHIC_PROMPT" &
generate_slide "infographic" "2" "$INFOGRAPHIC_PROMPT" &
generate_slide "hero" "1" "$HERO_PROMPT" &
generate_slide "hero" "2" "$HERO_PROMPT" &
wait

echo "6 张生成完成"
```

---

## 重新生成时的提示词改善策略

### 每次尝试的改善

| 尝试 | 改善策略 |
|------|---------|
| 第 1 次 | 用初始提示词生成 |
| 第 2 次 | 反映质量反馈，调整提示词（添加具体修饰语） |
| 第 3 次 | 大幅改变风格，添加更具体的构图指示 |

### 按问题类别的改善

| 问题 | 添加改善提示词 |
|------|-------------------|
| 文本不可读 | 添加 `no text elements, text-free design` |
| 布局混乱 | 添加 `balanced composition, grid-based layout` |
| 信息量不足 | 在提示词中明确具体功能名、数值 |
| 专业感低 | 添加 `corporate quality, polished, refined` |
| 颜色不匹配 | 指定具体 HEX 颜色代码 |

---

## 错误处理

### API 错误

| 错误代码 | 原因 | 处理 |
|-------------|------|------|
| `400` | 提示词无效 | 确认并修正提示词内容 |
| `401` | 认证失败 | 确认 API 密钥 |
| `429` | 速率限制 | 等待 60 秒后重试 |
| `500` | 服务器错误 | 等待 30 秒后重试 |

### jq 解析错误

响应中不包含图像数据时：

```bash
# 确认响应
cat /tmp/slide_response.json | jq '.candidates[0].content.parts | length'

# 确认错误消息
cat /tmp/slide_response.json | jq '.error'
```

---

## 成本估算

### 每次执行

```
基本: 6 张 x ~$0.06 = ~$0.36（2K 分辨率）
最大（所有模式重试 3 次）: 18 张 x ~$0.06 = ~$1.08
```

### 按分辨率的成本

| 分辨率 | 每张 | 6 张（基本） | 18 张（最大） |
|--------|----------|-------------|-------------|
| `1K` | ~$0.02 | ~$0.12 | ~$0.36 |
| `2K` | ~$0.06 | ~$0.36 | ~$1.08 |
| `4K` | ~$0.12 | ~$0.72 | ~$2.16 |

---

## 相关文档

- [slide-quality-check.md](./slide-quality-check.md) — 质量判定逻辑
- [generate-video/references/image-generator.md](../../generate-video/references/image-generator.md) — API 共同规格（详细）
- [generate-video/references/image-quality-check.md](../../generate-video/references/image-quality-check.md) — 视频用质量判定（参考）
