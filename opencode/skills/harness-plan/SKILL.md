---
name: harness-plan
description: "Harness v3 统一规划技能。负责任务规划、Plans.md 管理、进度同步。触发短语: 制定计划、添加任务、Plans.md 更新、标记完成、进度确认、harness-plan、harness-sync。不用于实现、审查、发布。"
description-en: "Unified planning skill for Harness v3. Handles task planning, Plans.md management, and progress sync. Use when user mentions: create a plan, add tasks, update Plans.md, mark complete, check progress, sync status, where am I, harness-plan, harness-sync. Do NOT load for: implementation, code review, or release tasks."
description-ja: "Harness v3 统一规划技能。负责任务规划、Plans.md 管理、进度同步。触发短语: 制定计划、添加任务、Plans.md 更新、标记完成、进度确认、harness-plan、harness-sync。不用于实现、审查、发布。"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "WebSearch", "Task"]
argument-hint: "[create|add|update|sync|sync --no-retro|--ci]"
---

# Harness Plan (v3)

Harness v3 的统一规划技能。
整合以下旧技能:

- `planning` (plan-with-agent) — 从想法落实到 Plans.md
- `plans-management` — 任务状态管理、标记更新
- `sync-status` — Plans.md 与实现的同步确认

## Quick Reference

| 用户输入 | 子命令 | 行为 |
|------------|------------|------|
| "制定计划" / "create a plan" | `create` | 对话式需求收集 → Plans.md 生成 |
| "添加任务" / "add a task" | `add` | 向 Plans.md 添加新任务 |
| "标记完成" / "mark complete" | `update` | 将任务标记更改为 cc:完成 |
| "现在在哪里" / "check progress" | `sync` | 比对实现与 Plans.md、同步 |
| `harness-sync` | `sync` | 进度确认（等效于独立 sync 命令） |
| `harness-plan create` | `create` | 计划创建 |

## 子命令详情

### create — 计划创建

See [references/create.md](${CLAUDE_SKILL_DIR}/references/create.md)

通过需求收集，生成可执行的 Plans.md。

**流程**:
1. 会话语境确认（从前面的讨论中提取或新需求收集）
2. 询问要构建什么（最多 3 个问题）
3. 技术调查（WebSearch）
4. 功能列表提取
5. 优先级矩阵（Required / Recommended / Optional）
6. TDD 采用判断（测试设计）
7. Plans.md 生成（带 `cc:TODO` 标记）
8. 下一步操作指引

**CI 模式** (`--ci`):
无需求收集。直接使用现有 Plans.md 仅进行任务分解。

### add — 任务添加

向 Plans.md 添加新任务。

```
harness-plan add 任务名: 详细说明 [--phase 阶段编号]
```

任务以 `cc:TODO` 标记添加。

### update — 标记更新

更改任务的状态标记。

```
harness-plan update [任务名|任务编号] [WIP|完成|blocked]
```

标记对应表:

| 命令 | 标记 |
|---------|---------|
| `WIP` | `cc:WIP` |
| `完成` / `done` | `cc:完成` |
| `blocked` | `blocked` |
| `TODO` | `cc:TODO` |

### sync — 进度同步

比对实现状态与 Plans.md，检测差异并更新。

See [references/sync.md](${CLAUDE_SKILL_DIR}/references/sync.md)

**流程**:
1. 获取 Plans.md 当前状态
2. 检测 Plans.md 格式（v1: 3 列 / v2: 5 列）
3. 从 git status / git log 获取实现状态
4. 确认代理跟踪（`.claude/state/agent-trace.jsonl`）
5. 检测 Plans.md 与实现的差异
6. 提出未更新标记的自动修正建议
7. 提示下一步操作

**回顾**（默认开启）:
若有 1 个以上 `cc:完成` 任务，自动执行回顾。
分析估算精度、阻塞原因模式、范围变动，记录学习成果。
可通过 `sync --no-retro` 明确跳过。

## Plans.md 格式规范

### 格式

```markdown
# [项目名称] Plans.md

创建日期: YYYY-MM-DD

---

## Phase N: 阶段名称

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| N.1  | 说明 | 测试通过 | - | cc:TODO |
| N.2  | 说明 | lint 错误 0 | N.1 | cc:WIP |
| N.3  | 说明 | 迁移可执行 | N.1, N.2 | cc:完成 |
```

**DoD（Definition of Done）**: 以一行描述可验证的完成条件。禁止使用"感觉不错""正常运行"等模糊表述。应以 Yes/No 可判定的形式。

**Depends**: 任务间依赖关系。`-`（无依赖）、任务编号（`N.1`）、逗号分隔（`N.1, N.2`）、阶段依赖（`Phase N`）。

### 标记列表

| 标记 | 含义 |
|---------|------|
| `pm:请求中` | PM 已请求 |
| `cc:TODO` | 未开始 |
| `cc:WIP` | 进行中 |
| `cc:完成` | Worker 作业完成 |
| `pm:已确认` | PM 审查完成 |
| `blocked` | 阻塞中（必须注明原因） |

## 相关技能

- `harness-sync` — 同步实现与 Plans.md
- `harness-work` — 实现已计划的任务
- `harness-review` — 审查实现
- `harness-setup` — 项目初始化
