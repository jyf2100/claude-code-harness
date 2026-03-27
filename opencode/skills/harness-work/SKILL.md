---
name: harness-work
description: "Harness v3 统一执行技能。负责从单件任务到全并行团队执行的 Plans.md 任务。触发短语: 实现它、执行它、harness-work、全部做完、breezing、团队执行、parallel。不用于规划、审查、发布、设置。"
description-en: "Unified execution skill for Harness v3. Implements Plans.md tasks from single task to full parallel team runs. Use when user mentions: implement, execute, harness-work, do everything, build features, run tasks, breezing, team run, parallel. Do NOT load for: planning, code review, release, or setup."
description-ja: "Harness v3 统一执行技能。负责从单件任务到全并行团队执行的 Plans.md 任务。以下短语触发: 实现它、执行它、harness-work、全部做完、breezing、团队执行、parallel。不用于规划、审查、发布、设置。"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task"]
argument-hint: "[all] [task-number|range] [--codex] [--parallel N] [--no-commit] [--resume id] [--breezing] [--auto-mode]"
---

# Harness Work (v3)

Harness v3 统合执行技能。
整合以下旧技能：

- `work` — Plans.md 任务的实现（范围自动判断）
- `impl` — 功能实现（基于任务）
- `breezing` — 团队全自动执行
- `parallel-workflows` — 并行工作流优化
- `ci` — CI 失败时的恢复

## Quick Reference

| 用户输入 | 模式 | 行为 |
|------------|--------|------|
| `harness-work` | **auto** | 按任务数自动判定（见下） |
| `harness-work all` | **auto** | 用自动模式执行所有未完成任务 |
| `harness-work 3` | solo | 只执行任务 3 |
| `harness-work --parallel 5` | parallel | 用 5 个 worker 并行执行（强制） |
| `harness-work --codex` | codex | 委托给 Codex CLI（仅明确指定时） |
| `harness-work --breezing` | breezing | 强制团队执行 |

## Execution Mode Auto Selection（无标志时的自动判定）

没有明确模式标志（`--parallel`, `--breezing`, `--codex`）时，
根据目标任务数自动选择最优模式：

| 目标任务数 | 自动选择模式 | 理由 |
|-------------|---------------|------|
| **1 件** | Solo | 开销最小。直接实现最快 |
| **2~3 件** | Parallel（Task tool） | Worker 分离的益处开始显现的阈值 |
| **4 件以上** | Breezing | Lead 调整 + Worker 并行 + Reviewer 独立的三者分离更有效 |

### 规则

1. **明确标志总是覆盖自动模式**
   - `--parallel N` → Parallel 模式（不管任务数）
   - `--breezing` → Breezing 模式（不管任务数）
   - `--codex` → Codex 模式（不管任务数）
2. **`--codex` 仅在明确指定时触发**。因为有些环境未安装 Codex CLI，所以不自动选择
3. `--codex` 可与其他模式组合：`--codex --breezing` → Codex + Breezing

## 选项

| 选项 | 说明 | 默认值 |
|----------|------|----------|
| `all` | 所有未完成任务 | - |
| `N` or `N-M` | 任务编号/范围指定 | - |
| `--parallel N` | 并行 worker 数 | auto |
| `--sequential` | 强制串行执行 | - |
| `--codex` | 用 Codex CLI 委托实现（仅明确指定，不自动选择） | false |
| `--no-commit` | 抑制自动提交 | false |
| `--resume <id|latest>` | 恢复上次会话 | - |
| `--breezing` | Lead/Worker/Reviewer 团队执行 | false |
| `--no-tdd` | 跳过 TDD 阶段 | false |
| `--no-simplify` | 跳过 Auto-Refinement | false |
| `--auto-mode` | 明确启用 Auto Mode rollout。仅在父会话的 permission mode 兼容时考虑采用 | false |

> **Token Optimization (v2.1.69+)**: 对于不涉及 git 操作的轻量任务，
> 可以启用 plugin settings 的 `includeGitInstructions: false`
> 来减少提示词 token。

## 范围对话（无参数时）

```
harness-work
要做多少?
1) 下一个任务: Plans.md 的下一个未完成任务 → Solo 执行
2) 全部（推荐）: 完成所有剩余任务 → 按任务数自动选择模式
3) 指定编号: 输入任务编号（例: 3, 5-7）→ 按数量自动选择模式
```

有参数则立即执行（跳过对话）：
- `harness-work all` → 全部任务，自动选择模式
- `harness-work 3-6` → 4 件所以自动选择 Breezing

## Effort 级别控制（v2.1.68+, v2.1.72 简化）

