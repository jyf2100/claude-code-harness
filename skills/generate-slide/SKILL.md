---
name: generate-slide
description: "用 Nano Banana Pro 自动生成项目介绍幻灯片。触发短语：幻灯片、项目介绍、一页概要、视觉介绍。不用于：视频生成、演示文稿制作。"
description-en: "Generate project intro slides with Nano Banana Pro. Use when user mentions slide, project slide, 1-page summary, or visual introduction."
description-zh: "用 Nano Banana Pro 自动生成项目介绍幻灯片。触发短语：幻灯片、项目介绍、一页概要、视觉介绍。不用于：视频生成、演示文稿制作。"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "AskUserQuestion"]
argument-hint: "[project-path|description]"
---

# Generate Slide 技能

使用 Nano Banana Pro（Gemini 3 Pro Image Preview）API 自动生成项目内容介绍/说明的单页幻灯片图片。

---

## 概要

3 种风格 × 各 2 张候选 = 共 6 张生成 → 按风格质量检查 → NG 则重试 → 各风格最佳 1 张，共 3 张输出。

## 前提条件

- `GOOGLE_AI_API_KEY` 环境变量已设置
- Google AI Studio 已启用 Nano Banana Pro（Gemini 3 Pro Image Preview）

## 功能详情

| 功能 | 详情 |
|------|------|
| **幻灯片图片生成** | 见 [references/slide-generator.md](${CLAUDE_SKILL_DIR}/references/slide-generator.md) |
| **质量判定** | 见 [references/slide-quality-check.md](${CLAUDE_SKILL_DIR}/references/slide-quality-check.md) |

---

## 执行流程

```
/generate-slide
    |
    +--[Step 1] 信息收集
    |   +-- 用户指定文本或代码库自动分析（README, package.json 等）
    |   +-- 提取项目名、概要、主要功能、技术栈
    |
    +--[Step 2] 规格确认（AskUserQuestion）
    |   +-- 尺寸·宽高比（默认: 16:9 / 2K）
    |   +-- 风格（技术、休闲、商务等）
    |   +-- 想强调的点（仅在模糊时提问）
    |
    +--[Step 3] 3 种风格 x 2 张生成（Nano Banana Pro API x 6 次）
    |   +-- Pattern A: Minimalist（2 张）
    |   +-- Pattern B: Infographic（2 张）
    |   +-- Pattern C: Hero Visual（2 张）
    |
    +--[Step 4] 按风格质量检查
    |   +-- Claude 用 Read 读取各风格的 2 张
    |   +-- 5 分制评分 → 分数高的作为候选
    |   +-- 两张都 2 分以下 → 改进提示词重试（最多 3 次）
    |   +-- 达到重试上限 → 向用户报告，选择继续或跳过
    |
    +--[Step 5] 输出最佳 3 张
        +-- 将各风格最佳 1 张复制到 selected/
        +-- 向用户展示结果列表（路径 + 分数 + 评价评论）
```

---

## 设计风格

| 风格 | 概念 | 特点 |
|------|------|------|
| **Minimalist** | 留白和排版为主 | clean, whitespace, typography-driven, elegant |
| **Infographic** | 数据/流程可视化 | data visualization, metrics, flow diagram, structured |
| **Hero Visual** | 大视觉 + 标语 | bold visual, impactful, hero image, catchy headline |

---

## 输出位置

```
out/slides/
+-- minimalist_1.png       # Pattern A 候选 1
+-- minimalist_2.png       # Pattern A 候选 2
+-- infographic_1.png      # Pattern B 候选 1
+-- infographic_2.png      # Pattern B 候选 2
+-- hero_1.png             # Pattern C 候选 1
+-- hero_2.png             # Pattern C 候选 2
+-- selected/
|   +-- minimalist.png     # Pattern A 最佳
|   +-- infographic.png    # Pattern B 最佳
|   +-- hero.png           # Pattern C 最佳
+-- quality-report.md      # 质量检查结果报告
```

