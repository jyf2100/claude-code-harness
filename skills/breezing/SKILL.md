---
name: breezing
description: "团队执行模式 — harness-work 的团队协调别名。触发短语：breezing、团队执行、全部完成。"
description-zh: "团队执行模式 — harness-work 的团队协调别名。触发短语：breezing、团队执行、全部完成。"
description-en: "Team execution mode — backward-compatible alias for harness-work with team orchestration."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Task", "WebSearch"]
argument-hint: "[all|N-M|--codex|--parallel N|--no-commit|--no-discuss|--auto-mode]"
user-invocable: true
---

# Breezing — 团队执行模式

> **向后兼容别名**: 以团队执行模式运行 `harness-work`。

## 快速参考

```bash
breezing                        # 询问范围后执行
breezing all                    # 完成 Plans.md 所有任务
breezing 3-6                    # 完成任务 3~6
breezing --codex all            # 用 Codex CLI 完成所有任务
breezing --parallel 2 all       # 2 并行完成所有任务
breezing --no-discuss all       # 跳过计划讨论完成所有任务
breezing --auto-mode all        # 在兼容父会话中尝试 Auto Mode rollout
```

## 选项

| 选项 | 说明 | 默认值 |
|-----|------|-------|
| `all` | 以所有未完成任务为目标 | - |
| `N` or `N-M` | 任务编号/范围指定 | - |
| `--codex` | 委托 Codex CLI 实现 | false |
| `--parallel N` | Implementer 并行数 | auto |
| `--no-commit` | 抑制自动提交 | false |
| `--no-discuss` | 跳过计划讨论 | false |
| `--auto-mode` | 显式启用 Auto Mode rollout。仅在父会话权限模式兼容时考虑采用 | false |

## 执行

**此技能委托给 `harness-work`。** 请使用以下设置运行 `harness-work`：

1. **将参数原样传递给 `harness-work`**
2. **强制团队执行模式** — Lead → Worker spawn → Reviewer spawn 的三者分离
3. **Lead 专注于委托** — 不直接写代码
4. **Auto Mode 作为 opt-in 处理** — `--auto-mode` 是兼容父会话的 rollout 标志

### 与 `harness-work` 的区别

| 特点 | `harness-work` | `breezing` (此技能) |
|-----|-----------------|---------------------|
| 并行方式 | 根据需要自动分割 | **Lead/Worker/Reviewer 角色分离** |
| Lead 角色 | 协调+实现 | **delegate (专注协调)** |
| 审查 | Lead 自我审查 | **独立 Reviewer** |
| 默认范围 | 下一个任务 | **全部** |

### 团队组成

| 角色 | Agent 类型 | 模式 | 职责 |
|-----|-----------|------|------|
| Lead | (self) | - | 协调、指挥、任务分配 |
| Worker ×N | `claude-code-harness:worker` | `bypassPermissions`（当前） / Auto Mode（后续）* | 实现 |
| Reviewer | `claude-code-harness:reviewer` | `bypassPermissions`（当前） / Auto Mode（后续）* | 独立审查 |

> *父会话或 frontmatter 为 `bypassPermissions` 时优先。分发模板目前仍使用 `bypassPermissions`，因此 Auto Mode 是后续 rollout 目标，不是默认行为。

### Codex 模式 (`--codex`)

将所有实现委托给 Codex CLI 的模式：

```bash
# 通过 stdin 管道传递提示词（应对 ARG_MAX）
CODEX_PROMPT=$(mktemp /tmp/codex-prompt-XXXXXX.md)
# 写入任务内容
cat "$CODEX_PROMPT" | ${TIMEOUT:+$TIMEOUT 120} codex exec - --sandbox workspace-write --full-auto 2>>/tmp/harness-codex-$$.log
rm -f "$CODEX_PROMPT"
```

## 流程摘要

```
breezing [scope] [--codex] [--parallel N] [--no-discuss] [--auto-mode]
    │
    ↓ 以团队模式加载 harness-work
    │
Phase 0: 计划讨论（用 --no-discuss 跳过）
Phase A: Pre-delegate（团队初始化）
Phase B: Delegate（Worker 实现 + Reviewer 审查）
Phase C: Post-delegate（整合验证 + Plans.md 更新 + commit）
```

### 进度推送（Phase B 中的进度通知）

