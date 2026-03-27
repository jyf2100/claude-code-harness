---
name: harness-work
description: "Harness v3 统合执行技能（Codex 原生版）。负责 Plans.md 任务从1件到全并行团队执行。以下短语启动: 实现、执行、harness-work、全部搞定、breezing、团队执行、parallel。不用于规划・审查・发布・设置。"
description-en: "Unified execution skill for Harness v3 (Codex native). Implements Plans.md tasks from single task to full parallel team runs."
description-ja: "Harness v3 统一执行技能（Codex 原生版）。Plans.md 任务从1件到全并行团队执行。"
argument-hint: "[all] [task-number|range] [--parallel N] [--no-commit] [--breezing]"
---

# Harness Work (v3) — Codex Native

> **本 SKILL.md 是 Codex CLI 原生版。**
> Claude Code 版请参见 `skills-v3/harness-work/SKILL.md`。
> 子代理 API 使用 Codex 的 `spawn_agent` / `send_input` / `wait_agent` / `close_agent`。

Harness v3 的统合执行技能。

## Quick Reference

| 用户输入 | 模式 | 动作 |
|------------|--------|------|
| `harness-work` | **solo** | 执行下一个未完成任务 1 件 |
| `harness-work all` | **sequential** | 串行执行所有未完成任务 |
| `harness-work 3` | solo | 仅执行任务 3 |
| `harness-work --parallel 3` | parallel | 用 `codex exec` 3 并行执行（Bash `&` + `wait`） |
| `harness-work --breezing` | breezing | 通过 `spawn_agent` 的团队执行（仅明确指定时） |

## Execution Mode Selection

> **重要**: Codex 中 `spawn_agent` 仅在用户明确要求团队执行・并行作业时使用。
> 不以任务数量为依据自动升级。

| 条件 | 模式 | 理由 |
|------|--------|------|
| 无参数 / 指定 1 件 | **Solo** | 直接实现最快 |
| `all` / 范围指定（无标志） | **Sequential** | 串行安全地逐个处理 |
| `--parallel N` | **Parallel** | `codex exec` 的 Bash 并行（仅明确指定时） |
| `--breezing` | **Breezing** | `spawn_agent` 团队执行（仅明确指定时） |

### 规则

1. **明确标志始终覆盖默认值**
2. **`--breezing` 和 `--parallel` 仅在明确指定时生效**。不以数量自动升级
3. `--parallel` 和 `--breezing` 互斥（不能同时指定）

## 选项

| 选项 | 说明 | 默认值 |
|----------|------|----------|
| `all` | 以所有未完成任务为对象 | - |
| `N` or `N-M` | 任务编号/范围指定 | - |
| `--parallel N` | `codex exec` Bash 并行数 | - |
| `--sequential` | 强制串行执行 | - |
| `--no-commit` | 抑制向 main 的最终提交（仅 Solo/Sequential。Breezing/Parallel 不支持） | false |
| `--breezing` | Lead/Worker/Reviewer 的团队执行 | false |
| `--no-tdd` | 跳过 TDD 阶段 | false |

## 范围对话（无参数时）

```
harness-work
要执行到什么程度?
1) 下一个任务: Plans.md 的下一个未完成任务 → Solo 执行
2) 全部: 串行执行所有剩余任务
3) 指定编号: 输入任务编号（例: 3, 5-7）
```

有参数则立即执行（跳过对话）。

## 执行模式详情

### Solo 模式

1. 读取 Plans.md，确定目标任务
   - **Plans.md 不存在时**: 自动调用 `harness-plan create --ci` → 生成 Plans.md 后继续
   - 头部没有 DoD / Depends 列时: 停止
   - **会话中有未记载任务时**: 从紧邻的会话语境中提取需求，以 `cc:TODO` 自动追加到 Plans.md
1.5. **任务背景确认**（30 秒）:
   - 从任务的"内容"和"DoD"推论并显示 1 行目的
   - 推论有信心时: 直接进入实现
   - 推论没信心时: 仅向用户确认 1 问
2. 将任务更新为 `cc:WIP`。记录 `TASK_BASE_REF=$(git rev-parse HEAD)`
3. **TDD 阶段**（无 `[skip:tdd]` & 测试框架存在时）:
   a. 先创建测试文件（Red）
   b. 确认失败
4. 实现代码（Green）
5. 用 `git commit` 自动提交（可用 `--no-commit` 省略）
6. **自动审查阶段**（参见"审查循环"）— 审查 TASK_BASE_REF..HEAD 的差异
7. 将任务更新为 `cc:完了 [hash]`
8. **丰富完成报告**（参见"完成报告格式"）
9. **失败时的自动重新规划**（仅测试/CI 失败时）

