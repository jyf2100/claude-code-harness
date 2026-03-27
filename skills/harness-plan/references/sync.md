# sync 子命令 — 进度同步流程

对照实现状态和 Plans.md，检测并更新差异。

## Step 0：Plans.md 验证

确认 Plans.md 的存在和格式。有问题时立即引导并停止。

| 状态 | 引导 |
|------|------|
| Plans.md 不存在 | `未找到 Plans.md。请用 /harness-plan create 创建。` → **停止** |
| 头部没有 DoD / Depends 列（v1 格式） | `Plans.md 是旧格式（3 列）。请用 /harness-plan create 重新生成 v2（5 列）。现有任务会自动继承。` → **停止** |
| v2 格式（5 列） | 直接进入 Step 1 |

## Step 1：收集现状（并行）

```bash
# Plans.md 的状态
cat Plans.md

# Git 更改状态
git status
git diff --stat HEAD~3

# 最近提交历史
git log --oneline -10

# Agent Trace（最近编辑的文件）
tail -20 .claude/state/agent-trace.jsonl 2>/dev/null | jq -r '.files[].path' | sort -u
```

## Step 1.5：Agent Trace 分析

从 Agent Trace 获取最近的编辑历史，与 Plans.md 的任务对照：

```bash
# 最近编辑的文件列表
RECENT_FILES=$(tail -20 .claude/state/agent-trace.jsonl 2>/dev/null | \
  jq -r '.files[].path' | sort -u)

# 项目信息
PROJECT=$(tail -1 .claude/state/agent-trace.jsonl 2>/dev/null | \
  jq -r '.metadata.project')
```

**对照要点**：

| 检查项 | 检测方法 |
|--------|----------|
| Plans.md 中没有的文件编辑 | Agent Trace vs 任务描述 |
| 与任务描述不同的文件 | 预期文件 vs 实际编辑 |
| 长时间没有编辑的任务 | Agent Trace 时间线 vs WIP 期间 |

## Step 2：检测差异

| 检查项 | 检测方法 |
|--------|----------|
| 已完成但仍是 `cc:WIP` | 提交历史 vs 标记 |
| 已开始但仍是 `cc:TODO` | 更改文件 vs 标记 |
| 标记 `cc:完了` 但未提交 | git status vs 标记 |

### Artifact Hash 向后兼容

同时识别 `cc:完了 [a1b2c3d]` 格式（带 commit hash）和 `cc:完了`（无 hash）。

**匹配规则**：
- `cc:完了` → 视为无 hash 完成
- `cc:完了 [xxxxxxx]` → 视为带 hash 完成。保留 7 字符短 hash
- 带 hash 时，可与 `git log --oneline` 对照确认提交存在

> **向后兼容**：无 hash 格式继续有效。不破坏现有 Plans.md。

## Step 3：Plans.md 更新提案

检测到差异时，提议并执行：

```
需要更新 Plans.md

| Task | 当前 | 更改后 | 理由 |
|------|------|--------|------|
| XX   | cc:WIP | cc:完了 | 已提交 |
| YY   | cc:TODO | cc:WIP | 已编辑文件 |

是否更新？(yes / no)
```

## Step 4：输出进度摘要

```markdown
## 进度摘要

**项目**：{{project_name}}

| 状态 | 件数 |
|------|------|
| 未开始 (cc:TODO) | {{count}} |
| 工作中 (cc:WIP) | {{count}} |
| 已完成 (cc:完了) | {{count}} |
| PM 已确认 (pm:確認済) | {{count}} |

**进度率**：{{percent}}%

### 最近编辑的文件 (Agent Trace)
- {{file1}}
- {{file2}}
```

## Step 5：下一步行动建议

```
接下来要做的事

**优先 1**：{{任务}}
- 理由：{{请求中 / 等待解除阻塞}}

**推荐**：harness-work, harness-review
```

## 异常检测

| 情况 | 警告 |
|------|------|
| 多个 `cc:WIP` | 多个任务同时进行中 |
| `pm:依頼中` 未处理 | 先处理 PM 的请求 |
| 较大偏差 | 任务管理跟不上 |
| WIP 超过 3 天未更新 | 确认是否被阻塞 |

## Step 6：回顾（默认开启）

执行 `sync` 时，如有 1 件以上 `cc:完了` 任务则自动进行回顾。
可用 `--no-retro` 明确跳过。

### Step R1：收集已完成任务

```bash
# 从 Plans.md 提取 cc:完了 / pm:確認済 的任务
grep -E 'cc:完了|pm:確認済' Plans.md

# 最近的完成提交历史
git log --oneline --since="7 days ago"

# 更改规模
git diff --stat HEAD~10
```

### Step R2：回顾 4 项

| 项目 | 分析方法 |
|------|---------|
| **估时准确性** | 从 Plans.md 任务描述推断预期文件数 → 与 `git diff --stat` 实际更改文件数比较 |
| **阻塞原因** | 统计带 `blocked` 标记的任务的理由模式（技术性/外部依赖/规格不明确） |
| **质量标记命中率** | 标记 `[feature:security]` 等的任务是否实际出现相关问题 |
| **范围变动** | Plans.md 首次提交时的任务数 vs 当前任务数（添加/删除件数） |

### Step R3：输出回顾摘要

```markdown
## 回顾摘要

**期间**：{{start_date}} ~ {{end_date}}

| 指标 | 值 |
|------|-----|
| 已完成任务 | {{count}} 件 |
| 发生阻塞 | {{blocked_count}} 件 |
| 范围变动 | +{{added}} / -{{removed}} 件 |
| 估时准确性 | 预期 {{est}} 文件 → 实际 {{actual}} 文件 |

### 学习
- {{1-2 行学习内容}}

### 下次应用
- {{1-2 行改进行动}}
```

### Step R4：记录到 harness-mem

将回顾结果记录到 harness-mem，供下次 `create` 时参考。
记录位置：`.claude/agent-memory/` 下的相应代理内存。
