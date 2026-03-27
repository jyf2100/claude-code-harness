# Slide Quality Check - 幻灯片图片质量判定

Nano Banana Pro 生成的幻灯片图片由 Claude 进行目视判定，保证质量。

---

## 概要

在 `/generate-slide` 的 Step 4 中执行的质量判定逻辑。
评估每种模式（Minimalist, Infographic, Hero Visual）的2张图片，选出最佳1张。

---

## 判定流程

```
接收每种模式的2张图片
    |
    +--[Step 1] 各图片单独评价
    |   +-- 按幻灯片特有的5个标准评分
    |   +-- 各标准1-5分评价
    |   +-- 计算综合得分（加权平均）
    |
    +--[Step 2] 模式内比较
    |   +-- 两张都3分以上 → 采用分数高的
    |   +-- 仅1张3分以上 → 采用那张
    |   +-- 两张都2分以下 → 重新生成
    |
    +--[Step 3] 重新生成判定
        +-- 两张都 NG → 改进提示词后重新生成（最多3次）
        +-- 达到重试上限 → 向用户报告
```

---

## 幻灯片特有的判定标准

### 5个标准与权重

| 标准 | 权重 | 说明 | 评价要点 |
|-----|------|------|---------|
| **信息传达力** | 高（x3） | 项目的特点能否在1张中传达 | 一目了然知道是什么项目、价值主张明确 |
| **布局平衡** | 高（x3） | 视觉完成度、留白的运用 | 元素排列有序、视线引导自然 |
| **文本可读性** | 中（x2） | AI生成文本是否可读 | 无乱码、字体大小合适、对比度足够 |
| **专业感** | 中（x2） | 是否达到商业用途质量 | 不廉价、配色精致、统一感强 |
| **品牌一致性** | 低（x1） | 与指定颜色・风格的一致性 | 符合指定风格、颜色不偏离 |

### 综合得分计算

```
综合得分 = (信息传达力 x 3 + 布局平衡 x 3 + 文本可读性 x 2 + 专业感 x 2 + 品牌一致性 x 1) / 11
```

### 分数定义

| 分数 | 判定 | 说明 |
|-----|------|------|
| 5 | Excellent | 完美，立即采用 |
| 4 | Good | 良好，可采用 |
| 3 | Acceptable | 可接受，没有其他则采用 |
| 2 | Poor | 有问题，推荐重新生成 |
| 1 | Unacceptable | 不可用，必须重新生成 |

### 采用阈值

```
采用阈值 = 3（Acceptable 以上）
```

---

## 模式别的额外检查

### Minimalist

| 检查项 | 合格标准 |
|-------|---------|
| 留白的运用 | 有足够留白，不拥挤 |
| 排版 | 字体易读，层次清晰 |
| 简洁性 | 元素精简到最少 |

### Infographic

| 检查项 | 合格标准 |
|-------|---------|
| 信息的结构化 | 视觉上有明确分区 |
| 图标/图的运用 | 除了文本还有视觉元素 |
| 数据的可视化 | 数值和特点有图示 |

### Hero Visual

| 检查项 | 合格标准 |
|-------|---------|
| 视觉冲击力 | 有吸引眼球的大胆视觉 |
| 标语 | 信息明确且易读 |
| 情感诉求 | 直观传达项目价值 |

---

## Claude 判定提示词

### 图片评价提示词

````text
请评价以下幻灯片图片。

## 评价对象
- 模式: {pattern_name}（Minimalist / Infographic / Hero Visual）
- 项目: {project_name}
- 概述: {project_description}
- 期望风格: {tone}

## 评价标准（各1-5分）
1. 信息传达力（权重: 高）— 项目特点能否在1张中传达
2. 布局平衡（权重: 高）— 视觉完成度、留白的运用
3. 文本可读性（权重: 中）— 文字是否可读、是否有乱码
4. 专业感（权重: 中）— 是否达到商业用途质量
5. 品牌一致性（权重: 低）— 与指定颜色・风格的一致性

## 输出格式
```json
{
  "scores": {
    "information_delivery": 1-5,
    "layout_balance": 1-5,
    "text_readability": 1-5,
    "professionalism": 1-5,
    "brand_consistency": 1-5
  },
  "total_score": 1-5,
  "verdict": "OK" | "NG",
  "strengths": ["优点1", "优点2"],
  "issues": ["问题点1", "问题点2"],
  "improvement_suggestions": ["改进建议1", "改进建议2"]
}
```
````