Claude Code v2.1.68 起 Opus 4.6 默认为 **medium effort**（`◐`）。
v2.1.72 废弃 `max` 级别，简化为 3 档 `low(○)/medium(◐)/high(●)`。
`/effort auto` 可重置为默认。
复杂任务可用 `ultrathink` 关键字启用 high effort（`●`）。

### 多因素评分

任务开始时合计以下分数，**阈值 3 以上**注入 ultrathink：

| 因素 | 条件 | 分数 |
|------|------|--------|
| 文件数 | 变更对象 4 个文件以上 | +1 |
| 目录 | 包含 core/, guardrails/, security/ | +1 |
| 关键词 | 包含 architecture, security, design, migration | +1 |
| 失败历史 | agent memory 有同任务失败记录 | +2 |
| 明确指定 | PM 模板中有 ultrathink 记载 | +3（自动采用） |

### 注入方法

分数 ≥ 3 时，在 Worker spawn 提示词开头添加 `ultrathink`。
breezing 模式也应用相同逻辑（harness-work 统一管理）。

## 执行模式详情

### Solo 模式（1 件时的自动选择）

1. 读取 Plans.md，确定目标任务
   - **Plans.md 不存在时**: 自动调用 `harness-plan create --ci` → 生成 Plans.md 并继续
   - 头部没有 DoD / Depends 列时: `Plans.md 是旧格式。请用 harness-plan create 重新生成。` → **停止**
   - **对话中有未记载任务时**: 从紧接的对话上下文提取需求，以 `cc:TODO` 自动追加到 Plans.md
     - 提取逻辑: 从用户发言检测动作动词（「添加~」「修正~」「实现~」）
     - 追加时按 v2 格式（Task / 内容 / DoD / Depends / Status）
     - 追加后显示「已向 Plans.md 追加以下内容」（5 秒超时提示，默认：继续）
1.5. **确认任务背景**（30 秒）:
   - 从任务的「内容」和「DoD」推论显示**目的**（此任务解决的问题）1 行
   - 用 `git grep` / `Glob` 推论显示**影响范围**（变更涉及的文件/模块）
   - 推论有信心时: 直接进入实现（流程无延迟）
   - 推论没信心时: 向用户确认 1 个问题（「这个理解对吗？」）
2. 将任务更新为 `cc:WIP`
3. **TDD 阶段**（无 `[skip:tdd]` & 存在测试框架时）:
   a. 先创建测试文件（Red）
   b. 确认失败
4. 实现代码（Green）（Read/Write/Edit/Bash）
5. 用 `/simplify` 进行 Auto-Refinement（可用 `--no-simplify` 省略）
6. **自动审查阶段**（参见「审查循环」）:
   - 优先 Codex exec 执行审查 → 失败则回退到内部 Reviewer agent
   - REQUEST_CHANGES 时: 根据指正修正→再审查（最多 3 次）
   - APPROVE 则进入下一步
7. 用 `git commit` 自动提交（可用 `--no-commit` 省略）
8. 将任务更新为 `cc:完了`（附带 commit hash）
   - 用 `git log --oneline -1` 获取最近 commit hash（短格式 7 字符）
   - 将 Plans.md 的 Status 更新为 `cc:完了 [a1b2c3d]` 格式
   - 无 commit 时（`--no-commit`）则 hash 省略，只写 `cc:完了`
9. **丰富完成报告**（参见「完成报告格式」）
10. **失败时自动重新计划**（仅测试/CI 失败时）:
    - 确认测试运行结果
    - 失败时: 将修正任务方案保存到 state，经批准命令添加到 Plans.md（参见「失败任务的自动重新工单化」）
    - 成功时: 进入下一个任务

### Parallel 模式（2~3 件时的自动选择 / 用 `--parallel N` 强制）

用 N 个 worker 并行执行带 `[P]` 标记的任务。
用 `--parallel N` 明确指定时，不管任务数都使用此模式。
写入同一文件有冲突时用 git worktree 隔离。

### Codex 模式（仅 `--codex` 明确指定时）

```bash
TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")
CODEX_PROMPT=$(mktemp /tmp/codex-prompt-XXXXXX.md)
# 将任务内容写入唯一临时文件
# 通过 stdin 传递（"-" 是官方 stdin 指定。避免 ARG_MAX 超限）
cat "$CODEX_PROMPT" | ${TIMEOUT:+$TIMEOUT 120} codex exec - --sandbox workspace-write --full-auto 2>>/tmp/harness-codex-$$.log
rm -f "$CODEX_PROMPT"
```