### Sequential 模式（指定 `all` 时的默认）

按依赖顺序逐个用 Solo 模式处理 Plans.md 的任务。
每个任务完成后更新 Plans.md，进入下一个任务。

### Parallel 模式（仅明确 `--parallel N` 时）

用 Bash 的 `&` + `wait` 并行执行 `codex exec` 的独立任务。

> **约束**: 不要并行化可能修改同一文件的任务。
> 用 `git worktree add` 为每个 Worker 分离工作目录，Lead 审查后 cherry-pick。

```bash
TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")

# 为每个 Worker 分离 worktree（注意 -b <branch> <path> 的顺序）
git worktree add -b worker-a-$$ /tmp/worker-a-$$
git worktree add -b worker-b-$$ /tmp/worker-b-$$

# 任务 A（用 -C 指定 worktree 为工作目录）
PROMPT_A=$(mktemp /tmp/codex-prompt-XXXXXX.md)
cat > "$PROMPT_A" << EOF
任务 A 的内容...

完成后，请输出以下 JSON 到 stdout:
{"commit": "<hash>", "files_changed": ["path1", "path2"], "summary": "..."}
EOF
cat "$PROMPT_A" | ${TIMEOUT:+$TIMEOUT 300} codex exec -C /tmp/worker-a-$$ - --sandbox workspace-write > /tmp/out-a-$$.json 2>>/tmp/harness-codex-$$.log &

# 任务 B（用 -C 指定 worktree 为工作目录）
PROMPT_B=$(mktemp /tmp/codex-prompt-XXXXXX.md)
cat > "$PROMPT_B" << EOF
任务 B 的内容...

完成后，请输出以下 JSON 到 stdout:
{"commit": "<hash>", "files_changed": ["path1", "path2"], "summary": "..."}
EOF
cat "$PROMPT_B" | ${TIMEOUT:+$TIMEOUT 300} codex exec -C /tmp/worker-b-$$ - --sandbox workspace-write > /tmp/out-b-$$.json 2>>/tmp/harness-codex-$$.log &

wait
rm -f "$PROMPT_A" "$PROMPT_B"

# Lead 从各 Worker 的输出 JSON 获取 commit hash，逐个审查 → cherry-pick
# ... 审查・cherry-pick 处理 ...

# 删除 worktree
git worktree remove /tmp/worker-a-$$
git worktree remove /tmp/worker-b-$$
```

### Breezing 模式（仅明确 `--breezing` 时）

通过 Lead / Worker / Reviewer 角色分离进行团队执行。
使用 Codex 的 native subagent API。

> **`--breezing` 仅在明确指定时**。仅在用户指示"用团队执行""用 breezing"时使用。

```
Lead (this agent)
├── Worker (spawn_agent) — 实现担当
│   各 Worker 在 git worktree 分离的工作目录中运行
└── Reviewer (codex exec --sandbox read-only) — 审查担当
```

**Phase A: Pre-delegate（准备）**:
1. 读取 Plans.md，确定目标任务
2. 解析依赖图，决定执行顺序（Depends 列）
3. 为每个任务创建对应的 git worktree

**Phase B: Delegate（Worker spawn → 审查 → cherry-pick）**:

对每个任务**逐个**执行以下内容（按依赖顺序）:

```
for task in execution_order:
    # B-0. 工作目录分离
    worktree_path = "/tmp/worker-{task.number}-$$"
    branch_name = "worker-{task.number}-$$"
    git worktree add -b {branch_name} {worktree_path}
    TASK_BASE_REF = git rev-parse HEAD  # 此任务专属的 base ref

    # B-1. Worker spawn（Codex native subagent）
    Plans.md: task.status = "cc:WIP"

    worker_id = spawn_agent({
        message: "工作目录: {worktree_path} 中工作。\n\n任务: {task.内容}\nDoD: {task.DoD}\n\n请实现。完成后请 git commit。\n\n完成时，请返回以下 JSON:\n{\"commit\": \"<hash>\", \"files_changed\": [\"path1\"], \"summary\": \"...\"}",
        fork_context: true
    })
    wait_agent({ ids: [worker_id] })
    # 从 Worker 输出获取 commit hash, files_changed, summary

    # B-2. Lead 执行审查（codex exec --sandbox read-only）
    # 仅审查此任务专属的 diff（TASK_BASE_REF 起始）
    diff_text = git("-C", worktree_path, "diff", TASK_BASE_REF, "HEAD")
    verdict = codex_exec_review(diff_text)  # 详情参见"审查循环"

    # B-3. 修正循环（REQUEST_CHANGES 时，最多 3 次）
    review_count = 0
    while verdict == "REQUEST_CHANGES" and review_count < 3:
        # Worker 已完成但未 close，所以可直接用 send_input 指示
        send_input({
            id: worker_id,
            message: "指出内容: {issues}\n请修正后 git commit --amend。修正后请再次输出 JSON。"
        })
        wait_agent({ ids: [worker_id] })
        # 再审查（TASK_BASE_REF 起始的差异）
        diff_text = git("-C", worktree_path, "diff", TASK_BASE_REF, "HEAD")
        verdict = codex_exec_review(diff_text)
        review_count++

    close_agent({ id: worker_id })

    # B-4. 结果处理
    if verdict == "APPROVE":
        # 将 worktree 的 commit cherry-pick 到 main
        commit_hash = git("-C", worktree_path, "rev-parse", "HEAD")
        git cherry-pick --no-commit {commit_hash}
        git commit -m "{task.内容}"
        Plans.md: task.status = "cc:完了 [{short_hash}]"
    else:
        → 升级给用户（Plans.md 保持 cc:WIP）
        # 跳过 B-5 以后，后续任务也停止

    # B-5. Worktree 清理
    git worktree remove {worktree_path}
    git branch -D {branch_name}

    # B-6. Progress feed
    print("📊 Progress: Task {completed}/{total} 完成 — {task.内容}")
```

