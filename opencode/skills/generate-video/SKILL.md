---
name: generate-video
description: "自动生成产品演示视频。百闻不如一见，生动体现。Use when user mentions '/generate-video', video generation, product demos, or visual documentation. Do NOT load for: embedding video players, live demos, video playback features. Requires Remotion setup."
description-en: "Auto-generate product demo videos. A picture worth thousand words, embodied. Use when user mentions '/generate-video', video generation, product demos, or visual documentation. Do NOT load for: embedding video players, live demos, video playback features. Requires Remotion setup."
description-ja: "プロダクトデモ動画を自動生成。百聞は一見にしかず、を体現。Use when user mentions '/generate-video', video generation, product demos, or visual documentation. Do NOT load for: embedding video players, live demos, video playback features. Requires Remotion setup."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task", "AskUserQuestion", "WebFetch"]
disable-model-invocation: true
argument-hint: "[demo|arch|release]"
context: fork
---

# Generate Video Skill

负责自动生成产品说明视频的技能组。

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
| **AI 图像生成** | See [references/image-generator.md](${CLAUDE_SKILL_DIR}/references/image-generator.md) |
| **图像质量判定** | See [references/image-quality-check.md](${CLAUDE_SKILL_DIR}/references/image-quality-check.md) |

## Prerequisites

- Remotion 已设置（`/remotion-setup`）
- Node.js 18+
- （可选）`GOOGLE_AI_API_KEY` - 用于 AI 图像生成

## `/generate-video` 流程

```
/generate-video
    │
    ├─[Step 1] 分析（analyzer.md）
    │   ├─ 框架检测
    │   ├─ 主要功能检测
    │   ├─ UI 组件检测
    │   └─ 项目资产解析（Plans.md, CHANGELOG 等）
    │
    ├─[Step 2] 场景提案（planner.md）
    │   ├─ 视频类型自动判定
    │   ├─ 场景构成提案
    │   └─ 用户确认
    │
    ├─[Step 2.5] 素材生成（image-generator.md）← NEW
    │   ├─ 素材必要判定（intro、CTA 等）
    │   ├─ 用 Nano Banana Pro 生成 2 张
    │   ├─ Claude 进行质量判定（image-quality-check.md）
    │   └─ OK → 采用 / NG → 重新生成（最多 3 次）
    │
    └─[Step 3] 并行生成（generator.md）
        ├─ 场景并行生成（Task tool）
        ├─ 整合 + 过渡
        └─ 最终渲染
```

## 执行步骤

1. 用户执行 `/generate-video`
2. 确认 Remotion 设置
3. 用 `analyzer.md` 进行代码库分析
4. 用 `planner.md` 提出场景提案 + 用户确认
5. 用 `generator.md` 进行并行生成
6. 完成报告

## 视频类型（按漏斗分类）

| 类型 | 漏斗 | 时长参考 | 自动判定条件 | 构成核心 |
|--------|----------|----------|--------------|----------|
| **LP/广告预告** | 认知~兴趣 | 30-90秒 | 新项目 | 痛点→结果→CTA |
| **Intro 演示** | 兴趣→考虑 | 2-3分 | 检测到 UI 变更 | 1 个用例完整展示 |
| **发布说明** | 考虑→确信 | 1-3分 | CHANGELOG 更新 | 强调 Before/After |
| **架构讲解** | 确信→决策 | 5-30分 | 大规模结构变更 | 实际运营+证据 |
| **引导入门** | 持续·活用 | 30秒-数分 | 初次设置 | 到达 Aha 体验的最短路径 |

> 详情: [references/best-practices.md](${CLAUDE_SKILL_DIR}/references/best-practices.md)

## 场景模板

### 90 秒预告（LP/广告用）

| 时间 | 场景 | 内容 |
|------|--------|------|
| 0-5秒 | Hook | 痛点或期望结果 |
| 5-15秒 | Problem+Promise | 目标用户和承诺 |
| 15-55秒 | Workflow | 象征性工作流 |
| 55-70秒 | Differentiator | 差异化依据 |
| 70-90秒 | CTA | 下一步行动 |

### 3 分钟 Intro 演示（考虑用）

| 时间 | 场景 | 内容 |
|------|--------|------|
| 0-10秒 | Hook | 结论+痛点 |
| 10-30秒 | UseCase | 用例声明 |
| 30-140秒 | Demo | 实际画面完整展示 |
| 140-170秒 | Objection | 消除一个常见顾虑 |
| 170-180秒 | CTA | 行动号召 |

### 通用场景

| 场景 | 推荐时间 | 内容 |
|--------|----------|------|
| Intro | 3-5秒 | Logo + 标语 |
| 功能演示 | 10-30秒 | Playwright 截图 |
| 架构图 | 10-20秒 | Mermaid → 动画 |
| CTA | 3-5秒 | URL + 联系方式 |

> 详细模板: [${CLAUDE_SKILL_DIR}/references/best-practices.md](${CLAUDE_SKILL_DIR}/references/best-practices.md#模板)

## 音频同步规则（重要）

带旁白的视频必须遵守:

| 规则 | 值 |
|--------|-----|
| 音频开始 | 场景开始 + 30f（1 秒等待） |
| 场景长度 | 30f + 音频长度 + 20f 余量 |
| 过渡 | 15f（与相邻场景重叠） |
| 场景开始计算 | 前一场景开始 + 前一场景长 - 15f |

**事前确认**: 用 `ffprobe` 确认音频长度后再设计场景

> 详情: [${CLAUDE_SKILL_DIR}/references/generator.md](${CLAUDE_SKILL_DIR}/references/generator.md#音频同步规则重要)

## BGM 支持

| 项目 | 推荐值 |
|------|--------|
| 有旁白 | bgmVolume: 0.20 - 0.30 |
| 无旁白 | bgmVolume: 0.50 - 0.80 |
| 文件位置 | `public/BGM/` |

> 详情: [${CLAUDE_SKILL_DIR}/references/generator.md](${CLAUDE_SKILL_DIR}/references/generator.md#bgm-支持)

## 字幕支持

| 规则 | 值 |
|--------|-----|
| 字幕开始 | 与音频开始相同 |
| 字幕 duration | 音频长 + 10f |
| 字体 | 推荐 Base64 嵌入 |

> 详情: [${CLAUDE_SKILL_DIR}/references/generator.md](${CLAUDE_SKILL_DIR}/references/generator.md#字幕支持)

## 视觉效果库

用于制作有冲击力视频的特效集:

| 特效 | 用途 |
|-----------|------|
| GlitchText | Hook、标题 |
| Particles | 背景、CTA 收敛 |
| ScanLine | 分析中效果 |
| ProgressBar | 并行处理显示 |
| 3D Parallax | 卡片显示 |

> 详情: [references/visual-effects.md](${CLAUDE_SKILL_DIR}/references/visual-effects.md)

## Notes

- 若 Remotion 未设置，引导 `/remotion-setup`
- 并行生成数根据场景数自动调整（max 5）
- 生成的视频输出到 `out/` 目录
- AI 生成图像保存到 `out/assets/generated/`
- 若 `GOOGLE_AI_API_KEY` 未设置则跳过图像生成（使用现有素材或占位符）
