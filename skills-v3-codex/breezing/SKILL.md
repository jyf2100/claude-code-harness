---
name: breezing
description: "团队执行模式（Codex 原生版）— harness-work 的团队协调别名。通过 breezing, 团队执行, 全部搞定 触发。"
description-en: "Team execution mode (Codex native) — backward-compatible alias for harness-work with team orchestration using Codex native subagent API."
description-ja: "团队执行模式（Codex 原生版）— harness-work 的团队协调别名。以下短语触发: breezing, 团队执行, 全部搞定。"
argument-hint: "[all|N-M|--max-workers N|--no-discuss]"
user-invocable: true
---

# Breezing — Team Execution Mode (Codex Native)

> **本 SKILL.md 是 Codex CLI 原生版。**
> Claude Code 版请参见 `skills-v3/breezing/SKILL.md`。
> 子代理 API 使用 Codex 的 `spawn_agent` / `send_input` / `wait_agent` / `close_agent`。

**向后兼容别名**: 以团队执行模式运行 `harness-work --breezing`。

## Quick Reference

```bash
breezing                        # 询问范围后执行
breezing all                    # 完成所有 Plans.md 任务
breezing 3-6                    # 完成任务 3〜6
breezing --max-workers 2 all    # 将独立任务的同时 spawn 上限设为 2
breezing --no-discuss all       # 跳过计划讨论完成所有任务
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `all` | 以所有未完成任务为对象 | - |
| `N` or `N-M` | 任务编号/范围指定 | - |
| `--max-workers N` | 独立任务的同时 spawn 数上限（breezing 独有选项） | 1（串行） |
| `--no-commit` | 不支持（Breezing 中 Worker 的临时 commit 和 Lead 的 cherry-pick 是必需的） | - |
| `--no-discuss` | 跳过计划讨论 | false |

## Execution

**本技能委托给 `harness-work --breezing`。** 请按以下设置执行:

1. **将参数传递给 `harness-work --breezing`**（`--max-workers N` 作为 breezing 独有选项解释，与 `harness-work` 的 `--parallel` 是不同概念）
2. **强制团队执行模式** — Lead → Worker spawn → codex exec Reviewer 三者分离
3. **Lead 专注 delegate** — 不直接写代码

### 与 `harness-work` 的区别

| 特征 | `harness-work` | `breezing` (本技能) |
|------|-----------------|------------------------|
| 默认模式 | Solo / Sequential | **Breezing（团队执行）** |
| 并行手段 | `codex exec` Bash 并行 | **通过 `spawn_agent` 的子代理委托** |
| Lead 的角色 | 协调+实现 | **delegate (专注协调)** |
| 审查 | Lead 自我审查 | **codex exec 独立审查** |
| 默认范围 | 下一个任务 | **全部** |

### Team Composition（Codex Native）

| Role | 执行方式 | 权限 | 职责 |
|------|---------|------|------|
| Lead | (self) | 继承当前会话 | 协调・指挥・任务分配・cherry-pick |
| Worker ×N | `spawn_agent({message, fork_context})` | 继承会话权限 | 实现（git worktree 分离） |
| Reviewer | `codex exec --sandbox read-only` | read-only | 独立审查 |

## Flow Summary

```
breezing [scope] [--max-workers N] [--no-discuss]
    │
    ↓ Load harness-work --breezing
    │
Phase 0: Planning Discussion（--no-discuss 时跳过）
Phase A: Pre-delegate（团队初始化 + worktree 准备）
Phase B: Delegate（Worker 实现 + codex exec 审查）
Phase C: Post-delegate（整合验证 + Plans.md 更新 + commit）
```

### Phase 0: Planning Discussion（结构化 3 问检查）

执行所有任务前，用以下 3 问确认计划的健全性。
`--no-discuss` 指定时全部跳过。

**Q1. 范围确认**:
> "将执行 {{N}} 件任务。范围合适吗？"

**Q2. 依赖关系确认**（仅当 Plans.md 有 Depends 列时）:
> "任务 {{X}} 依赖于 {{Y}}。执行顺序对吗？"

**Q3. 风险标记**（仅当有 `[needs-spike]` 任务时）:
> "任务 {{Z}} 是 [needs-spike]。要先 spike 吗？"

### Phase A: Pre-delegate

1. 读取 Plans.md，确定目标任务
2. 解析依赖图，决定执行顺序
3. 为每个任务创建 git worktree

### Phase B: Delegate（Codex Native Subagent Orchestration）

```
for task in execution_order:
    # B-0. 工作目录分离
    worktree_path = "/tmp/worker-{task.number}-$$"
    branch_name = "worker-{task.number}-$$"
    git worktree add -b {branch_name} {worktree_path}
    TASK_BASE_REF = git rev-parse HEAD

    # B-1. Worker spawn
    Plans.md: task.status = "cc:WIP"

    worker_id = spawn_agent({
        message: "工作目录: {worktree_path} 中工作。\n\n任务: {task.内容}\nDoD: {task.DoD}\n\n请实现。完成后请 git commit。\n\n完成时，请返回以下 JSON:\n{\"commit\": \"<hash>\", \"files_changed\": [...], \"summary\": \"...\"}",
        fork_context: true
    })
    wait_agent({ ids: [worker_id] })

    # B-2. Lead 执行审查（TASK_BASE_REF 起始）
    # 审查步骤与 harness-work 的"审查循环"部分完全相同:
    #   codex exec -C {worktree_path} - --sandbox read-only -o {REVIEW_OUT}
    #   → 用 grep '"verdict"' 提取 APPROVE/REQUEST_CHANGES
    VERDICT = review_task(worktree_path, TASK_BASE_REF)  # 参见 harness-work

    # B-3. 修正循环（REQUEST_CHANGES 时，最多 3 次）
    review_count = 0
    while VERDICT == "REQUEST_CHANGES" and review_count < 3:
        send_input({
            id: worker_id,
            message: "指出内容: {issues}\n请修正后 git commit --amend。修正后请再次输出 JSON。"
        })
        wait_agent({ ids: [worker_id] })
        VERDICT = review_task(worktree_path, TASK_BASE_REF)
        review_count++

    # B-4. Worker 终止
    close_agent({ id: worker_id })

    # B-5. 结果处理
    if VERDICT == "APPROVE":
        commit_hash = git("-C", worktree_path, "rev-parse", "HEAD")
        git cherry-pick --no-commit {commit_hash}
        git commit -m "{task.内容}"
        Plans.md: task.status = "cc:完了 [{short_hash}]"
    else:
        → 升级给用户（Plans.md 保持 cc:WIP）
        → 后续任务也停止

    # B-6. Worktree 清理
    git worktree remove {worktree_path}
    git branch -D {branch_name}

    # B-7. Progress feed
    print("📊 Progress: Task {completed}/{total} 完成 — {task.内容}")
