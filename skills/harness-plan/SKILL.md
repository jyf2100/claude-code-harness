---
name: harness-plan
description: "Harness v3 统一计划技能。负责任务计划、Plans.md 管理、进度同步。触发短语：创建计划、添加任务、更新 Plans.md、标记完成、确认进度、harness-plan、harness-sync。不用于：实现、代码审查或发布任务。"
description-en: "Unified planning skill for Harness v3. Handles task planning, Plans.md management, and progress sync. Use when user mentions: create a plan, add tasks, update Plans.md, mark complete, check progress, sync status, where am I, harness-plan, harness-sync. Do NOT load for: implementation, code review, or release tasks."
description-zh: "Harness v3 统一计划技能。负责任务计划、Plans.md 管理、进度同步。触发短语：创建计划、添加任务、更新 Plans.md、标记完成、确认进度、harness-plan、harness-sync。不用于：实现、代码审查或发布任务。"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "WebSearch", "Task"]
argument-hint: "[create|add|update|sync|sync --no-retro|--ci]"
---

# Harness Plan (v3)

Harness v3 的统一计划技能。
整合了以下 3 个旧技能：

- `planning` (plan-with-agent) — 从想法到 Plans.md 的落实
- `plans-management` — 任务状态管理、标记更新
- `sync-status` — Plans.md 与实现的同步确认

## 快速参考

| 用户输入 | 子命令 | 操作 |
|---------|-------|------|
| "创建计划" / "create a plan" | `create` | 对话式需求收集 → 生成 Plans.md |
| "添加任务" / "add a task" | `add` | 向 Plans.md 添加新任务 |
| "标记完成" / "mark complete" | `update` | 将任务标记更改为 cc:完了 |
| "现在在哪" / "check progress" | `sync` | 对照实现与 Plans.md 并同步 |
| `harness-sync` | `sync` | 进度确认（与独立 sync surface 等效） |
| `harness-plan create` | `create` | 创建计划 |

## 子命令详情

### create — 创建计划

See [references/create.md](${CLAUDE_SKILL_DIR}/references/create.md)

通过对话收集想法和需求，生成可执行的 Plans.md。

**流程**:
1. 确认对话上下文（从最近讨论提取 or 新对话收集）
2. 询问要做什么（最多 3 问）
3. 技术调查（WebSearch）
4. 提取功能列表
5. 优先级矩阵（Required / Recommended / Optional）
6. TDD 采用判断（测试设计）
7. 生成 Plans.md（带 `cc:TODO` 标记）
8. 指引下一步操作

**CI 模式** (`--ci`):
不进行对话。直接利用现有 Plans.md 仅进行任务分解。

### add — 添加任务

向 Plans.md 添加新任务。

```
harness-plan add 任务名: 详细说明 [--phase 阶段编号]
```

任务以 `cc:TODO` 标记添加。

### update — 更新标记

更改任务的状态标记。

```
harness-plan update [任务名|任务编号] [WIP|完了|blocked]
```

标记对应表：

| 命令 | 标记 |
|-----|------|
| `WIP` | `cc:WIP` |
| `完了` / `done` | `cc:完了` |
| `blocked` | `blocked` |
| `TODO` | `cc:TODO` |

### sync — 进度同步

对照实现情况与 Plans.md，检测差异并更新。

See [references/sync.md](${CLAUDE_SKILL_DIR}/references/sync.md)

**流程**:
1. 获取 Plans.md 当前状态
2. 检测 Plans.md 格式（v1: 3 列 / v2: 5 列）
3. 从 git status / git log 获取实现情况
4. 确认代理跟踪（`.claude/state/agent-trace.jsonl`）
5. 检测 Plans.md 与实现的差异
6. 提议自动修正未更新的标记
7. 提示下一步操作

**回顾**（默认开启）:
有 1 个以上 `cc:完了` 任务时自动执行回顾。
分析估算精度、阻塞原因模式、范围变动，记录学习心得。
可用 `sync --no-retro` 显式跳过。

## Plans.md 格式规范

### 格式

```markdown
# [项目名] Plans.md

创建日期: YYYY-MM-DD

---

## Phase N: 阶段名

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| N.1  | 说明 | 测试通过 | - | cc:TODO |
| N.2  | 说明 | lint 错误 0 | N.1 | cc:WIP |
| N.3  | 说明 | 迁移可执行 | N.1, N.2 | cc:完了 |
```

**DoD（Definition of Done）**: 用 1 行描述可验证的完成条件。禁止使用"感觉不错"、"正常运行"等表述。必须是可以 Yes/No 判断的形式。

**Depends**: 任务间依赖关系。`-`（无依赖）、任务编号（`N.1`）、逗号分隔（`N.1, N.2`）、阶段依赖（`Phase N`）。

### 标记列表

| 标记 | 含义 |
|-----|------|
| `pm:依赖中` | 已向 PM 请求 |
| `cc:TODO` | 未开始 |
| `cc:WIP` | 进行中 |
| `cc:完了` | Worker 工作完成 |
| `pm:确认済` | PM 审核完成 |
| `blocked` | 阻塞中（必须注明原因） |

## 相关技能

- `harness-sync` — 同步实现与 Plans.md
- `harness-work` — 实现计划的任务
- `harness-review` — 审查实现
- `harness-setup` — 项目初始化