**Phase C: Post-delegate（整合・报告）**:
1. 统计所有任务的 commit log
2. 输出**丰富完成报告**
3. Plans.md 最终确认（所有任务是否都是 cc:完了）

## CI 失败时的应对

1. 确认日志并识别错误
2. 实施修正
3. 同一原因失败 3 次则停止自动修正循环
4. 汇总失败日志・尝试过的修正・剩余论点后升级

## 失败任务的自动重新工单化

任务完成后测试/CI 失败时，自动生成修正任务方案，批准后反映到 Plans.md。

| 条件 | 动作 |
|------|----------|
| `cc:完了` 后测试失败 | 提示修正任务方案，等待批准 |
| CI 失败（3 次以内） | 实施修正 |
| CI 失败（第 3 次） | 提示修正任务方案 + 升级 |

## 审查循环

实现完成后自动执行的质量验证阶段。
**所有模式共用**（Solo / Sequential / Parallel / Breezing）统一适用。

### 审查执行（codex exec 方式）

用 `codex exec --sandbox read-only` 执行审查。
verdict 通过 `-o` 标志将最终消息写入文件，机械地获取 JSON。

> **差异起点**: 使用各任务专属的 `TASK_BASE_REF`（任务开始时的 HEAD）。
> 不是累积差异，仅审查该任务的变更。

```bash
# 任务开始时记录 base ref（更新 cc:WIP 前执行）
TASK_BASE_REF=$(git rev-parse HEAD)

# ... 实现完成后 ...

TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")
REVIEW_PROMPT=$(mktemp /tmp/codex-review-XXXXXX.md)
REVIEW_OUT=$(mktemp /tmp/codex-review-out-XXXXXX.json)
cat > "$REVIEW_PROMPT" << 'REVIEW_EOF'
请审查以下 diff。

## 判定标准（仅以此决定 verdict）
- critical（安全漏洞・数据丢失・生产故障）: 1 件以上 → REQUEST_CHANGES
- major（破坏现有功能・与规格矛盾・测试不通过）: 1 件以上 → REQUEST_CHANGES
- minor（命名・注释・风格）: 不影响 verdict → APPROVE
- recommendation（改善建议）: 不影响 verdict → APPROVE

仅有 minor / recommendation 时必须返回 APPROVE。

请仅输出以下 JSON（不要输出其他文本）:
{"verdict": "APPROVE", "critical_issues": [], "major_issues": [], "recommendations": []}
或
{"verdict": "REQUEST_CHANGES", "critical_issues": [...], "major_issues": [...], "recommendations": [...]}

## diff
REVIEW_EOF
git diff "${TASK_BASE_REF}" >> "$REVIEW_PROMPT"
cat "$REVIEW_PROMPT" | ${TIMEOUT:+$TIMEOUT 120} codex exec - --sandbox read-only -o "$REVIEW_OUT" 2>>/tmp/harness-review-$$.log
REVIEW_EXIT=$?
rm -f "$REVIEW_PROMPT"

# 从 JSON 提取 verdict（解析用 -o 写出的文件）
VERDICT=$(grep -o '"verdict":\s*"[^"]*"' "$REVIEW_OUT" | head -1 | grep -o 'APPROVE\|REQUEST_CHANGES')
rm -f "$REVIEW_OUT"
```

### APPROVE / REQUEST_CHANGES 的判定标准

