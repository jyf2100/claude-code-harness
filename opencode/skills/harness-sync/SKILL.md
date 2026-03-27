---
name: harness-sync
description: "Plans.md 与实现的进度同步。执行差异检测、标记更新、回顾。触发短语: harness-sync、sync-status、进度确认、现在在哪里、完成了多少。支持 --snapshot 保存进度快照。不用于规划、实现、审查、发布。"
description-en: "Progress sync between Plans.md and actual implementation. Detects drift, updates markers, runs retrospective. Use when user mentions: harness-sync, sync-status, sync progress, where am I, check progress, what's done. Supports --snapshot for progress snapshots. Do NOT load for: planning, implementation, review, or release."
description-ja: "Plans.md 与实现的进度同步。执行差异检测、标记更新、回顾。以下短语触发: harness-sync、sync-status、进度确认、现在在哪里、完成了多少。支持 --snapshot 保存进度快照。不用于规划、实现、审查、发布。"
allowed-tools: ["Read", "Edit", "Bash", "Grep", "Glob"]
argument-hint: "[--snapshot|--no-retro]"
---

# Harness Sync

将 Plans.md 与实现状态进行比对，检测差异并更新。
旧 `sync-status` 和 `harness-plan sync` 子命令的独立版。

## Quick Reference

| 用户输入 | 行为 |
|------------|------|
| `harness-sync` | 进度同步 + 回顾（默认开启） |
| `harness-sync --no-retro` | 仅进度同步（跳过回顾） |
| `harness-sync --snapshot` | 保存快照（进度的时间点记录） |
| "现在在哪里" / "进度确认" | 同上 |

## 选项

| 选项 | 说明 | 默认值 |
|----------|------|----------|
| `--snapshot` | 将当前进度保存为快照 | false |
| `--no-retro` | 跳过回顾 | false（默认执行） |

## Step 0: Plans.md 验证

确认 Plans.md 的存在和格式。若有问题立即提示并停止。

| 状态 | 提示 |
|------|------|
| Plans.md 不存在 | `未找到 Plans.md。请用 harness-plan create 创建。` → **停止** |
| 头部没有 DoD / Depends 列（v1 格式） | `Plans.md 是旧格式（3列）。请用 harness-plan create 重新生成为 v2（5列）。现有任务会自动继承。` → **停止** |
| v2 格式（5列） | 直接进入 Step 1 |

## Step 1: 现状收集（并行）

```bash
# Plans.md 状态
cat Plans.md

# Git 变更状态
git status
git diff --stat HEAD~3

# 最近提交历史
git log --oneline -10

# 代理跟踪（最近编辑的文件）
tail -20 .claude/state/agent-trace.jsonl 2>/dev/null | jq -r '.files[].path' | sort -u
```

## Step 1.5: Agent Trace 分析

从 Agent Trace 获取最近编辑历史，与 Plans.md 的任务进行比对:

```bash
# 最近编辑文件列表
RECENT_FILES=$(tail -20 .claude/state/agent-trace.jsonl 2>/dev/null | \
  jq -r '.files[].path' | sort -u)

# 项目信息
PROJECT=$(tail -1 .claude/state/agent-trace.jsonl 2>/dev/null | \
  jq -r '.metadata.project')
```

**比对要点**:

| 检查项 | 检测方法 |
|------------|----------|
| Plans.md 中没有的文件编辑 | Agent Trace vs 任务描述 |
| 与任务描述不同的文件 | 预期文件 vs 实际编辑 |
| 长时间无编辑的任务 | Agent Trace 时间序列 vs WIP 期间 |

## Step 2: 差异检测

| 检查项 | 检测方法 |
|------------|----------|
| 已完成但仍为 `cc:WIP` | 提交历史 vs 标记 |
| 已开始但仍为 `cc:TODO` | 变更文件 vs 标记 |
| 标记 `cc:完成` 但未提交 | git status vs 标记 |

## Step 3: Plans.md 更新建议

若检测到差异，提出建议并执行:

```
Plans.md 需要更新

| Task | 当前 | 变更后 | 原因 |
|------|------|--------|------|
| XX   | cc:WIP | cc:完成 | 已提交 |
| YY   | cc:TODO | cc:WIP | 文件已编辑 |

是否更新？ (yes / no)
```

## Step 4: 进度摘要输出