将任务内容写入唯一临时文件，通过 stdin 委托给 Codex CLI。
并行执行时路径不会冲突，大提示词也不受 ARG_MAX 限制。
验证结果，不满足质量标准时自行修正。

### Breezing 模式（4 件以上自动选择 / 用 `--breezing` 强制）

用 Lead / Worker / Reviewer 角色分离进行团队执行。
Codex 中以 `spawn_agent`, `wait`, `send_input`, `resume_agent`, `close_agent`
的 native subagent orchestration 为前提，
不采用旧的 TeamCreate / TaskCreate 说明。

**权限策略**:
- 当前 shipped 默认是 `bypassPermissions`
- `--auto-mode` 作为兼容父会话的 opt-in rollout 标志
- 不在 `permissions.defaultMode` 或 agent frontmatter 的 `permissionMode` 中写入未文档化的 `autoMode` 值

> **CC v2.1.69+**: nested teammates 被平台侧禁止，
> 所以 Worker/Reviewer 提示词不需要冗余的 nested 防止措辞。

```
Lead（此代理）
├── Worker（task-worker agent）— 实现担当
└── Reviewer（code-reviewer agent）— 审查担当
```

**Phase A: Pre-delegate（准备）**:
1. 读取 Plans.md，确定目标任务
2. 解析依赖图，决定执行顺序（Depends 列）
3. 对各任务进行 effort 评分（ultrathink 注入判定）

**Phase B: Delegate（Worker spawn → 审查 → cherry-pick）**:

对各任务**按顺序**执行（按依赖顺序）:

> **API 注记**: 以下用 Claude Code API 语法描述。
> Codex 环境请将 `Agent(...)` 读作 `spawn_agent(...)`，`SendMessage(...)` 读作 `send_input(...)`。
> 详情参见 `team-composition.md` 的 API 映射表。

```
for task in execution_order:
    # B-1. Worker spawn（前台，worktree 隔离）
    # Agent tool 的返回值包含 agentId — 用于修正循环中的 SendMessage
    Plans.md: task.status = "cc:WIP"  # 着手时更新（未开始任务保持 cc:TODO）

    worker_result = Agent(
        subagent_type="claude-code-harness:worker",
        prompt="任务: {task.内容}\nDoD: {task.DoD}\nmode: breezing",
        isolation="worktree",
        run_in_background=false  # 前台执行 → 等待 Worker 完成
    )
    worker_id = worker_result.agentId  # 保持用于 SendMessage
    # worker_result 包含 {commit, worktreePath, files_changed, summary}

    # B-2. Lead 执行审查（优先 Codex exec）
    diff_text = git("-C", worker_result.worktreePath, "show", worker_result.commit)
    verdict = codex_exec_review(diff_text) or reviewer_agent_review(diff_text)

    # B-3. 修正循环（REQUEST_CHANGES 时，最多 3 次）
    # Worker 已在前台完成，但可用 SendMessage 重新开始
    # （CC: SendMessage(to: agentId) / Codex: resume_agent(agent_id) + send_input）
    review_count = 0
    latest_commit = worker_result.commit
    while verdict == "REQUEST_CHANGES" and review_count < 3:
        SendMessage(to=worker_id, message="指正内容: {issues}\n请修正并 amend")
        # Worker 修正 → amend → 返回更新后的 commit hash
        updated_result = wait_for_response(worker_id)
        latest_commit = updated_result.commit
        diff_text = git("-C", worker_result.worktreePath, "show", latest_commit)
        verdict = codex_exec_review(diff_text) or reviewer_agent_review(diff_text)
        review_count++

    # B-4. APPROVE → cherry-pick 到 main
    if verdict == "APPROVE":
        git cherry-pick --no-commit {latest_commit}  # worktree → main
        git commit -m "{task.内容}"
        Plans.md: task.status = "cc:完了 [{hash}]"
    else:
        → 升级给用户

    # B-5. Progress feed
    print("📊 Progress: Task {completed}/{total} 完成 — {task.内容}")
```

**Phase C: Post-delegate（整合/报告）**:
1. 汇总所有任务的 commit log
2. 输出**丰富完成报告**（参见「完成报告格式」的 Breezing 模板）
3. Plans.md 最终确认（所有任务是否都变成 cc:完了）

## CI 失败时的应对

CI 失败时：

1. 确认日志确定错误
2. 实施修正
3. 同一原因失败 3 次则停止自动修正循环
4. 汇总失败日志/尝试过的修正/遗留论点并升级

## 失败任务的自动重新工单化

任务完成后测试/CI 失败时，自动生成修正任务方案，批准后反映到 Plans.md：

### 触发条件

