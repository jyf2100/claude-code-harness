---
name: generate-video
description: "自动生成产品演示视频。百闻不如一见。Use when user mentions '/generate-video', video generation, product demos, or visual documentation. Do NOT load for: embedding video players, live demos, video playback features. Requires Remotion setup."
description-en: "Auto-generate product demo videos. A picture worth thousand words, embodied. Use when user mentions '/generate-video', video generation, product demos, or visual documentation. Do NOT load for: embedding video players, live demos, video playback features. Requires Remotion setup."
description-zh: "自动生成产品演示视频。百闻不如一见，体现得淋漓尽致。触发短语：/generate-video、视频生成、产品演示、视觉文档。不用于：嵌入视频播放器、实时演示、视频播放功能。需要 Remotion 设置。"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task", "AskUserQuestion", "WebFetch"]
disable-model-invocation: true
argument-hint: "[demo|arch|release]"
context: fork
---

# Generate Video Skill

负责产品演示视频自动生成的技能群。

---

## 概述

在 `/generate-video` 命令内部使用的技能。
执行代码库分析 → 场景提案 → 并行生成的流程。

## 功能详情

| 功能 | 详情 |
|------|------|
| **最佳实践** | See [references/best-practices.md](${CLAUDE_SKILL_DIR}/references/best-practices.md) |
| **代码库分析** | See [references/analyzer.md](${CLAUDE_SKILL_DIR}/references/analyzer.md) |
| **场景规划** | See [references/planner.md](${CLAUDE_SKILL_DIR}/references/planner.md) |
| **并行场景生成** | See [references/generator.md](${CLAUDE_SKILL_DIR}/references/generator.md) |
| **视觉效果库** | See [references/visual-effects.md](${CLAUDE_SKILL_DIR}/references/visual-effects.md) |
| **AI图像生成** | See [references/image-generator.md](${CLAUDE_SKILL_DIR}/references/image-generator.md) |
| **图像质量判定** | See [references/image-quality-check.md](${CLAUDE_SKILL_DIR}/references/image-quality-check.md) |

## Prerequisites

- Remotion 已安装（`/remotion-setup`）
- Node.js 18+
- （可选）`GOOGLE_AI_API_KEY` - AI图像生成用

## `/generate-video` 流程

```
/generate-video
    │
    ├─[Step 1] 分析（analyzer.md）
    │   ├─ 框架检测
    │   ├─ 主要功能检测
    │   ├─ UI组件检测
    │   └─ 项目资产解析（Plans.md, CHANGELOG等）
    │
    ├─[Step 2] 场景提案（planner.md）
    │   ├─ 视频类型自动判定
    │   ├─ 场景构成提案
    │   └─ 用户确认
    │
    ├─[Step 2.5] 素材生成（image-generator.md）← NEW
    │   ├─ 素材必要判定（Intro、CTA等）
    │   ├─ Nano Banana Pro 生成2张图像
    │   ├─ Claude 质量判定（image-quality-check.md）
    │   └─ OK → 采用 / NG → 重新生成（最多3次）
    │
    └─[Step 3] 并行生成（generator.md）
        ├─ 场景并行生成（Task tool）
        ├─ 整合 + 转场
        └─ 最终渲染
```

## 执行步骤

1. 用户执行 `/generate-video`
2. Remotion 安装确认
3. 使用 `analyzer.md` 进行代码库分析
4. 使用 `planner.md` 进行场景提案 + 用户确认
5. 使用 `generator.md` 进行并行生成
6. 完成报告

## 视频类型（按漏斗分类）

| 类型 | 漏斗 | 时长参考 | 自动判定条件 | 构成核心 |
|--------|----------|----------|--------------|----------|
| **LP/广告预告片** | 认知〜兴趣 | 30-90秒 | 新项目 | 痛点→结果→CTA |
| **Intro演示** | 兴趣→考虑 | 2-3分 | UI变更检测 | 1个用例完整演示 |
| **发布说明** | 考虑→确信 | 1-3分 | CHANGELOG更新 | Before/After重视 |
| **架构讲解** | 确信→决策 | 5-30分 | 大规模结构变更 | 实际使用+证据 |
| **入门指南** | 继续・利用 | 30秒-数分 | 首次设置 | Aha体验的最短路径 |