```

### 独立任务的并行 spawn（`--max-workers N` 指定时）

有多个无依赖任务时，用 `--max-workers N` 控制同时 spawn 数:

> **`wait_agent` 的语义**: `wait_agent({ids: [a, b]})` 返回最先完成的 1 个（不是等待全部完成）。
> 因此，等待所有 Worker 完成需要用循环逐个调用 `wait_agent`。

```
# 独立任务 A, B 并行 spawn（各自 worktree 已分离）
worker_a = spawn_agent({ message: "工作目录: /tmp/worker-a-$$ ...", fork_context: true })
worker_b = spawn_agent({ message: "工作目录: /tmp/worker-b-$$ ...", fork_context: true })

# 逐个等待各 Worker 完成 → 审查 → cherry-pick（串行）
# wait_agent 返回第一个，所以其他 Worker 还在运行中
for worker_id in [worker_a, worker_b]:
    wait_agent({ ids: [worker_id] })    # 等待此 Worker 完成
    VERDICT = review_task(worktree_path, TASK_BASE_REF)  # 参见 harness-work
    # 修正循环（如需要）...
    close_agent({ id: worker_id })
    if VERDICT == "APPROVE":
        cherry-pick → Plans.md 更新
```

> **约束**: 只能并行化 Depends 为 `-` 的独立任务。
> 审查 → cherry-pick 是串行执行（因为写入 main 会冲突）。

### Worker 的输出契约

Worker 提示词中明确要求完成时返回以下 JSON:

```json
{
  "commit": "a1b2c3d",
  "files_changed": ["src/foo.ts", "tests/foo.test.ts"],
  "summary": "向 foo 模块添加 bar 功能"
}
```

Lead 解析此 JSON 获取 commit hash 和文件列表。

### Progress Feed（Phase B 中的进度通知）

```
📊 Progress: Task 1/5 完成 — "向 harness-work 添加失败重新工单化"
📊 Progress: Task 2/5 完成 — "向 harness-sync 添加 --snapshot"
```

### 完成报告（Phase C）

所有任务完成后，Lead 按以下步骤生成丰富完成报告:

1. 用 `git log --oneline {session_base_ref}..HEAD` 收集所有 cherry-pick 提交
2. 用 `git diff --stat {session_base_ref}..HEAD` 获取整体变更规模
3. 提取 Plans.md 的剩余任务
4. 按 Breezing 模板输出

## 与 Claude Code 版的差异

| 项目 | Claude Code 版 | Codex 原生版（本文件） |
|------|---------------|-------------------------------|
| Worker spawn | `Agent(subagent_type="worker", isolation="worktree")` | `spawn_agent({message, fork_context})` + `git worktree add` |
| 等待完成 | `Agent` 的返回值 | `wait_agent({ids: [id]})` |
| 修正指示 | `SendMessage(to: agentId, message: "...")` | `send_input({id, message})` |
| Worker 终止 | 自动 | `close_agent({id})` |
| 审查 | Codex exec → Reviewer agent fallback | 仅 `codex exec --sandbox read-only` |
| 权限 | `bypassPermissions` + hooks | `codex exec`: `--full-auto` / `spawn_agent`: 继承会话权限 |
| Agent Teams | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 环境变量 | Codex native（标准功能） |
| Worktree | `isolation="worktree"` 自动管理 | `git worktree add/remove` 手动管理 |
| 模式升级 | 4 个任务以上自动 | 仅 `--breezing` 明确指定时 |

## Related Skills

- `harness-work` — 从单一任务到团队执行（本体）
- `harness-sync` — 进度同步
- `harness-review` — 代码审查
