---
name: generate-video
description: "自动生成产品演示视频。百闻不如一见，体现得淋漓尽致。Use when user mentions '/generate-video', video generation, product demos, or visual documentation. Do NOT load for: embedding video players, live demos, video playback features. Requires Remotion setup."
description-en: "Auto-generate product demo videos. A picture worth thousand words, embodied. Use when user mentions '/generate-video', video generation, product demos, or visual documentation. Do NOT load for: embedding video players, live demos, video playback features. Requires Remotion setup."
description-zh: "自动生成产品演示视频。百闻不如一见，体现得淋漓尽致。触发短语：/generate-video、视频生成、产品演示、视觉文档。不用于：嵌入视频播放器、实时演示、视频播放功能。需要 Remotion 设置。"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task", "AskUserQuestion", "WebFetch"]
disable-model-invocation: true
argument-hint: "[demo|arch|release]"
context: fork
---

# Generate Video 技能

负责产品说明视频自动生成的技能群。

---

## 概要

`/generate-video` 命令内部使用的技能。
执行代码库分析 → 场景提案 → 并行生成的流程。

## 功能详情

| 功能 | 详情 |
|------|------|
| **最佳实践** | 见 [references/best-practices.md](${CLAUDE_SKILL_DIR}/references/best-practices.md) |
| **代码库分析** | 见 [references/analyzer.md](${CLAUDE_SKILL_DIR}/references/analyzer.md) |
| **场景规划** | 见 [references/planner.md](${CLAUDE_SKILL_DIR}/references/planner.md) |
| **并行场景生成** | 见 [references/generator.md](${CLAUDE_SKILL_DIR}/references/generator.md) |
| **视觉效果库** | 见 [references/visual-effects.md](${CLAUDE_SKILL_DIR}/references/visual-effects.md) |
| **AI 图片生成** | 见 [references/image-generator.md](${CLAUDE_SKILL_DIR}/references/image-generator.md) |
| **图片质量判定** | 见 [references/image-quality-check.md](${CLAUDE_SKILL_DIR}/references/image-quality-check.md) |

## Prerequisites

- Remotion 已设置（`/remotion-setup`）
- Node.js 18+
- （可选）`GOOGLE_AI_API_KEY` - AI 图片生成用

## `/generate-video` 流程

```
/generate-video
    │
    ├─[Step 1] 分析（analyzer.md）
    │   ├─ 框架检测
    │   ├─ 主要功能检测
    │   ├─ UI 组件检测
    │   └─ 项目资产分析（Plans.md, CHANGELOG 等）
    │
    ├─[Step 2] 场景提案（planner.md）
    │   ├─ 视频类型自动判定
    │   ├─ 场景构成提案
    │   └─ 用户确认
    │
    ├─[Step 2.5] 素材生成（image-generator.md）← NEW
    │   ├─ 素材必要性判定（intro、CTA 等）
    │   ├─ 用 Nano Banana Pro 生成 2 张
    │   ├─ Claude 质量判定（image-quality-check.md）
    │   └─ OK → 采用 / NG → 重新生成（最多 3 次）
    │
    └─[Step 3] 并行生成（generator.md）
        ├─ 场景并行生成（Task tool）
        ├─ 集成 + 过渡
        └─ 最终渲染
```

## 执行步骤

1. 用户执行 `/generate-video`
2. 确认 Remotion 设置
3. 用 `analyzer.md` 分析代码库
4. 用 `planner.md` 提案场景 + 用户确认
5. 用 `generator.md` 并行生成
6. 完成报告

## 视频类型（按漏斗）

| 类型 | 漏斗 | 长度参考 | 自动判定条件 | 构成核心 |
|------|------|----------|-------------|----------|
| **LP/广告 teaser** | 认知〜兴趣 | 30-90 秒 | 新项目 | 痛点→结果→CTA |
| **Intro 演示** | 兴趣→考虑 | 2-3 分钟 | 检测到 UI 更改 | 完整 1 个用例 |
| **发布说明** | 考虑→确信 | 1-3 分钟 | CHANGELOG 更新 | 强调 Before/After |
| **架构解说** | 确信→决策 | 5-30 分钟 | 大规模结构更改 | 实际运用+证据 |
| **Onboarding** | 继续·活用 | 30 秒-数分钟 | 初次设置 | Aha 体验的最短路径 |

> 详情: [references/best-practices.md](${CLAUDE_SKILL_DIR}/references/best-practices.md)

## 场景模板

### 90 秒 teaser（LP/广告用）

| 时间 | 场景 | 内容 |
|------|------|------|
| 0-5 秒 | Hook | 痛点或期望结果 |
| 5-15 秒 | Problem+Promise | 目标用户和承诺 |
| 15-55 秒 | Workflow | 象征性工作流 |
| 55-70 秒 | Differentiator | 差异化依据 |
| 70-90 秒 | CTA | 下一步 |

### 3 分钟 Intro 演示（考虑用）

| 时间 | 场景 | 内容 |
|------|------|------|
| 0-10 秒 | Hook | 结论+痛点 |
| 10-30 秒 | UseCase | 用例声明 |
| 30-140 秒 | Demo | 实际画面完整演示 |
| 140-170 秒 | Objection | 打消 1 个常见顾虑 |
| 170-180 秒 | CTA | 行动号召 |

### 通用场景

| 场景 | 推荐时间 | 内容 |
|------|----------|------|
| intro | 3-5 秒 | Logo + 标语 |
| 功能演示 | 10-30 秒 | Playwright 录制 |
| 架构图 | 10-20 秒 | Mermaid → 动画 |
| CTA | 3-5 秒 | URL + 联系方式 |

> 详情模板: [${CLAUDE_SKILL_DIR}/references/best-practices.md](${CLAUDE_SKILL_DIR}/references/best-practices.md#模板)

## 音频同步规则（重要）

有旁白的视频必须遵守以下规则：

| 规则 | 值 |
|------|-----|
| 音频开始 | 场景开始 + 30f（等待 1 秒） |
| 场景长度 | 30f + 音频长度 + 20f 余量 |
| 过渡 | 15f（与相邻场景重叠） |
| 场景开始计算 | 前场景开始 + 前场景长度 - 15f |

**事前确认**: 设计场景前用 `ffprobe` 确认音频长度

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
|------|-----|
| 字幕开始 | 与音频开始相同 |
| 字幕 duration | 音频长 + 10f |
| 字体 | 推荐 Base64 嵌入 |

> 详情: [${CLAUDE_SKILL_DIR}/references/generator.md](${CLAUDE_SKILL_DIR}/references/generator.md#字幕支持)

## 视觉效果库

面向有冲击力视频的特效集：

| 特效 | 用途 |
|------|------|
| GlitchText | Hook、标题 |
| Particles | 背景、CTA 收敛 |
| ScanLine | 分析中演出 |
| ProgressBar | 并行处理显示 |
| 3D Parallax | 卡片显示 |

> 详情: [references/visual-effects.md](${CLAUDE_SKILL_DIR}/references/visual-effects.md)

## Notes

- Remotion 未设置时引导 `/remotion-setup`
- 并行生成数根据场景数自动调整（max 5）
- 生成的视频输出到 `out/` 目录
- AI 生成图片保存到 `out/assets/generated/`
- `GOOGLE_AI_API_KEY` 未设置时跳过图片生成（使用现有素材或占位符）