> 详情: [references/best-practices.md](${CLAUDE_SKILL_DIR}/references/best-practices.md)

## 场景模板

### 90秒预告片（LP/广告用）

| 时间 | 场景 | 内容 |
|------|--------|------|
| 0-5秒 | Hook | 痛点 or 期望的结果 |
| 5-15秒 | Problem+Promise | 目标用户和承诺 |
| 15-55秒 | Workflow | 象征性工作流 |
| 55-70秒 | Differentiator | 差异化依据 |
| 70-90秒 | CTA | 下一步行动 |

### 3分钟Intro演示（考虑用）

| 时间 | 场景 | 内容 |
|------|--------|------|
| 0-10秒 | Hook | 结论+痛点 |
| 10-30秒 | UseCase | 用例宣言 |
| 30-140秒 | Demo | 实画面完整演示 |
| 140-170秒 | Objection | 解决一个常见顾虑 |
| 170-180秒 | CTA | 行动号召 |

### 通用场景

| 场景 | 推荐时长 | 内容 |
|--------|----------|------|
| Intro | 3-5秒 | Logo + 标语 |
| 功能演示 | 10-30秒 | Playwright 录屏 |
| 架构图 | 10-20秒 | Mermaid → 动画 |
| CTA | 3-5秒 | URL + 联系方式 |

> 详细模板: [${CLAUDE_SKILL_DIR}/references/best-practices.md](${CLAUDE_SKILL_DIR}/references/best-practices.md#模板)

## 音频同步规则（重要）

带旁白的视频必须遵守以下规则:

| 规则 | 值 |
|--------|-----|
| 音频开始 | 场景开始 + 30f（1秒等待） |
| 场景长度 | 30f + 音频长度 + 20f余白 |
| 转场 | 15f（与相邻场景重叠） |
| 场景开始计算 | 前场景开始 + 前场景长 - 15f |

**预先确认**: 使用 `ffprobe` 确认音频长度后再设计场景

> 详情: [${CLAUDE_SKILL_DIR}/references/generator.md](${CLAUDE_SKILL_DIR}/references/generator.md#音频同步规则重要)

## BGM 支持

| 项目 | 推荐值 |
|------|--------|
| 有旁白 | bgmVolume: 0.20 - 0.30 |
| 无旁白 | bgmVolume: 0.50 - 0.80 |
| 文件位置 | `public/BGM/` |

> 详情: [${CLAUDE_SKILL_DIR}/references/generator.md](${CLAUDE_SKILL_DIR}/references/generator.md#bgm支持)

## 字幕支持

| 规则 | 值 |
|--------|-----|
| 字幕开始 | 与音频开始相同 |
| 字幕duration | 音频长 + 10f |
| 字体 | Base64嵌入推荐 |

> 详情: [${CLAUDE_SKILL_DIR}/references/generator.md](${CLAUDE_SKILL_DIR}/references/generator.md#字幕支持)

## 视觉效果库

有冲击力的视频特效集:

| 特效 | 用途 |
|-----------|------|
| GlitchText | Hook、标题 |
| Particles | 背景、CTA收敛 |
| ScanLine | 解析中演出 |
| ProgressBar | 并行处理显示 |
| 3D Parallax | 卡片显示 |

> 详情: [references/visual-effects.md](${CLAUDE_SKILL_DIR}/references/visual-effects.md)

## Notes

- Remotion未安装时引导 `/remotion-setup`
- 并行生成数根据场景数自动调整（max 5）
- 生成的视频输出到 `out/` 目录
- AI生成图像保存到 `out/assets/generated/`
- `GOOGLE_AI_API_KEY` 未设置时跳过图像生成（使用现有素材或占位符）