### 2张比较提示词

````text
请比较以下2张幻灯片图片，选择更合适的一张。

## 评价对象
- 模式: {pattern_name}
- 项目: {project_name}

## 图片1 的评价
{image_1_evaluation}

## 图片2 的评价
{image_2_evaluation}

## 选择标准的优先级
1. 信息传达力（最高优先）
2. 专业感
3. 布局平衡

## 输出格式
```json
{
  "selected": "1" | "2",
  "reason": "选择理由",
  "comparison_notes": "比较详情"
}
```
````

---

## 模式内选择逻辑

### 基本规则

```
1. 两张都3分以上:
   → 采用分数高的一张
   → 同分 → 按优先标准判定:
      1. 信息传达力高的一张
      2. 专业感高的一张
      3. 默认采用候选1

2. 仅1张3分以上:
   → 采用3分以上的那张

3. 两张都2分以下:
   → 重新生成（改进提示词）
   → 达到重试上限（3次）时:
      → 将分数高的一张作为"临时采用"报告给用户
      → 让用户选择继续或跳过
```

### 重试控制

```
max_retries = 3（每种模式）
```

| 重试 | 改进策略 |
|-----|---------|
| 第1次 | 使用初始提示词生成 |
| 第2次 | 反映质量意见，添加具体修饰词 |
| 第3次 | 大幅更改风格，添加更具体的构图指示 |

---

## 判定结果结构

### 单独评价结果

```json
{
  "image_id": "minimalist_1",
  "pattern": "minimalist",
  "scores": {
    "information_delivery": 4,
    "layout_balance": 5,
    "text_readability": 3,
    "professionalism": 4,
    "brand_consistency": 4
  },
  "total_score": 4.1,
  "verdict": "OK",
  "strengths": [
    "留白运用出色",
    "项目名一目了然"
  ],
  "issues": [
    "功能列表文字略小"
  ],
  "improvement_suggestions": [
    "增大文字大小，或减少功能数量"
  ]
}
```

### 模式选择结果

```json
{
  "pattern": "minimalist",
  "candidates": [
    {"id": "minimalist_1", "total_score": 4.1, "verdict": "OK"},
    {"id": "minimalist_2", "total_score": 3.5, "verdict": "OK"}
  ],
  "selected": "minimalist_1",
  "reason": "布局平衡和信息传达力更优",
  "output_path": "out/slides/selected/minimalist.png"
}
```

---

## 质量报告生成

Step 5 生成 `out/slides/quality-report.md`:

```markdown
# Slide Quality Report

## 生成信息
- 项目: {project_name}
- 生成时间: {datetime}
- 宽高比: {aspect_ratio}
- 风格: {tone}

## 结果摘要

| 模式 | 候选1 | 候选2 | 采用 | 分数 | 重试 |
|-----|-------|-------|------|------|-----|
| Minimalist | {score}/5 | {score}/5 | 候选{n} | {score}/5 | 0次 |
| Infographic | {score}/5 | {score}/5 | 候选{n} | {score}/5 | 0次 |
| Hero Visual | {score}/5 | {score}/5 | 候选{n} | {score}/5 | 0次 |

## 详细评价

### Minimalist

#### 候选1 (minimalist_1.png)
- 信息传达力: {score}/5
- 布局平衡: {score}/5
- 文本可读性: {score}/5
- 专业感: {score}/5
- 品牌一致性: {score}/5
- **综合: {score}/5 — {verdict}**
- 优点: {strengths}
- 问题: {issues}

#### 候选2 (minimalist_2.png)
...

### Infographic
...

### Hero Visual
...

## 输出文件

| 文件 | 说明 |
|-----|------|
| `out/slides/selected/minimalist.png` | Minimalist 模式最佳 |
| `out/slides/selected/infographic.png` | Infographic 模式最佳 |
| `out/slides/selected/hero.png` | Hero Visual 模式最佳 |
```

---

## 阈值调整

### 用户请求响应

```
「更严格一点」→ 将采用阈值提高到 4
「先这样也行」→ 将采用阈值降低到 2
「这张图片就行」→ 跳过质量判定直接采用
```

---

## 相关文档

- [slide-generator.md](./slide-generator.md) — 图片生成逻辑
- [generate-video/references/image-quality-check.md](../../generate-video/references/image-quality-check.md) — 视频用质量判定（结构参考源）