| 条件 | 行为 |
|------|----------|
| `cc:完了` 后测试失败 | 将修正任务方案保存到 state，等待批准 |
| CI 失败（3 次以内） | 实施修正，递增失败计数 |
| CI 失败（第 3 次） | 提示修正任务方案 + 升级 |

### 自动生成修正任务

1. 分类失败原因（syntax_error / import_error / type_error / assertion_error / timeout / runtime_error）
2. 将修正任务方案保存到 `.claude/state/pending-fix-proposals.jsonl`:
   - 编号: 原任务编号 + `.fix` 后缀（例: `26.1.fix`）
   - 内容: `fix: [原任务名] - [失败原因类别]`
   - DoD: 测试/CI 通过
   - Depends: 原任务编号
3. 用户发送 `approve fix <task_id>` 后以 `cc:TODO` 添加到 Plans.md
4. 用 `reject fix <task_id>` 丢弃方案。pending 只有 1 件时也可用 `yes` / `no` 响应

## 审查循环

实现完成后（步骤 5 之后）自动执行的质量验证阶段。
**所有模式通用**（Solo / Parallel / Breezing）统一应用。
Parallel 模式中各 Worker 作为 step 10（接受外部审查）执行相同循环。

### 审查执行的优先级

```
1. Codex exec（优先）
   ↓ codex 命令不存在或超时（120s）
2. 内部 Reviewer agent（回退）
```

### APPROVE / REQUEST_CHANGES 的判定标准

向审查者传递以下阈值标准，**仅用此标准**判定 verdict。
标准外的改善建议作为 `recommendations` 返回，但不影响 verdict。

| 严重度 | 定义 | 对 verdict 的影响 |
|--------|------|-----------------|
| **critical** | 安全漏洞、数据丢失风险、生产故障可能性 | 1 件即 → REQUEST_CHANGES |
| **major** | 现有功能破坏、与规格明显矛盾、测试不通过 | 1 件即 → REQUEST_CHANGES |
| **minor** | 命名改善、注释不足、风格不统一 | 不影响 verdict |
| **recommendation** | 最佳实践建议、将来改善方案 | 不影响 verdict |

> **重要**: 仅 minor / recommendation 时**必须返回 APPROVE**。
> 「有了更好的改善」不能作为 REQUEST_CHANGES 的理由。

### Codex exec 审查

将任务开始时的 HEAD 作为 `BASE_REF` 保存，以与该 ref 的差分作为审查对象。

```bash
# 任务开始时记录 base ref（Step 2 的 cc:WIP 更新前执行）
BASE_REF=$(git rev-parse HEAD)

# ... 实现完成后 ...

TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")
REVIEW_PROMPT=$(mktemp /tmp/codex-review-XXXXXX.md)
AI_RESIDUALS_JSON="$(bash scripts/review-ai-residuals.sh --base-ref "${BASE_REF}" 2>/dev/null || echo '{"tool":"review-ai-residuals","scan_mode":"diff","base_ref":null,"files_scanned":[],"summary":{"verdict":"APPROVE","major":0,"minor":0,"recommendation":0,"total":0},"observations":[]}')"
cat > "$REVIEW_PROMPT" <<REVIEW_EOF
请审查以下 diff 和静态检测结果。

## 判定标准（仅用此决定 verdict）
- critical（安全漏洞/数据丢失/生产故障）: 1 件即 → REQUEST_CHANGES
- major（现有功能破坏/规格矛盾/测试不通过）: 1 件即 → REQUEST_CHANGES
- minor（命名/注释/风格）: 不影响 verdict → APPROVE
- recommendation（改善建议）: 不影响 verdict → APPROVE

仅 minor / recommendation 时必须返回 APPROVE。

## 额外观察
- AI Residuals（mock / dummy / localhost / TODO / test.skip / 硬编码设置等）
- 使用 `scripts/review-ai-residuals.sh` 的结果作为依据之一，只有 major 级别的才反映到 verdict
- 单纯的残骸候补或临时实现注释保持为 minor / recommendation

请以 JSON 格式返回:
{"verdict": "APPROVE|REQUEST_CHANGES", "critical_issues": [], "major_issues": [], "recommendations": []}

## AI residual scan result
${AI_RESIDUALS_JSON}

## diff
REVIEW_EOF
git diff "${BASE_REF}" >> "$REVIEW_PROMPT"
cat "$REVIEW_PROMPT" | ${TIMEOUT:+$TIMEOUT 120} codex exec - --sandbox read-only 2>>/tmp/harness-review-$$.log
REVIEW_EXIT=$?
rm -f "$REVIEW_PROMPT"
```

### 内部 Reviewer agent 回退

