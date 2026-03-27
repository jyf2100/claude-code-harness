---
name: cc-update-review
description: "CC 更新集成的质量护栏。Feature Table 添加时检测"仅书写"，强制输出实现方案。Use when reviewing CC update integration PRs. Do NOT load for: implementation work, standard reviews, setup."
description-en: "Quality guardrail for CC update integration. Detects doc-only Feature Table additions and requires implementation proposals. Internal use only."
description-zh: "CC 更新集成的质量护栏。Feature Table 添加时检测"仅书写"，强制输出实现方案。触发短语：CC 更新集成审查。不用于：实现工作、标准审查、设置。"
user-invocable: false
allowed-tools: ["Read", "Grep", "Glob"]
---

# CC 更新审查护栏

防止 Claude Code 更新集成时出现"仅在 Feature Table 书写"的质量护栏。
自动分类 Feature Table 的添加是否伴随实现，如有不足则强制输出实现方案。

## 快速参考

此技能在以下情况触发：

- **CC 更新集成 PR** 审查时
- 检测到 **Feature Table**（`CLAUDE.md` / `docs/CLAUDE-feature-table.md`）有新行的 diff 时
- `/harness-review` 判定为 CC 集成 PR 时的内部调用

**不**触发的情况：

- 通常的实现工作（`/work`）
- 仅 Feature Table 以外的更改
- 设置/初始化工作

## 3 类别分类

Feature Table 添加的各项目分为以下 3 类。

### (A) 有实现

**定义**: Feature Table 的添加有对应的 hooks / scripts / agents / skills / core 实现更改包含在同一 PR 中。

**判定条件**：
- Feature Table 的行中提到的功能相关文件已更改
- hooks.json、技能 SKILL.md、代理 .md、scripts/*.sh、core/src/*.ts 中有 diff

**示例**：

| Feature Table 添加 | 对应的实现更改 | 判定 |
|-------------------|----------------|------|
| `PostCompact 钩子` | 新建 `hooks/post-compact-handler.sh` | A |
| `MCP Elicitation 对应` | hooks.json 添加 Elicitation 事件 + 创建 `elicitation-handler.sh` | A |
| `Worker maxTurns 限制` | `agents-v3/worker.md` 添加 maxTurns 字段 | A |

**结果**: OK。不需要额外操作。

---

### (B) 仅书写

**定义**: 仅在 Feature Table 添加了行，Harness 侧的实现更改完全没有。且不符合 CC 自动继承（类别 C）。

**判定条件**：
- Feature Table 有新行
- 同一 PR 中没有 hooks / scripts / agents / skills / core 相关更改
- 是 Harness 应提供独特价值的功能（设置、工作流集成、护栏等）

**示例**：

| Feature Table 添加 | 对应的实现更改 | 判定 |
|-------------------|----------------|------|
| `PreCompact 钩子` | 无（仅 Feature Table） | B |
| `Agent Teams` | 无（仅 Feature Table） | B |
| `Desktop Scheduled Tasks` | 无（仅 Feature Table） | B |

**结果**: NG。阻止 PR，要求提示实现方案。输出格式见后述。

---

### (C) CC 自动继承

**定义**: Claude Code 本体的性能改善、bug 修复、内部优化等，Harness 侧不需要更改的项目。

**判定条件**：
- 是 CC 本体的修复，Harness 没有 wrap/扩展的余地
- 性能改善、内存泄漏修复、UI 改善等
- 不影响 Harness 工作流的内部更改

**示例**：

| Feature Table 添加 | 理由 | 判定 |
|-------------------|------|------|
| `Streaming API memory leak fix` | CC 内部的内存泄漏修复。Harness 侧无需对应 | C |
| `Compaction image retention` | CC 在压缩时保留图片。Harness 无需更改 | C |
| `Parallel tool call fix` | CC 内部的并行执行修复。自动受益 | C |

**结果**: OK。但要在 Feature Table 的列中明确标注"CC 自动继承"。

## CC 更新 PR 检查清单

PR 审查时按顺序确认以下内容：

```
## CC 更新集成检查清单

### 1. Feature Table 差异提取
- [ ] 从 `CLAUDE.md` 或 `docs/CLAUDE-feature-table.md` 的 diff 列出添加行

### 2. 各项目分类
- [ ] 对添加的各行判定 A / B / C
- [ ] 确认类别 B 的项目为 0 件

### 3. 按类别确认
- [ ] (A) 有实现: 对应的实现文件是否正确链接
- [ ] (B) 仅书写: 是否提示了实现方案（非 0 件则阻止 PR）
- [ ] (C) CC 自动继承: Feature Table 是否明确标注"CC 自动继承"

### 4. CHANGELOG 确认
- [ ] 类别 A 的项目是否以"今まで / 今後"形式记载在 CHANGELOG
- [ ] 类别 C 的项目是否在 CHANGELOG 中记载为 CC 自动继承

### 分类结果

| # | Feature Table 项目 | 类别 | 对应文件 / 备注 |
|---|-------------------|------|----------------|
| 1 | （项目名） | A / B / C | （文件路径或备注） |
| 2 | （项目名） | A / B / C | （文件路径或备注） |
```

## 类别 B 检测时的输出格式

检测到 1 件以上类别 B 时，按以下格式输出实现方案。
**此格式输出是强制性的，不允许省略。**

```
## 类别 B 检测: 实现方案

### B-{编号}. {Feature Table 的项目名}

**现状**: 仅在 Feature Table 记载。Harness 侧无实现。

**Harness 独特价值**:
{Harness 应如何利用此功能的具体说明}

**实现方案**:

| 对象文件 | 更改内容 |
|---------|---------|
| `{文件路径}` | {具体更改内容} |
| `{文件路径}` | {具体更改内容} |

**用户体验改善**:
- 以前: {当前用户体验}
- 今后: {实现后的用户体验}

**实现优先级**: {高 / 中 / 低}
**预估工时**: {小 / 中 / 大}
```

### 输出示例

```
## 类别 B 检测: 实现方案

### B-1. Desktop Scheduled Tasks

**现状**: 仅在 Feature Table 记载。Harness 侧无实现。

**Harness 独特价值**:
将 Scheduled Tasks 与 Harness 工作流集成，可自动执行定期质量检查、
状态同步、内存整理。

**实现方案**:

| 对象文件 | 更改内容 |
|---------|---------|
| `skills/harness-work/references/scheduled-tasks.md` | 计划任务的模板和指南 |
| `scripts/setup-scheduled-tasks.sh` | 初始设置脚本 |
| `hooks/hooks.json` | Cron 触发器注册 |

**用户体验改善**:
- 以前: 用户必须手动执行定期任务
- 今后: Harness 自动执行定期质量检查并通知结果

**实现优先级**: 中
**预估工时**: 中
```

## 推荐"附加价值"列

建议在 Feature Table 添加以下列：

| Feature | Skill | Purpose | 附加价值 |
|---------|-------|---------|---------|
| PostCompact 钩子 | hooks | 上下文再注入 | A: 有实现 |
| Streaming leak fix | all | 内存泄漏修复 | C: CC 自动继承 |

此列可一目了然确认各项目的分类，防止类别 B 残留。

## 相关技能

- `harness-review` - 代码审查（判定 CC 集成 PR 时内部调用此技能）
- `harness-work` - 实现工作（基于类别 B 实现方案的工作时）
- `memory` - SSOT 管理（分类标准的决策记录）
