# 演出指南 - Direction Guide

定义 generate-video 技能的视觉演出系统的使用方法和最佳实践。

---

## 概要

演出系统由以下4个要素组成:

| 要素 | 作用 | 控制内容 |
|-----|------|---------|
| **transition** | 场景切换 | 淡入淡出、滑动、缩放、切换 |
| **emphasis** | 元素强调 | 3级强调 + 音效 |
| **background** | 背景设计 | 5种背景样式 |
| **timing** | 时机调整 | 等待时间、音频偏移 |

---

## Transition（过渡）

### 4种过渡类型

| Type | 用途 | 视觉效果 | 推荐 duration |
|------|------|---------|--------------|
| **fade** | 通用切换 | 平滑淡入/淡出 | 500ms (15f) |
| **slideIn** | 转向下一个话题 | 方向指定滑动（left/right/top/bottom） | 400ms (12f) |
| **zoom** | 引导关注细节 | 缩放 | 600ms (18f) |
| **cut** | 即时切换 | 切换（瞬间） | 0ms |

### 使用指南

#### fade（淡入淡出）
- **推荐场景**: 通用、章节开始、平缓切换
- **效果**: 视觉上柔和、不引人注目
- **示例**:
  - 介绍 → 主要说明
  - 功能说明 → 下一个功能说明
  - CTA 前的平静

```json
{
  "transition": {
    "type": "fade",
    "duration_ms": 500,
    "easing": "easeInOut"
  }
}
```

#### slideIn（滑入）
- **推荐场景**: 话题转换、比较展示、步骤进行
- **效果**: 动态、对下一个内容的期待感
- **direction**:
  - `right`: 前进感（下一步）
  - `left`: 过去参照（Before/After 的 Before）
  - `top`: 重要信息登场
  - `bottom`: 补充信息追加

```json
{
  "transition": {
    "type": "slideIn",
    "duration_ms": 400,
    "direction": "right",
    "easing": "easeOut"
  }
}
```

#### zoom（缩放）
- **推荐场景**: 详情展示、强调、震撼信息
- **效果**: 引导关注、冲击力
- **示例**:
  - 显示重要数值
  - 提出问题核心
  - 强调差异化要点

```json
{
  "transition": {
    "type": "zoom",
    "duration_ms": 600,
    "easing": "easeInOut"
  }
}
```

#### cut（切换）
- **推荐场景**: 演示操作、快速展开、紧张感
- **效果**: 瞬间、节奏提升
- **示例**:
  - UI 操作的步骤之间
  - 快速演示
  - 节奏感强的功能介绍

```json
{
  "transition": {
    "type": "cut",
    "duration_ms": 0
  }
}
```

### 漏斗别推荐过渡

| 漏斗阶段 | 推荐过渡 | 理由 |
|---------|---------|------|
| 认知（LP/广告） | fade, zoom | 平稳、震撼 |
| 兴趣（Intro） | slideIn, fade | 动态、期待感 |
| 考虑（功能演示） | cut, slideIn | 节奏、效率 |
| 确信（架构） | fade, zoom | 详情、信任 |
| 继续（入门引导） | slideIn, cut | 步骤进行 |

---

## Emphasis（强调）

### 3级强调级别

| Level | 用途 | 视觉效果 | 推荐音效 |
|-------|------|---------|---------|
| **high** | 最重要信息 | 大动画、明亮色彩 | whoosh, chime |
| **medium** | 重要要点 | 中等动画、强调色 | pop |
| **low** | 补充信息 | 轻微强调、淡色 | none, ding |

### 使用指南

#### high（高强调）
- **推荐场景**:
  - Hook（开场冲击）
  - CTA（行动号召）
  - 差异化要点（Differentiator）
  - 惊人结果・数值

- **视觉效果**:
  - 文字大小: 特大
  - 颜色: 鲜艳（默认: `#00F5FF` 青色）
  - 动画: scale 1.2, bounce
  - 音效: `whoosh` 或 `chime`

- **示例**:
  - "快3倍" → high emphasis
  - "立即免费试用" → high emphasis

