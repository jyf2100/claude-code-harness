# Image Quality Check - Claude 图片质量判定

Nano Banana Pro 生成的图片由 Claude 目视判定，保证质量。

---

## 概要

在 `image-generator.md` 的 Step 4 执行的质量判定逻辑。
Claude 分析 2 张生成图片，判定采用/不采用。

## 判定流程

```
接收 2 张图片
    │
    ├── [Step 1] 各图片个别评价
    │   ├─ 基本质量检查
    │   ├─ 场景适配性检查
    │   └─ 品牌一致性检查
    │
    ├── [Step 2] 汇总判定结果
    │   ├── 两张都 OK → 进入 Step 3
    │   ├── 1 张 OK → 采用 OK
    │   └── 两张都 NG → 重新生成
    │
    └── [Step 3] 从 2 张中选择最佳
        ├─ 比较评价
        └─ 决定采用图片
```

---

## 判定标准

### 1. 基本质量检查

| 检查项 | 合格标准 | NG 例 |
|-------|---------|------|
| **清晰度** | 无模糊·噪点 | 失焦、过度噪点 |
| **构图** | 平衡良好 | 偏移、裁切、不自然配置 |
| **色调** | 自然且一致 | 色斑、不自然饱和度 |
| **伪影** | 无生成噪点 | 畸变、重复图案 |
| **分辨率** | 满足指定分辨率 | 低分辨率、放大劣化 |

### 2. 场景适配性检查

| 检查项 | 合格标准 | NG 例 |
|-------|---------|------|
| **主题一致** | 表达提示词主题 | 无关内容 |
| **样式一致** | 符合指定样式 | 样式不一致 |
| **用途适配** | 符合场景目的 | 不适合视频的构图 |
| **文本质量** | 包含时可读 | 乱码、不自然文本 |

### 3. 品牌一致性检查

| 检查项 | 合格标准 | NG 例 |
|-------|---------|------|
| **配色方案** | 与品牌色协调 | 颜色不一致 |
| **基调** | 专业 | 过于随意、廉价 |
| **一致性** | 与其他场景统一感 | 显得突兀 |

---

## 评价评分

### 分数定义

| 分数 | 判定 | 说明 |
|------|------|------|
| 5 | Excellent | 完美，立即采用 |
| 4 | Good | 良好，可采用 |
| 3 | Acceptable | 可接受，无其他则采用 |
| 2 | Poor | 有问题，推荐重新生成 |
| 1 | Unacceptable | 不可用，必须重新生成 |

### 采用阈值

```
采用阈值 = 3（Acceptable 以上）
```

### 2 张比较时的选择逻辑

```
两张都在阈值以上时：
  → 采用分数高的
  → 同分时按以下判断：
     1. 场景适配性高的
     2. 品牌一致性高的
     3. 采用第 1 张（默认）
```

---

## Claude 判定提示词

### 图片评价提示词

````text
请评价以下图片。

## 评价对象
- 场景：{scene_name}
- 用途：{scene_purpose}
- 期望样式：{expected_style}
- 品牌色：{brand_colors}

## 评价标准
1. 基本质量（清晰度、构图、色调、伪影）
2. 场景适配性（主题、样式、用途）
3. 品牌一致性（颜色、基调、一致性）

## 输出格式
```json
{
  "score": 1-5,
  "verdict": "OK" | "NG",
  "strengths": ["优点1", "优点2"],
  "issues": ["问题点1", "问题点2"],
  "improvement_suggestions": ["改进建议1", "改进建议2"]
}
```
````

### 2 张比较提示词

````text
请比较以下 2 张图片，选择更合适的一张。

## 评价对象
- 场景：{scene_name}
- 用途：{scene_purpose}

## 图片 A 的评价
{image_a_evaluation}

## 图片 B 的评价
{image_b_evaluation}

## 输出格式
```json
{
  "selected": "A" | "B",
  "reason": "选择理由",
  "comparison_notes": "比较详情"
}
```
````

---

## 判定结果结构

### 个别评价结果

```json
{
  "image_id": "intro_1",
  "score": 4,
  "verdict": "OK",
  "evaluation": {
    "basic_quality": {
      "sharpness": 5,
      "composition": 4,
      "color": 4,
      "artifacts": 5
    },
    "scene_fit": {
      "subject_match": 4,
      "style_match": 4,
      "purpose_fit": 4
    },
    "brand_consistency": {
      "color_scheme": 4,
      "tone": 4,
      "coherence": 4
    }
  },
  "strengths": [
    "简洁设计",
    "恰当的颜色使用"
  ],
  "issues": [
    "右端略空"
  ],
  "improvement_suggestions": [
    "调整构图偏中间"
  ]
}
```

### 比较选择结果

```json
{
  "scene": "intro",
  "candidates": [
    {"id": "intro_1", "score": 4, "verdict": "OK"},
    {"id": "intro_2", "score": 3, "verdict": "OK"}
  ],
  "selected": "intro_1",
  "reason": "构图和颜色平衡更优",
  "output_path": "out/assets/generated/intro_selected.png"
}
```

---

## NG 时的重新生成指示

### 改进提示词生成

```
上次图片未被采用。

## 问题点
{issues}

## 改进建议
{improvement_suggestions}

## 修正提示词
请生成改进了以下点的提示词：
1. {improvement_1}
2. {improvement_2}
```

### 重新生成时的调整策略

| 问题类别 | 调整策略 |
|---------|---------|
| 构图问题 | 添加 `centered composition`, `balanced layout` |
| 颜色问题 | 添加具体颜色指定（HEX） |
| 样式不一致 | 更具体指定样式 |
| 文本质量 | 添加 `no text`，稍后叠加 |
| 质量下降 | 添加 `high quality`, `4K`, `detailed` |

---

## 执行示例

### 用 Read 工具读取图片

```
Claude 用 Read 工具读取图片：

Read:
  file_path: "out/assets/generated/intro_1.png"

Read:
  file_path: "out/assets/generated/intro_2.png"
```

### 执行评价

```
正在评价图片...

📊 评价结果：

| 图片 | 分数 | 判定 | 主要评价 |
|------|------|------|---------|
| intro_1 | 4/5 | ✅ OK | 构图良好、色调统一 |
| intro_2 | 3/5 | ✅ OK | 略暗、构图有偏 |

🎯 选择：intro_1
理由：整体平衡和明亮度更优
```

### NG 时输出例

```
📊 评价结果：

| 图片 | 分数 | 判定 | 主要问题 |
|------|------|------|---------|
| cta_1 | 2/5 | ❌ NG | 文本崩坏 |
| cta_2 | 2/5 | ❌ NG | 颜色太暗 |

⚠️ 两张图片都不符合标准

改进建议：
1. 提示词添加 `no text`（文本稍后叠加）
2. 添加 `bright colors`, `light background`

执行重新生成...（尝试 2/3）
```

---

## 判定绕过

### 强制采用

```
用户指定「这张图片就行」时：
→ 跳过质量判定直接采用
```

### 阈值调整

```
用户指定「更严格」时：
→ 采用阈值提高到 4

用户指定「先这样」时：
→ 采用阈值降低到 2
```

---

## 相关文档

- [image-generator.md](./image-generator.md) - Nano Banana Pro API 客户端
- [generator.md](./generator.md) - 并行场景生成引擎
