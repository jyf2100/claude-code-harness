# 演出指南 - Direction Guide

定义 generate-video 技能的视觉演出系统的使用方法和最佳实践。

---

## 概述

演出系统由以下 4 个要素组成：

| 要素 | 角色 | 控制内容 |
|------|------|---------|
| **transition** | 场景切换 | 淡入淡出、滑动、缩放、切换 |
| **emphasis** | 要素强调 | 3 段强调 + 效果音 |
| **background** | 背景设计 | 5 种背景样式 |
| **timing** | 时机调整 | 等待时间、音频偏移 |

---

## Transition（过渡）

### 4 种过渡类型

| Type | 用途 | 视觉效果 | 推荐 duration |
|------|------|---------|--------------|
| **fade** | 通用切换 | 平滑淡入/淡出 | 500ms (15f) |
| **slideIn** | 转到下一个话题 | 方向滑动（left/right/top/bottom） | 400ms (12f) |
| **zoom** | 引导关注细节 | 缩放 | 600ms (18f) |
| **cut** | 立即切换 | 切换（瞬间） | 0ms |

### 使用指南

#### fade（淡入淡出）
- **推荐场景**: 通用、段落开始、平稳切换
- **效果**: 视觉上柔和、不过度吸引注意力
- **示例**:
  - 介绍 → 主要说明
  - 功能说明 → 下一个功能说明
  - CTA 前的沉稳

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
- **推荐场景**: 话题转换、比较展示、步骤推进
- **效果**: 动态、对下一个内容的期待感
- **direction**:
  - `right`: 前进感（下一步）
  - `left`: 过去参照（Before/After 的 Before）
  - `top`: 重要信息登场
  - `bottom`: 补充信息添加

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
- **推荐场景**: 详情显示、强调、冲击性信息
- **效果**: 引导关注、冲击力
- **示例**:
  - 重要数字显示
  - 问题核心展示
  - 差异化要点强调

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
- **效果**: 瞬间、节奏加快
- **示例**:
  - UI 操作步骤间
  - 快速演示
  - 有节奏的功能介绍

```json
{
  "transition": {
    "type": "cut",
    "duration_ms": 0
  }
}
```

### 按漏斗推荐过渡

| 漏斗阶段 | 推荐过渡 | 原因 |
|-------------|-------------------|------|
| 认知（LP/广告） | fade, zoom | 平稳、冲击 |
| 兴趣（Intro） | slideIn, fade | 动态、期待感 |
| 考虑（功能演示） | cut, slideIn | 节奏、效率 |
| 确信（架构） | fade, zoom | 详情、信任 |
| 持续（引导入门） | slideIn, cut | 步骤推进 |

---

## Emphasis（强调）

### 3 段强调级别

| Level | 用途 | 视觉效果 | 推荐效果音 |
|-------|------|---------|-----------|
| **high** | 最重要信息 | 大动画、明亮色彩 | whoosh, chime |
| **medium** | 重要要点 | 中等动画、强调色 | pop |
| **low** | 补充信息 | 适度强调、淡色 | none, ding |

### 使用指南

#### high（高强调）
- **推荐场景**:
  - Hook（最初冲击）
  - CTA（行动号召）
  - 差异化要点（Differentiator）
  - 惊人结果·数字

- **视觉效果**:
  - 文本大小: 特大
  - 色彩: 鲜艳（默认: `#00F5FF` 青色）
  - 动画: scale 1.2, bounce
  - 效果音: `whoosh` 或 `chime`

- **示例**:
  - "快 3 倍" → high emphasis
  - "立即免费试用" → high emphasis

```json
{
  "emphasis": {
    "level": "high",
    "text": ["快 3 倍"],
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
  - 文本大小: 大
  - 色彩: 强调色（默认: `#FFC700` 金色）
  - 动画: scale 1.1, fade-in
  - 效果音: `pop`

- **示例**:
  - "步骤 1: 设置" → medium emphasis
  - "您是否遇到过这样的问题？" → medium emphasis

```json
{
  "emphasis": {
    "level": "medium",
    "text": ["步骤 1: 设置"],
    "sound": "pop",
    "color": "#FFC700",
    "position": "top"
  }
}
```

#### low（低强调）
- **推荐场景**:
  - 补充信息
  - 附加功能的轻松介绍
  - 注释
  - 详细信息链接

- **视觉效果**:
  - 文本大小: 普通
  - 色彩: 淡色（默认: `#A8DADC` 浅蓝）
  - 动画: 仅 fade-in
  - 效果音: `none` 或 `ding`

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

### 效果音的选择

| Sound | 音色特征 | 推荐用途 |
|-------|---------|---------|
| **whoosh** | 风声、动感 | high emphasis、画面切换 |
| **chime** | 钟声、优美 | CTA、成功显示 |
| **pop** | 弹出、轻快 | medium emphasis、按钮显示 |
| **ding** | 小铃铛声 | low emphasis、轻微通知 |
| **none** | 无声 | 静态信息、连续显示 |

### 按漏斗推荐强调级别

| 漏斗阶段 | 主要强调 | 辅助强调 |
|-------------|---------|---------|
| 认知（LP/广告） | 高频 high | 适度 medium |
| 兴趣（Intro） | high 1-2 次 | 高频 medium |
| 考虑（功能演示） | medium 为主 | low 补充 |
| 确信（架构） | 适度 medium | 高频 low |
| 持续（引导入门） | high 目标 | medium 步骤 |

---

## Background（背景）

### 5 种背景样式