Lead 在每个 Worker 任务完成时，以以下格式输出进度：

```
📊 Progress: Task {completed}/{total} 完成 — "{task_subject}"
```

**输出示例**:
```
📊 Progress: Task 1/5 完成 — "向 harness-work 添加失败重新票据化"
📊 Progress: Task 2/5 完成 — "向 harness-sync 添加 --snapshot"
📊 Progress: Task 3/5 完成 — "向 breezing 添加进度推送"
```

> **设计意图**: breezing 通常运行时间较长。
> 让用户瞥一眼终端就能知道"现在进行到哪了"。
> task-completed.sh 钩子通过 systemMessage 输出同等信息，与 Lead 的输出互补。

### 审查策略（所有模式统一）

Breezing 模式的审查也遵循 **Codex exec 优先 → 内部 Reviewer 回退** 的统一策略。
详见 `harness-work` 的"审查循环"部分。

- Worker 在 worktree 内实现、commit → 返回结果给 Lead
- Lead 用 Codex exec 审查（120s 超时，回退：Reviewer agent）
- REQUEST_CHANGES → Lead 通过 SendMessage 向 Worker 发送修复指示，Worker amend（最多 3 次）
- APPROVE → **Lead** cherry-pick 到 main → 更新 Plans.md 为 `cc:完了 [{hash}]`

### 完成报告（Phase C — Lead 生成）

所有任务完成后，**Lead** 按以下步骤生成丰富完成报告：

1. 用 `git log --oneline {base_ref}..HEAD` 收集所有 cherry-pick 提交
2. 用 `git diff --stat {base_ref}..HEAD` 获取整体变更规模
3. 提取 Plans.md 的 `cc:TODO` / `cc:WIP` 剩余任务
4. 按 `harness-work` 的"完成报告格式"的 Breezing 模板输出

> **生成者是 Lead**。不是 Worker 或 hook。Lead 在 Phase C 读取 git + Plans.md 生成。

### Phase 0: 计划讨论（结构化 3 问检查）

执行所有任务前，用以下 3 问确认计划的健全性。
指定 `--no-discuss` 时全部跳过。

**Q1. 范围确认**:
> "将执行 {{N}} 个任务。范围是否合适？"

太多时建议按优先级（Required > Recommended > Optional）筛选。

**Q2. 依赖关系确认**（仅当 Plans.md 有 Depends 列时）:
> "任务 {{X}} 依赖 {{Y}}。执行顺序对吗？"

读取 Depends 列，显示依赖链。有循环依赖则报错。

**Q3. 风险标志**（仅当有 `[needs-spike]` 任务时）:
> "任务 {{Z}} 是 [needs-spike]。先做 spike 吗？"

有未完成 spike 的 `[needs-spike]` 任务时，确认是否先执行 spike。

3 问都无问题则进入 Phase A（设计上总共 30 秒完成）。

### 基于依赖图的任务分配

Plans.md 有 Depends 列时（v2 格式），按依赖图执行任务：

1. 先执行 **Depends 为 `-` 的任务**。有多个独立任务可并行 spawn
2. 各 Worker 完成后，Lead 审查→cherry-pick（见 harness-work Phase B）
3. 依赖方任务 cherry-pick 到 main 后，执行依赖它的任务
4. 重复直到所有任务完成

> **注意**: 各任务的"Worker 完成→审查→cherry-pick"是串行处理。
> 可并行化的是独立任务（Depends 为 `-`）的 Worker spawn 部分。

## Codex 原生编排

Codex 中使用原生子代理。
代表性控制面是 `spawn_agent`, `wait`, `send_input`, `resume_agent`, `close_agent`。

> **Claude Code vs Codex 通信 API**（SSOT: `team-composition.md` 的 API 映射表）:
> - Claude Code: 用 `SendMessage(to: agentId, message: "...")` 向 Worker 发送修复指示
> - Codex: 用 `resume_agent(agent_id)` 恢复 Worker → `send_input(agent_id, "...")` 发送指示
>
> harness-work 的伪代码用 Claude Code 语法描述。Codex 环境中请按上述方式理解。

## 相关技能

- `harness-work` — 从单个任务到团队执行（本体）
- `harness-sync` — 进度同步
- `harness-review` — 代码审查（breezing 内自动启动）