```json
{
  "emphasis": {
    "level": "high",
    "text": ["快3倍"],
    "sound": "whoosh",
    "color": "#00F5FF",
    "position": "center"
  }
}
```

#### medium（中强调）
- **推荐场景**:
  - 功能说明要点
  - 工作流步骤
  - 问题提出（Problem）
  - 解决方案（Solution）

- **视觉效果**:
  - 文字大小: 大
  - 颜色: 强调色（默认: `#FFC700` 金色）
  - 动画: scale 1.1, fade-in
  - 音效: `pop`

- **示例**:
  - "步骤1: 设置" → medium emphasis
  - "您有这样的问题吗？" → medium emphasis

```json
{
  "emphasis": {
    "level": "medium",
    "text": ["步骤1: 设置"],
    "sound": "pop",
    "color": "#FFC700",
    "position": "top"
  }
}
```

#### low（低强调）
- **推荐场景**:
  - 补充信息
  - 附加功能的简单介绍
  - 注释
  - 详细信息链接

- **视觉效果**:
  - 文字大小: 正常
  - 颜色: 淡色（默认: `#A8DADC` 浅蓝）
  - 动画: 仅 fade-in
  - 音效: `none` 或 `ding`

- **示例**:
  - "※详情请参阅文档" → low emphasis
  - "其他众多功能" → low emphasis

```json
{
  "emphasis": {
    "level": "low",
    "text": ["※详情请参阅文档"],
    "sound": "none",
    "color": "#A8DADC",
    "position": "bottom"
  }
}
```

### 音效选择方法

| Sound | 声音特点 | 推荐用途 |
|-------|---------|---------|
| **whoosh** | 风声、动态 | high emphasis、画面切换 |
| **chime** | 钟声、悦耳 | CTA、成功显示 |
| **pop** | 弹出、轻快 | medium emphasis、按钮显示 |
| **ding** | 小铃声 | low emphasis、轻通知 |
| **none** | 无声 | 安静信息、连续显示 |

### 漏斗别推荐强调级别

| 漏斗阶段 | 主要强调 | 辅助强调 |
|---------|---------|---------|
| 认知（LP/广告） | high 多用 | medium 适度 |
| 兴趣（Intro） | high 1-2次 | medium 多用 |
| 考虑（功能演示） | medium 为主 | low 补充 |
| 确信（架构） | medium 适度 | low 多用 |
| 继续（入门引导） | high 目标 | medium 步骤 |

---

## Background（背景）

### 5种背景样式

| Type | 视觉特征 | 用途 | 颜色示例 |
|------|---------|------|---------|
| **cyberpunk** | 霓虹、网格、未来感 | Tech系、先进性诉求 | `#0a0e27` + `#00f5ff` |
| **corporate** | 精致、信任感、专业 | BtoB、企业级 | `#1a1a2e` + `#16213e` |
| **minimal** | 简洁、干净、集中 | 说明重视频、文档 | `#ffffff` + `#f0f0f0` |
| **gradient** | 色彩丰富、动态、亲切 | BtoC、休闲 | `#667eea` → `#764ba2` |
| **particles** | 动态粒子、充满活力 | Hook、CTA、冲击 | `#000000` + particles |

### 使用指南

#### cyberpunk（赛博朋克）
- **推荐场景**:
  - 诉求技术先进性
  - 面向开发者的工具
  - AI/ML 功能介绍
  - 架构图

- **特征**:
  - 霓虹网格
  - 故障效果
  - 青・蓝系颜色

```json
{
  "background": {
    "type": "cyberpunk",
    "primaryColor": "#0a0e27",
    "secondaryColor": "#00f5ff",
    "opacity": 0.9
  }
}
```

#### corporate（企业）
- **推荐场景**:
  - BtoB 产品
  - 企业级功能
  - 安全性・可靠性诉求
  - 实绩・案例介绍

- **特征**:
  - 深蓝系
  - 干净的渐变
  - 沉稳氛围

```json
{
  "background": {
    "type": "corporate",
    "primaryColor": "#1a1a2e",
    "secondaryColor": "#16213e",
    "opacity": 1
  }
}
```