| Type | 视觉特征 | 用途 | 色彩示例 |
|------|---------|------|---------|
| **cyberpunk** | 霓虹、网格、未来感 | 科技系、先进性展示 | `#0a0e27` + `#00f5ff` |
| **corporate** | 精致、信任感、专业 | BtoB、企业 | `#1a1a2e` + `#16213e` |
| **minimal** | 简洁、干净、专注 | 说明为主、文档 | `#ffffff` + `#f0f0f0` |
| **gradient** | 多彩、动态、亲切 | BtoC、休闲 | `#667eea` → `#764ba2` |
| **particles** | 动态粒子、活力 | Hook、CTA、冲击 | `#000000` + particles |

### 使用指南

#### cyberpunk（赛博朋克）
- **推荐场景**:
  - 展示技术先进性
  - 开发者工具
  - AI/ML 功能介绍
  - 架构图

- **特征**:
  - 霓虹网格
  - 故障效果
  - 青·青色系色彩

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
  - 企业功能
  - 安全·可靠性展示
  - 成绩·案例介绍

- **特征**:
  - 深蓝系
  - 干净渐变
  - 稳重氛围

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
  - 希望内容专注
  - 复杂图表·代码显示
  - 引导入门
  - 文档式说明

- **特征**:
  - 白·灰色系
  - 简洁
  - 可读性优先

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
  - 亲切感展示
  - 介绍·CTA
  - 休闲基调

- **特征**:
  - 多彩渐变
  - 柔和印象
  - 视觉愉悦

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
  - 重要转换点
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

### 按漏斗推荐背景

| 漏斗阶段 | 推荐背景 | 原因 |
|-------------|---------|------|
| 认知（LP/广告） | particles, gradient | 视觉冲击 |
| 兴趣（Intro） | gradient, cyberpunk | 亲切、先进 |
| 考虑（功能演示） | minimal, corporate | 专注、信任 |
| 确信（架构） | corporate, cyberpunk | 专业 |
| 持续（引导入门） | minimal, gradient | 简洁、亲切 |

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
  - 过渡后视觉稳定
  - 前一场景余韵
  - 吸引注意的间隔

- **推荐值**:
  - `0f`: 过渡足够时
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
  - 音频结束后余韵
  - 确保 CTA 显示时间
  - 阅读时间保障

- **推荐值**:
  - `0f`: 立即进入下一个
  - `15-20f`: 标准余韵
  - `30f`: 充分阅读

```json
{
  "timing": {
    "delay_after": 20
  }
}
```

#### audio_start_offset（音频开始偏移）
- **用途**:
  - 场景显示后，音频开始前的等待
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

### 音频同步重要规则

> **重要**: 带旁白的视频请严格遵守以下内容

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
   场景开始 = 前一场景开始 + 前一场景长度 - 过渡长度
   音频开始 = 场景开始 + audio_start_offset
   ```

4. **确保余量**:
   - 过渡开始前音频结束
   - 至少确保 `delay_after: 20f`

---

## 最佳实践

### 1. 按漏斗组合演出

#### 90 秒 LP/广告预告（认知~兴趣）
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

#### 3 分钟 Intro 演示（兴趣→考虑）
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

### 2. 效果音的适当使用

**规则**:
- 1 个视频内效果音最多 **5-7 次**
- 连续场景中减少效果音（避免效果递减）
- high emphasis 必须附加效果音
- medium emphasis 选择性使用
- low emphasis 基本无声

### 3. 背景的统一感

**规则**:
- 1 个视频内背景类型最多 **2-3 种**
- 按段落统一（段落内使用相同背景）
- 仅 Hook/CTA 允许特殊背景（particles）

### 4. 过渡的节奏

**规则**:
- 不要连续使用同一过渡 3 次以上
- 组合快速展开（cut）和缓急（fade/zoom）
- 段落开始推荐 fade 或 zoom

### 5. 强调级别的分配

**规则（90 秒视频时）**:
- high: 2-3 次（Hook, Differentiator, CTA）
- medium: 5-8 次（主要信息）
- low: 适当（补充信息）

---

## 设计检查清单

设计场景演出时确认以下内容：

### 过渡
- [ ] 选择了符合场景目的的过渡
- [ ] 避免连续使用同一过渡
- [ ] duration_ms 是否适当（fade: 500ms, slideIn: 400ms, zoom: 600ms）

### 强调
- [ ] 强调级别是否适当（high: 仅最重要）
- [ ] 效果音使用次数是否适当（整体 5-7 次以内）
- [ ] 在 text 数组中指定了要强调的关键词

### 背景
- [ ] 选择了符合漏斗阶段的背景类型
- [ ] 段落内背景统一
- [ ] 是否指定了 primaryColor, secondaryColor

### 时机
- [ ] audio_start_offset 是否为 30f（标准）
- [ ] 场景长度 = audio_start + 音频长 + delay_after
- [ ] 过渡开始前音频结束

### 整体平衡
- [ ] 效果音使用 5-7 次以内
- [ ] 背景类型 2-3 种以内
- [ ] high emphasis 2-3 次以内

---

## 相关文档

- [generator.md](./generator.md) - 并行生成流程
- [visual-effects.md](./visual-effects.md) - 视觉效果库
- [schemas/direction.schema.json](../schemas/direction.schema.json) - 演出 schema 定义
- [schemas/emphasis.schema.json](../schemas/emphasis.schema.json) - 强调 schema 定义
- [schemas/animation.schema.json](../schemas/animation.schema.json) - 动画 schema 定义
