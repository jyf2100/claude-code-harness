# Image Quality Check - Claude 图像质量判定

Claude 目视判定 Nano Banana Pro 生成的图像，保证质量。

---

## 概要

在 `image-generator.md` 的 Step 4 中执行的质量判定逻辑。
Claude 分析 2 张生成图像，判定采用/不采用。

## 判定流程

```
接收 2 张图像
    │
    ├── [Step 1] 各图像单独评估
    │   ├─ 基本质量检查
    │   ├─ 场景适应性检查
    │   └─ 品牌一致性检查
    │
    ├── [Step 2] 判定结果汇总
    │   ├── 两张都 OK → Step 3
    │   ├── 一张 OK → 采用 OK 的
    │   └── 两张都 NG → 重新生成
    │
    └── [Step 3] 从 2 张中选择最优
        ├─ 比较评估
        └─ 决定采用图像
```

---

## 判定标准

### 1. 基本质量检查

| 检查项 | 合格标准 | NG 例 |
|-------------|---------|------|
| **清晰度** | 无模糊・噪点 | 失焦、过度噪点 |
| **构图** | 平衡良好 | 偏差、截断、不自然配置 |
| **色调** | 自然且一致 | 色差、不自然饱和度 |
| **伪影** | 无生成噪点 | 扭曲、重复图案 |
| **分辨率** | 满足指定分辨率 | 低分辨率、放大劣化 |

### 2. 场景适应性检查

| 检查项 | 合格标准 | NG 例 |
|-------------|---------|------|
| **主题匹配** | 表现提示词主题 | 无关内容 |
| **风格匹配** | 符合指定风格 | 风格不匹配 |
| **用途适应** | 符合场景目的 | 不适合视频的构图 |
| **文本质量** | 包含时可读 | 乱码、不自然文本 |

### 3. 品牌一致性检查

| 检查项 | 合格标准 | NG 例 |
|-------------|---------|------|
| **颜色方案** | 与品牌颜色协调 | 颜色不匹配 |
| **基调** | 专业 | 过于随意、廉价 |
| **一致性** | 与其他场景统一 | 突兀 |

---

## 评估评分

### 分数定义

| 分数 | 判定 | 说明 |
|--------|------|------|
| 5 | Excellent | 完美，立即采用 |
| 4 | Good | 良好，可采纳 |
| 3 | Acceptable | 可接受，如果没有其他选择则采用 |
| 2 | Poor | 有问题，建议重新生成 |
| 1 | Unacceptable | 不可用，必须重新生成 |

### 采用阈值

```
采用阈值 = 3（Acceptable 以上）
```

### 2 张比较时的选择逻辑

```
两张都在阈值以上时:
  → 采用分数高的
  → 分数相同时按以下判断:
     1. 场景适应性高的
     2. 品牌一致性高的
     3. 采用第 1 张（默认）
```

---

## Claude 判定提示词

### 图像评估提示词

````text
请评估以下图像。

## 评估对象
- 场景: {scene_name}
- 用途: {scene_purpose}
- 期望风格: {expected_style}
- 品牌颜色: {brand_colors}

## 评估标准
1. 基本质量（清晰度、构图、色调、伪影）
2. 场景适应性（主题、风格、用途）
3. 品牌一致性（颜色、基调、一致性）

## 输出格式
```json
{
  "score": 1-5,
  "verdict": "OK" | "NG",
  "strengths": ["优点1", "优点2"],
  "issues": ["问题点1", "问题点2"],
  "improvement_suggestions": ["改善建议1", "改善建议2"]
}
```
````

### 2 张比较提示词

````text
请比较以下 2 张图像，选择更合适的一张。

## 评估对象
- 场景: {scene_name}
- 用途: {scene_purpose}

## 图像A 的评估
{image_a_evaluation}

## 图像B 的评估
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

## 判定结果的结构

### 单独评估结果

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
    "简洁的设计",
    "恰当的颜色使用"
  ],
  "issues": [
    "右端略显空旷"
  ],
  "improvement_suggestions": [
    "调整构图使中心更集中"
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
  "reason": "构图和色彩平衡更优",
  "output_path": "out/assets/generated/intro_selected.png"
}
```

---

## NG 时的重新生成指示

### 改善提示词生成

```
上次的图像未被采用。

## 问题点
{issues}

## 改善建议
{improvement_suggestions}

## 修正提示词
请生成改善以下内容的提示词:
1. {improvement_1}
2. {improvement_2}
```

### 重新生成时的调整策略

| 问题类别 | 调整策略 |
|-------------|---------|
| 构图问题 | 添加 `centered composition`, `balanced layout` |
| 颜色问题 | 添加具体颜色指定（HEX） |
| 风格不匹配 | 使风格指定更具体 |
| 文本质量 | 添加 `no text`，之后叠加 |
| 质量下降 | 添加 `high quality`, `4K`, `detailed` |

---

## 执行示例

### Read 工具读取图像

```
Claude 用 Read 工具读取图像:

Read:
  file_path: "out/assets/generated/intro_1.png"

Read:
  file_path: "out/assets/generated/intro_2.png"
```

### 评估执行

```
正在评估图像...

📊 评估结果:

| 图像 | 分数 | 判定 | 主要评价 |
|------|--------|------|---------|
| intro_1 | 4/5 | ✅ OK | 构图良好、色调统一 |
| intro_2 | 3/5 | ✅ OK | 略暗、构图有偏差 |

🎯 选择: intro_1
理由: 整体平衡和亮度更优
```

### NG 时的输出示例

```
📊 评估结果:

| 图像 | 分数 | 判定 | 主要问题 |
|------|--------|------|---------|
| cta_1 | 2/5 | ❌ NG | 文本崩坏 |
| cta_2 | 2/5 | ❌ NG | 颜色太暗 |

⚠️ 两张图像都不满足标准

改善建议:
1. 在提示词中添加 `no text`（文本之后叠加）
2. 添加 `bright colors`, `light background`

正在重新生成... (尝试 2/3)
```

---

## 判定的绕过

### 强制采用

```
用户指定"这张图就行"时:
→ 跳过质量判定直接采用
```

### 阈值调整

```
用户指定"更严格"时:
→ 将采用阈值提高到 4

用户指定"先凑合"时:
→ 将采用阈值降低到 2
```

---

## 相关文档

- [image-generator.md](./image-generator.md) - Nano Banana Pro API 客户端
- [generator.md](./generator.md) - 并行场景生成引擎