---

## 执行步骤

### Step 1: 信息收集

按以下优先级收集项目信息：

1. **用户指定文本**: 参数中传入项目说明时使用
2. **代码库自动分析**: 无参数时，自动分析以下内容
   - `README.md` — 项目概要
   - `package.json` / `Cargo.toml` / `pyproject.toml` — 项目名、说明、依赖
   - `CLAUDE.md` — 项目构成、目的
   - `Plans.md` — 进行中的任务（如存在）

提取的信息：

| 项目 | 示例 |
|------|------|
| 项目名 | Claude Code Harness |
| 概要（1-2 句） | 用 Plan-Work-Review 自律运行 Claude Code 的插件 |
| 主要功能（3-5 个） | 技能管理、质量检查、并行执行 |
| 技术栈 | TypeScript, Node.js, Claude Code Plugin |
| 颜色（如有） | 品牌色或推断 |

### Step 2: 规格确认

用 AskUserQuestion 确认以下内容（有默认值，仅在模糊时提问）：

```
问题 1: 幻灯片的尺寸·宽高比是？
  - 16:9 / 2K（推荐）
  - 4:3 / 2K
  - 1:1 / 2K
  - 自定义

问题 2: 风格是？
  - 技术（深色主题、代码感）
  - 休闲（明亮、友好）
  - 商务（正式、信任感）
  - 创意（大胆、艺术向）
```

### Step 3: 图片生成

按 `slide-generator.md` 的步骤，生成 3 种风格 x 2 张 = 6 张。

各风格的生成独立，因此尽可能并行执行 curl：

```bash
# 并行执行示例（3 种风格 x 2 张）
for pattern in minimalist infographic hero; do
  for i in 1 2; do
    # 执行 slide-generator.md 的 curl 模式
    # → 保存到 out/slides/${pattern}_${i}.png
  done
done
```

### Step 4: 质量检查

按 `slide-quality-check.md` 的标准，评估各风格的 2 张：

1. 用 Read 读取各图片
2. 5 分制评分（信息传达力、布局、文本可读性、专业感、品牌一致性）
3. 风格内分数高的作为候选
4. 两张都 2 分以下 → 改进提示词重新生成（最多 3 次）

### Step 5: 结果输出

```bash
# 将最佳图片复制到 selected/
mkdir -p out/slides/selected
cp out/slides/minimalist_best.png out/slides/selected/minimalist.png
cp out/slides/infographic_best.png out/slides/selected/infographic.png
cp out/slides/hero_best.png out/slides/selected/hero.png
```

生成质量报告（`out/slides/quality-report.md`）：

```markdown
# Slide Quality Report

## 生成信息
- 项目: {project_name}
- 生成时间: {datetime}
- 宽高比: {aspect_ratio}
- 风格: {tone}

## 结果摘要

| 风格 | 候选 1 | 候选 2 | 采用 | 分数 |
|------|--------|--------|------|------|
| Minimalist | 3/5 | 4/5 | 候选 2 | 4/5 |
| Infographic | 4/5 | 3/5 | 候选 1 | 4/5 |
| Hero Visual | 5/5 | 4/5 | 候选 1 | 5/5 |

## 详细评价
...
```

---

## 错误处理

### GOOGLE_AI_API_KEY 未设置

```
GOOGLE_AI_API_KEY 未设置。

设置方法:
1. 在 Google AI Studio 获取 API 密钥: https://ai.google.dev/aistudio
2. export GOOGLE_AI_API_KEY="your-api-key"
```

### 所有风格都达到重试上限

用 AskUserQuestion 提供选项：

```
风格 {pattern} 的图片在 3 次重试后仍未达标。

选项:
1. 采用最高分图片继续
2. 跳过此风格
3. 手动指定提示词重新生成
```

---

## 相关技能

- `generate-video` — 产品演示视频生成（共享图片生成引擎）
- `notebookLM` — 文档/幻灯片生成（另一种方法）