```markdown
## 进度摘要

**项目**: {{project_name}}

| 状态 | 数量 |
|----------|------|
| 未开始 (cc:TODO) | {{count}} |
| 进行中 (cc:WIP) | {{count}} |
| 已完成 (cc:完成) | {{count}} |
| PM已确认 (pm:已确认) | {{count}} |

**进度率**: {{percent}}%

### 最近编辑的文件 (Agent Trace)
- {{file1}}
- {{file2}}
```

## Step 4.5: 快照保存（指定 `--snapshot` 时）

若指定了 `--snapshot`，将当前进度状态保存为带时间戳的快照。

### 保存位置

以 JSON 格式保存到 `.claude/state/snapshots/` 目录:

```bash
SNAPSHOT_DIR="${PROJECT_ROOT}/.claude/state/snapshots"
mkdir -p "${SNAPSHOT_DIR}"
SNAPSHOT_FILE="${SNAPSHOT_DIR}/progress-$(date -u +%Y%m%dT%H%M%SZ).json"
```

### 快照内容

```json
{
  "timestamp": "2026-03-08T10:30:00Z",
  "phase": "Phase 26",
  "progress": {
    "total": 16,
    "todo": 5,
    "wip": 3,
    "done": 6,
    "confirmed": 2
  },
  "progress_rate": 50,
  "recent_commits": ["abc1234 feat: ...", "def5678 fix: ..."],
  "recent_files": ["skills/harness-work/SKILL.md", "..."],
  "notes": ""
}
```

### 差异比较

若存在上次快照，显示差异:

```markdown
## 快照差异

| 指标 | 上次 ({{prev_time}}) | 本次 | 变化 |
|------|---------------------|------|------|
| 进度率 | {{prev}}% | {{current}}% | +{{diff}}%pt |
| 完成任务 | {{prev_done}} | {{current_done}} | +{{diff_done}} |
| WIP 任务 | {{prev_wip}} | {{current_wip}} | {{diff_wip}} |
```

> **设计意图**: snapshot 是用户想"记录当前状态"时手动使用的。
> 与 breezing 中的自动进度推送（26.2.3）是不同功能。

## Step 5: 下一步操作建议

```
接下来要做的事

**优先 1**: {{任务}}
- 原因: {{请求中 / 等待解锁}}

**推荐**: harness-work, harness-review
```

## 异常检测

| 情况 | 警告 |
|------|------|
| 多个 `cc:WIP` | 多个任务同时进行中 |
| `pm:请求中` 未处理 | 先处理 PM 的请求 |
| 差异较大 | 任务管理跟不上 |
| WIP 超过 3 天无更新 | 确认是否被阻塞 |

## Step 6: 回顾（默认开启）

若有 1 个以上 `cc:完成` 任务，自动执行回顾。
可通过 `--no-retro` 明确跳过。

### Step R1: 完成任务收集

```bash
# 从 Plans.md 提取 cc:完成 / pm:已确认 的任务
grep -E 'cc:完成|pm:已确认' Plans.md

# 最近完成的提交历史
git log --oneline --since="7 days ago"

# 变更规模
git diff --stat HEAD~10
```

### Step R2: 回顾 4 项

| 项目 | 分析方法 |
|------|---------|
| **估算精度** | 从 Plans.md 任务描述推断预期文件数 → 与 `git diff --stat` 的实际变更文件数比较 |
| **阻塞原因** | 汇总带 `blocked` 标记的任务的原因模式（技术/外部依赖/规格不明确） |
| **质量标记命中率** | 带有 `[feature:security]` 等标记的任务是否实际出现了相关问题 |
| **范围变动** | Plans.md 首次提交时的任务数 vs 当前任务数（新增/删除数量） |

### Step R3: 回顾摘要输出

```markdown
## 回顾摘要

**期间**: {{start_date}} 〜 {{end_date}}

| 指标 | 值 |
|------|-----|
| 完成任务 | {{count}} 件 |
| 阻塞发生 | {{blocked_count}} 件 |
| 范围变动 | +{{added}} / -{{removed}} 件 |
| 估算精度 | 预期 {{est}} 文件 → 实际 {{actual}} 文件 |

### 学习
- {{1-2 行学习内容}}

### 下次应用
- {{1-2 行改善行动}}
```

### Step R4: 记录到 harness-mem

将回顾结果记录到 harness-mem，以便下次 `create` 时参考。
记录位置: `.claude/agent-memory/` 下对应的代理内存。

## 相关技能

- `harness-plan` — 计划创建、任务管理
- `harness-work` — 任务实现
- `harness-review` — 代码审查