| 重要度 | 定义 | 对 verdict 的影响 |
|--------|------|-----------------|
| **critical** | 安全漏洞、数据丢失风险、生产故障可能性 | 1 件以上 → REQUEST_CHANGES |
| **major** | 破坏现有功能、与规格明显矛盾、测试不通过 | 1 件以上 → REQUEST_CHANGES |
| **minor** | 命名改善、注释不足、风格不统一 | 不影响 verdict |
| **recommendation** | 最佳实践建议、未来改善方案 | 不影响 verdict |

> **重要**: 仅有 minor / recommendation 时**必须返回 APPROVE**。

### 修正循环（REQUEST_CHANGES 时）

```
review_count = 0
MAX_REVIEWS = 3

while verdict == "REQUEST_CHANGES" and review_count < MAX_REVIEWS:
    1. 分析审查指出（仅 critical / major 为对象）
    2. 针对每个指出实现修正
    3. git commit --amend
    4. 再次用 codex exec 执行审查（TASK_BASE_REF 起始）
    review_count++

if review_count >= MAX_REVIEWS and verdict != "APPROVE":
    → 升级给用户
    → "已修正 3 次但以下 critical/major 指出仍然存在" + 显示指出列表
    → 等待用户判断（继续 / 中断）
```

### Breezing 模式下的适用

1. Worker 在 worktree 内实现・commit → 用 `wait_agent` 等待完成
2. Lead 用 `codex exec --sandbox read-only` 审查（TASK_BASE_REF 起始）
3. REQUEST_CHANGES → 用 `send_input` 向 Worker 发送修正指示 → Worker 进行 amend
4. 修正后，再审查（最多 3 次）
5. 用 `close_agent` 终止 Worker
6. APPROVE → Lead cherry-pick 到 main → 将 Plans.md 更新为 `cc:完了 [{hash}]`

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
Worker 未返回 JSON 时用 `git log --oneline -1` 获取最近 commit。

## 完成报告格式

任务完成时自动输出的视觉摘要。

### Solo 模板

```
┌─────────────────────────────────────────────┐
│  ✓ Task {N} 完成: {任务名}                    │
├─────────────────────────────────────────────┤
│  ■ 做了什么                                  │
│    • {变更内容 1}                             │
│    • {变更内容 2}                             │
│  ■ 有什么变化                                │
│    Before: {旧行为}                           │
│    After:  {新行为}                           │
│  ■ 变更文件 ({N} files)                      │
│    {文件路径 1}                               │
│  ■ 剩余课题                                   │
│    Plans.md 有 {M} 件未完成任务               │
│  commit: {hash} | review: {APPROVE}          │
└─────────────────────────────────────────────┘
```

### Breezing 模板

```
┌─────────────────────────────────────────────┐
│  ✓ Breezing 完成: {N}/{M} 任务               │
├─────────────────────────────────────────────┤
│  1. ✓ {任务名 1}            [{hash1}]        │
│  2. ✓ {任务名 2}            [{hash2}]        │
│  ■ 整体变更                                   │
│    {N} files changed, {A} insertions(+),     │
│    {D} deletions(-)                          │
│  ■ 剩余课题                                   │
│    Plans.md 有 {K} 件未完成任务               │
└─────────────────────────────────────────────┘
```

## 与 Claude Code 版的差异

| 项目 | Claude Code 版 | Codex 原生版（本文件） |
|------|---------------|-------------------------------|
| Worker spawn | `Agent(subagent_type="worker")` | `spawn_agent({message, fork_context})` |
| 等待完成 | `Agent` 的返回值 | `wait_agent({ids: [id]})` |
| 修正指示 | `SendMessage(to: agentId)` | `send_input({id, message})` |
| Worker 终止 | 自动（Agent tool 返回值） | 用 `close_agent({id})` 明确终止 |
| Worktree 分离 | `isolation="worktree"` 自动管理 | 用 `git worktree add` 手动分离 |
| 权限 | `bypassPermissions` | `codex exec`: `--full-auto` / `spawn_agent`: 继承会话权限 |
| 审查 | Codex exec → Reviewer agent fallback | 仅 `codex exec --sandbox read-only` |
| verdict 获取 | 解析 Agent 响应 | `codex exec -o <file>` + grep 提取 |
| 模式自动升级 | 按任务数自动判定 | 仅明确标志（不自动升级） |
| Effort 控制 | `ultrathink` + `/effort` | config.toml 中的 `model_reasoning_effort` |
| Auto-Refinement | `/simplify` | 无 |

## 相关技能

- `harness-plan` — 规划要执行的任务
- `harness-sync` — 同步实现与 Plans.md
- `harness-review` — 实现的审查
- `harness-release` — 版本升级・发布