#### minimal（极简）
- **推荐场景**:
  - 让观众专注于内容
  - 复杂图表・代码展示
  - 入门引导
  - 文档式说明

- **特征**:
  - 白・灰系
  - 简洁
  - 可视性优先

```json
{
  "background": {
    "type": "minimal",
    "primaryColor": "#ffffff",
    "secondaryColor": "#f0f0f0",
    "opacity": 1
  }
}
```

#### gradient（渐变）
- **推荐场景**:
  - BtoC 产品
  - 诉求亲和力
  - 介绍・CTA
  - 休闲风格

- **特征**:
  - 色彩丰富的渐变
  - 柔和印象
  - 视觉上有趣

```json
{
  "background": {
    "type": "gradient",
    "primaryColor": "#667eea",
    "secondaryColor": "#764ba2",
    "opacity": 0.95
  }
}
```

#### particles（粒子）
- **推荐场景**:
  - Hook（开始时的冲击）
  - CTA（行动号召）
  - 重要转折点
  - 充满活力的印象

- **特征**:
  - 动态粒子
  - 能量感
  - 引导关注

```json
{
  "background": {
    "type": "particles",
    "primaryColor": "#000000",
    "secondaryColor": "#00f5ff",
    "opacity": 0.8
  }
}
```

### 漏斗别推荐背景

| 漏斗阶段 | 推荐背景 | 理由 |
|---------|---------|------|
| 认知（LP/广告） | particles, gradient | 视觉冲击力 |
| 兴趣（Intro） | gradient, cyberpunk | 亲和力、先进性 |
| 考虑（功能演示） | minimal, corporate | 集中、信任感 |
| 确信（架构） | corporate, cyberpunk | 专业感 |
| 继续（入门引导） | minimal, gradient | 简洁、亲切 |

---

## Timing（时机）

### 时机参数

| Parameter | 用途 | 推荐值 |
|-----------|------|--------|
| **delay_before** | 场景开始前等待 | 0-15f（0-500ms） |
| **delay_after** | 场景结束后等待 | 0-30f（0-1000ms） |
| **audio_start_offset** | 音频开始偏移 | 30f（1000ms，标准） |

### 使用指南

#### delay_before（开始前等待）
- **用途**:
  - 过渡后的视觉稳定
  - 前一场景的余韵
  - 吸引注意力的间隔

- **推荐值**:
  - `0f`: 过渡已足够时
  - `5-10f`: 轻微间隔
  - `15f`: 充分间隔

```json
{
  "timing": {
    "delay_before": 10
  }
}
```

#### delay_after（结束后等待）
- **用途**:
  - 音频结束后的余韵
  - 确保 CTA 显示时间
  - 确保阅读时间

- **推荐值**:
  - `0f`: 立即进入下一个
  - `15-20f`: 标准余韵
  - `30f`: 充分阅读时间

```json
{
  "timing": {
    "delay_after": 20
  }
}
```

#### audio_start_offset（音频开始偏移）
- **用途**:
  - 场景显示后到音频开始的等待
  - 视觉稳定后再开始音频

- **推荐值**:
  - `30f`（1000ms）: 标准（推荐）
  - `15f`（500ms）: 快速展开
  - `45f`（1500ms）: 从容

```json
{
  "timing": {
    "audio_start_offset": 30
  }
}
```

### 音频同步的重要规则

> **重要**: 带解说的视频请严格遵守以下规则

1. **场景长度计算公式**:
   ```
   duration_ms = audio_start_offset + 音频长度 + delay_after
   ```

2. **事先确认音频长度**:
   ```bash
   ffprobe -v error -show_entries format=duration \
     -of default=noprint_wrappers=1:nokey=1 audio/scene.wav
   ```

3. **与过渡的协调**:
   ```
   场景开始 = 前场景开始 + 前场景长 - 过渡长
   音频开始 = 场景开始 + audio_start_offset
   ```

4. **确保余量**:
   - 在过渡开始前音频必须结束
   - 至少确保 `delay_after: 20f`

---

## 最佳实践

