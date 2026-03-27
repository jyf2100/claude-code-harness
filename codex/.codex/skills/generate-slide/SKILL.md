---
name: generate-slide
description: "用 Nano Banana Pro 自动生成项目介绍幻灯片。幻灯片、单页介绍、视觉介绍时触发。不用于视频生成或演示文稿创建。"
description-ja: "Nano Banana Proでプロジェクト紹介スライドを自動生成。スライド、1枚紹介、ビジュアル紹介で起動。動画生成やデッキ作成では起動しない。"
description-en: "Generate project intro slides with Nano Banana Pro. Use when user mentions slide, project slide, 1-page summary, or visual introduction."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "AskUserQuestion"]
argument-hint: "[project-path|description]"
---

# Generate Slide Skill

使用 Nano Banana Pro（Gemini 3 Pro Image Preview）API 自动生成介绍/说明项目内容的单页幻灯片图像。

---

## 概要

3 种模式 x 各 2 张候选 = 共 6 张生成 → 按模式进行质量检查 → NG 则重试 → 各模式的最佳 1 张，共 3 张输出。

## 前提条件

- `GOOGLE_AI_API_KEY` 环境变量已设置
- Google AI Studio 中已启用 Nano Banana Pro（Gemini 3 Pro Image Preview）

## 功能详情

| 功能 | 详情 |
|------|------|
| **幻灯片图像生成** | See [references/slide-generator.md](${CLAUDE_SKILL_DIR}/references/slide-generator.md) |
| **质量判定** | See [references/slide-quality-check.md](${CLAUDE_SKILL_DIR}/references/slide-quality-check.md) |

---

## 执行流程

```
/generate-slide
    |
    +--[Step 1] 信息收集
    |   +-- 用户指定文本或代码库自动分析（README, package.json 等）
    |   +-- 抽取项目名、概要、主要功能、技术栈
    |
    +--[Step 2] 规格确认（AskUserQuestion）
    |   +-- 尺寸、宽高比（默认: 16:9 / 2K）
    |   +-- 风格（技术、休闲、商务等）
    |   +-- 想强调的重点（仅在不明确时提问）
    |
    +--[Step 3] 3 模式 x 2 张生成（Nano Banana Pro API x 6 次）
    |   +-- Pattern A: Minimalist（2 张）
    |   +-- Pattern B: Infographic（2 张）
    |   +-- Pattern C: Hero Visual（2 张）
    |
    +--[Step 4] 按模式进行质量检查
    |   +-- Claude 用 Read 读取各模式的 2 张图像
    |   +-- 5 级评分 → 选高分者作为候选
    |   +-- 两张都 2 分以下 → 改善提示词重试（最多 3 次）
    |   +-- 达到重试上限 → 向用户报告，选择继续或跳过
    |
    +--[Step 5] 输出最佳 3 张
        +-- 各模式的最佳 1 张复制到 selected/
        +-- 向用户展示结果列表（路径 + 分数 + 评价评论）
```

---

## 设计模式

| 模式 | 概念 | 特点 |
|---------|-----------|------|
| **Minimalist** | 以留白和排版为主 | clean, whitespace, typography-driven, elegant |
| **Infographic** | 数据/流程可视化 | data visualization, metrics, flow diagram, structured |
| **Hero Visual** | 大视觉 + 标语 | bold visual, impactful, hero image, catchy headline |

---

## 输出位置

```
out/slides/
+-- minimalist_1.png       # Pattern A 候选1
+-- minimalist_2.png       # Pattern A 候选2
+-- infographic_1.png      # Pattern B 候选1
+-- infographic_2.png      # Pattern B 候选2
+-- hero_1.png             # Pattern C 候选1
+-- hero_2.png             # Pattern C 候选2
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

1. **用户指定文本**: 如果参数中提供了项目说明则使用
2. **代码库自动分析**: 无参数时，自动分析以下内容
   - `README.md` — 项目概要
   - `package.json` / `Cargo.toml` / `pyproject.toml` — 项目名、说明、依赖
   - `CLAUDE.md` — 项目结构、目的
   - `Plans.md` — 进行中的任务（如有）

抽取信息：

| 项目 | 例 |
|------|-----|
| 项目名 | Claude Code Harness |
| 概要（1-2 句） | 用 Plan-Work-Review 自主运行 Claude Code 的插件 |
| 主要功能（3-5 个） | 技能管理、质量检查、并行执行 |
| 技术栈 | TypeScript, Node.js, Claude Code Plugin |
| 颜色（如有） | 品牌色或推测 |

### Step 2: 规格确认

用 AskUserQuestion 确认以下内容（有默认值，仅在不明确时提问）：

```
问题 1: 幻灯片的尺寸/宽高比是？
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

### Step 3: 图像生成

按照 `slide-generator.md` 的步骤，生成 3 模式 x 2 张 = 6 张。
各模式的生成是独立的，尽可能并行执行 curl：

```bash
# 并行执行示例（3 模式 x 2 张）
for pattern in minimalist infographic hero; do
  for i in 1 2; do
    # 执行 slide-generator.md 的 curl 模式
    # → 保存到 out/slides/${pattern}_${i}.png
  done
done
```

### Step 4: 质量检查

按照 `slide-quality-check.md` 的标准，评估各模式的 2 张：

1. 用 Read 读取各图像
2. 5 级评分（信息传达力、布局、文本可读性、专业感、品牌一致性）
3. 模式内选高分者作为候选
4. 两张都 2 分以下 → 改善提示词重新生成（最多 3 次）

### Step 5: 结果输出

```bash
# 复制最佳图像到 selected/
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

| 模式 | 候选1 | 候选2 | 采用 | 分数 |
|---------|-------|-------|------|--------|
| Minimalist | 3/5 | 4/5 | 候选2 | 4/5 |
| Infographic | 4/5 | 3/5 | 候选1 | 4/5 |
| Hero Visual | 5/5 | 4/5 | 候选1 | 5/5 |

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

### 所有模式都达到重试上限

用 AskUserQuestion 提供选项：

```
模式 {pattern} 的图像在 3 次重试后仍未达到标准。

选项:
1. 采用最高分图像并继续
2. 跳过此模式
3. 手动指定提示词重新生成
```

---

## 相关技能

- `generate-video` — 产品演示视频生成（共享图像生成引擎）
- `notebookLM` — 文档/幻灯片生成（另一种方法）