Codex exec 不可用时（`command -v codex` 失败，或 exit code ≠ 0）：

```
Agent tool: subagent_type="reviewer"
prompt: "请审查以下变更。判定标准: critical/major → REQUEST_CHANGES，仅 minor/recommendation → APPROVE。diff: {git diff ${BASE_REF}}"
```

Reviewer agent 以 Read-only（Write/Edit/Bash 无效）安全执行审查。

### 修正循环（REQUEST_CHANGES 时）

```
review_count = 0
MAX_REVIEWS = 3

while verdict == "REQUEST_CHANGES" and review_count < MAX_REVIEWS:
    1. 分析审查指正（仅 critical / major）
    2. 对各指正实施修正
    3. 再次执行审查（相同判定标准/相同优先级）
    review_count++

if review_count >= MAX_REVIEWS and verdict != "APPROVE":
    → 升级给用户
    → 「已修正 3 次但以下 critical/major 指正仍存在」+ 显示指正列表
    → 等待用户判断（继续 / 中断）
```

### Breezing 模式下的应用

Breezing 模式中**Lead**执行审查循环（参见上述 Phase B）：

1. Worker 在 worktree 内实现/commit → 向 Lead 返回结果
2. Lead 用 Codex exec 审查（优先）/ Reviewer agent（回退）
3. REQUEST_CHANGES → Lead 用 SendMessage 向 Worker 发送修正指示 → Worker amend
4. 修正后，再次审查（最多 3 次）
5. APPROVE → Lead cherry-pick 到 main → 更新 Plans.md 为 `cc:完了 [{hash}]`

## 完成报告格式

任务完成时（`cc:完了` + commit 后）自动输出的可视化摘要。
目的是让非专家也能理解变更内容和影响。

### 模板

```
┌─────────────────────────────────────────────┐
│  ✓ Task {N} 完成: {任务名}                    │
├─────────────────────────────────────────────┤
│                                              │
│  ■ 做了什么                                 │
│    • {变更内容 1}                              │
│    • {变更内容 2}                              │
│                                              │
│  ■ 有什么变化                                │
│    Before: {旧行为}                            │
│    After:  {新行为}                            │
│                                              │
│  ■ 变更文件 ({N} files)                    │
│    {文件路径 1}                             │
│    {文件路径 2}                             │
│                                              │
│  ■ 剩余课题                                  │
│    • Task {X} ({status}): {内容}  ← Plans.md  │
│    • Task {Y} ({status}): {内容}  ← Plans.md  │
│    （Plans.md 有 {M} 件未完成任务）       │
│                                              │
│  commit: {hash} | review: {APPROVE}           │
└─────────────────────────────────────────────┘
```

### 生成规则

1. **做了什么**: 从 `git diff --stat HEAD~1` 和 commit message 自动提取。技术术语最小化，用动词开头
2. **有什么变化**: 从任务的「内容」和「DoD」推论 Before/After。重视用户体验变化
3. **变更文件**: 从 `git diff --name-only HEAD~1` 获取。超过 5 个文件则省略显示件数
4. **剩余课题**: 列出 Plans.md 的 `cc:TODO` / `cc:WIP` 任务。明确是否已记载在 Plans.md
5. **review**: 显示审查结果（APPROVE / REQUEST_CHANGES → APPROVE）

### Parallel 模式下的报告

- **1 个任务**（`--parallel` 强制时）: 使用 Solo 模板
- **多个任务**: 使用 Breezing 汇总模板（见下）

### Breezing 模式下的报告

所有任务完成后汇总输出。各任务用简化版（只显示做了什么 + commit hash）列表，
最后输出整体摘要（总变更文件数 + 剩余课题）：

```
┌─────────────────────────────────────────────┐
│  ✓ Breezing 完成: {N}/{M} 任务             │
├─────────────────────────────────────────────┤
│                                              │
│  1. ✓ {任务名 1}            [{hash1}]      │
│  2. ✓ {任务名 2}            [{hash2}]      │
│  3. ✓ {任务名 3}            [{hash3}]      │
│                                              │
│  ■ 整体变更                                 │
│    {N} files changed, {A} insertions(+),     │
│    {D} deletions(-)                          │
│                                              │
│  ■ 剩余课题                                  │
│    Plans.md 有 {K} 件未完成任务         │
│    • Task {X}: {内容}                         │
│                                              │
└─────────────────────────────────────────────┘
```

## 相关技能

- `harness-plan` — 计划要执行的任务
- `harness-sync` — 同步实现与 Plans.md
- `harness-review` — 审查实现
- `harness-release` — 版本 bump/发布