### 1. 漏斗别演出组合

#### 90秒 LP/广告 teaser（认知~兴趣）
```json
{
  "hook": {
    "transition": { "type": "zoom", "duration_ms": 600 },
    "emphasis": { "level": "high", "sound": "whoosh" },
    "background": { "type": "particles" },
    "timing": { "delay_before": 10, "delay_after": 20 }
  },
  "problem": {
    "transition": { "type": "slideIn", "direction": "right", "duration_ms": 400 },
    "emphasis": { "level": "medium", "sound": "pop" },
    "background": { "type": "gradient" },
    "timing": { "delay_before": 0, "delay_after": 15 }
  },
  "cta": {
    "transition": { "type": "zoom", "duration_ms": 600 },
    "emphasis": { "level": "high", "sound": "chime" },
    "background": { "type": "particles" },
    "timing": { "delay_before": 15, "delay_after": 30 }
  }
}
```

#### 3分钟 Intro 演示（兴趣→考虑）
```json
{
  "intro": {
    "transition": { "type": "fade", "duration_ms": 500 },
    "emphasis": { "level": "high", "sound": "whoosh" },
    "background": { "type": "gradient" },
    "timing": { "delay_before": 0, "delay_after": 20 }
  },
  "demo": {
    "transition": { "type": "cut", "duration_ms": 0 },
    "emphasis": { "level": "medium", "sound": "pop" },
    "background": { "type": "minimal" },
    "timing": { "delay_before": 0, "delay_after": 10 }
  },
  "cta": {
    "transition": { "type": "fade", "duration_ms": 500 },
    "emphasis": { "level": "high", "sound": "chime" },
    "background": { "type": "gradient" },
    "timing": { "delay_before": 10, "delay_after": 30 }
  }
}
```

### 2. 音效的合理使用

**规则**:
- 1个视频内音效最多 **5-7次**
- 连续场景中减少音效使用（因习惯导致效果减弱）
- high emphasis 必须配音效
- medium emphasis 选择性使用
- low emphasis 基本无声

### 3. 背景的统一感

**规则**:
- 1个视频内背景类型最多 **2-3种**
- 按章节统一（section内使用相同背景）
- 仅 Hook/CTA 允许特殊背景（particles）

### 4. 过渡的节奏

**规则**:
- 不要连续使用同一过渡3次以上
- 组合快速展开（cut）和缓急（fade/zoom）
- 章节开始推荐使用 fade 或 zoom

### 5. 强调级别的分配

**规则（90秒视频时）**:
- high: 2-3次（Hook, Differentiator, CTA）
- medium: 5-8次（主要信息）
- low: 适当（补充信息）

---

## 设计检查清单

场景演出设计时请确认:

### 过渡
- [ ] 选择了符合场景目的的过渡
- [ ] 避免了连续使用同一过渡
- [ ] duration_ms 是否合适（fade: 500ms, slideIn: 400ms, zoom: 600ms）

### 强调
- [ ] 强调级别是否合适（high: 仅最重要）
- [ ] 音效使用次数是否合适（整体5-7次以内）
- [ ] 在 text 数组中指定了需要强调的关键词

### 背景
- [ ] 选择了符合漏斗阶段的背景类型
- [ ] 章节内背景统一
- [ ] 是否指定了 primaryColor, secondaryColor

### 时机
- [ ] audio_start_offset 是否为 30f（标准）
- [ ] 场景长 = audio_start + 音频长 + delay_after
- [ ] 过渡开始前音频已结束

### 整体平衡
- [ ] 音效使用5-7次以内
- [ ] 背景类型2-3种以内
- [ ] high emphasis 2-3次以内

---

## 相关文档

- [generator.md](./generator.md) - 并行生成流程
- [visual-effects.md](./visual-effects.md) - 视觉效果库
- [schemas/direction.schema.json](../schemas/direction.schema.json) - 演出 schema 定义
- [schemas/emphasis.schema.json](../schemas/emphasis.schema.json) - 强调 schema 定义
- [schemas/animation.schema.json](../schemas/animation.schema.json) - 动画 schema 定义
