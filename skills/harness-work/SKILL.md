---
name: harness-work
description: "Harness v3 统一执行技能。负责从单个任务到全并行团队执行的 Plans.md 任务实现。触发短语：实现、执行、harness-work、全部完成、构建功能、运行任务、breezing、团队运行、parallel。不用于：计划、代码审查、发布或设置。"
description-en: "Unified execution skill for Harness v3. Implements Plans.md tasks from single task to full parallel team runs. Use when user mentions: implement, execute, harness-work, do everything, build features, run tasks, breezing, team run, parallel. Do NOT load for: planning, code review, release, or setup."
description-zh: "Harness v3 统一执行技能。负责从单个任务到全并行团队执行的 Plans.md 任务实现。触发短语：实现、执行、harness-work、全部完成、构建功能、运行任务、breezing、团队运行、parallel。不用于：计划、代码审查、发布或设置。"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task"]
argument-hint: "[all] [task-number|range] [--codex] [--parallel N] [--no-commit] [--resume id] [--breezing] [--auto-mode]"
---

# Harness Work (v3)

Harness v3 的统一执行技能。
整合了以下旧技能：

- `work` — Plans.md 任务实现（自动范围判断）
- `impl` — 功能实现（基于任务）
- `breezing` — 团队全自动执行
- `parallel-workflows` — 并行工作流优化
- `ci` — CI 失败时的恢复

## 快速参考

| 用户输入 | 模式 | 操作 |
|---------|------|------|
| `harness-work` | **auto** | 根据任务数自动判断（见下文） |
| `harness-work all` | **auto** | 自动模式执行所有未完成任务 |
| `harness-work 3` | solo | 只执行任务 3 |
| `harness-work --parallel 5` | parallel | 5 个 worker 并行执行（强制） |
| `harness-work --codex` | codex | 委托给 Codex CLI（仅显式指定时） |
| `harness-work --breezing` | breezing | 强制团队执行 |

## 执行模式自动选择（无标志时）

当没有显式模式标志（`--parallel`, `--breezing`, `--codex`）时，
根据目标任务数自动选择最优模式：

| 目标任务数 | 自动选择模式 | 原因 |
|-----------|-------------|------|
| **1 个** | Solo | 开销最小。直接实现最快 |
| **2~3 个** | Parallel（Task tool） | Worker 分离的优势开始显现的阈值 |
| **4 个以上** | Breezing | Lead 协调 + Worker 并行 + Reviewer 独立的三者分离最有效 |

### 规则

1. **显式标志始终覆盖自动模式**
   - `--parallel N` → Parallel 模式（无论任务数）
   - `--breezing` → Breezing 模式（无论任务数）
   - `--codex` → Codex 模式（无论任务数）
2. **`--codex` 仅在显式指定时生效**。因为有些环境未安装 Codex CLI，所以不自动选择
3. `--codex` 可与其他模式组合：`--codex --breezing` → Codex + Breezing

## 选项

| 选项 | 说明 | 默认值 |
|-----|------|-------|
| `all` | 以所有未完成任务为目标 | - |
| `N` or `N-M` | 任务编号/范围指定 | - |
| `--parallel N` | 并行 worker 数 | auto |
| `--sequential` | 强制串行执行 | - |
| `--codex` | 委托 Codex CLI 实现（仅显式指定，不自动选择） | false |
| `--no-commit` | 抑制自动提交 | false |
| `--resume <id\|latest>` | 恢复上次会话 | - |
| `--breezing` | Lead/Worker/Reviewer 团队执行 | false |
| `--no-tdd` | 跳过 TDD 阶段 | false |
| `--no-simplify` | 跳过自动优化 | false |
| `--auto-mode` | 显式启用 Auto Mode rollout。仅在父会话的权限模式兼容时考虑采用 | false |

> **Token Optimization (v2.1.69+)**: 对于不涉及 git 操作的轻量任务，
> 可以启用 plugin settings 的 `includeGitInstructions: false`
> 来减少提示词 token 消耗。

## 范围对话框（无参数时）

```
harness-work
要执行到什么程度？
1) 下一个任务: Plans.md 的下一个未完成任务 → Solo 执行
2) 全部（推荐）: 完成所有剩余任务 → 根据任务数自动选择模式
3) 编号指定: 输入任务编号（例: 3, 5-7）→ 根据数量自动选择模式
```

有参数则立即执行（跳过对话）:
- `harness-work all` → 全部任务，自动选择模式
- `harness-work 3-6` → 4 个任务，自动选择 Breezing

## Effort 级别控制（v2.1.68+, v2.1.72 简化）

Claude Code v2.1.68 中 Opus 4.6 默认使用 **medium effort** (`◐`)。
v2.1.72 废弃了 `max` 级别，简化为 3 级 `low(○)/medium(◐)/high(●)`。
`/effort auto` 可重置为默认值。
对于复杂任务，使用 `ultrathink` 关键字启用 high effort (`●`)。

### 多因素评分

任务开始时合计以下分数，**阈值 3 以上**时注入 ultrathink：

| 因素 | 条件 | 分数 |
|-----|------|-----|
| 文件数 | 变更目标 4 个文件以上 | +1 |
| 目录 | 包含 core/, guardrails/, security/ | +1 |
| 关键词 | 包含 architecture, security, design, migration | +1 |
| 失败历史 | agent memory 中有同任务失败记录 | +2 |
| 显式指定 | PM 模板中有 ultrathink 记载 | +3（自动采用） |

### 注入方法

分数 ≥ 3 时，在 Worker spawn 提示词开头添加 `ultrathink`。
breezing 模式也应用相同逻辑（由 harness-work 统一管理）。

## 执行模式详情

### Solo 模式（1 个任务时自动选择）

1. 读取 Plans.md，确定目标任务
   - **Plans.md 不存在时**: 自动调用 `harness-plan create --ci` → 生成 Plans.md 并继续
   - 表头没有 DoD / Depends 列时: `Plans.md 是旧格式。请用 harness-plan create 重新生成。` → **停止**
   - **对话中有未记录任务时**: 从最近的对话上下文提取需求，以 `cc:TODO` 自动追加到 Plans.md
     - 提取逻辑: 从用户发言中检测动作动词（"添加~"、"修改~"、"实现~"）
     - 追加时遵循 v2 格式（Task / 内容 / DoD / Depends / Status）
     - 追加后显示"已向 Plans.md 追加以下内容"（5 秒超时提示，默认：继续）
1.5. **任务背景确认**（30 秒）:
   - 从任务的"内容"和"DoD"推断显示 **目的**（此任务要解决的问题）1 行
   - 用 `git grep` / `Glob` 推断显示 **影响范围**（变更涉及的文件/模块）
   - 如果推断有信心: 直接进入实现（不延迟流程）
   - 如果推断不确定: 只向用户确认 1 个问题（"这个理解对吗？"）
2. 将任务更新为 `cc:WIP`
3. **TDD 阶段**（无 `[skip:tdd]` & 存在测试框架时）:
   a. 先创建测试文件（Red）
   b. 确认失败
4. 实现代码（Green）（Read/Write/Edit/Bash）
5. `/simplify` 进行自动优化（可用 `--no-simplify` 省略）
6. **自动审查阶段**（见"审查循环"）:
   - 优先 Codex exec 审查 → 回退到内部 Reviewer agent
   - REQUEST_CHANGES 时: 根据指摘修改→再审查（最多 3 次）
   - APPROVE 则进入下一步
7. `git commit` 自动提交（可用 `--no-commit` 省略）
8. 将任务更新为 `cc:完了`（附带 commit hash）
   - 用 `git log --oneline -1` 获取最近的 commit hash（短格式 7 字符）
   - 将 Plans.md 的 Status 更新为 `cc:完了 [a1b2c3d]` 格式
   - 无 commit 时（`--no-commit` 时）只显示无 hash 的 `cc:完了`
9. **丰富完成报告**（见"完成报告格式"）
10. **失败时自动重新计划**（仅测试/CI 失败时）:
    - 确认测试执行结果
    - 失败时: 将修复任务方案保存到 state，通过批准命令追加到 Plans.md（见"失败任务的自动重新票据化"）
    - 成功时: 进入下一个任务

### Parallel 模式（2~3 个任务时自动选择 / `--parallel N` 强制）

用 N 个 worker 并行执行带 `[P]` 标记的任务。
用 `--parallel N` 显式指定时，无论任务数都使用此模式。
对同一文件的写入冲突时用 git worktree 隔离。

### Codex 模式（仅 `--codex` 显式指定时）

```bash
TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")
CODEX_PROMPT=$(mktemp /tmp/codex-prompt-XXXXXX.md)
# 将任务内容写入唯一临时文件
# 通过 stdin 传递（"-" 是官方 stdin 指定。避免 ARG_MAX 超限）
cat "$CODEX_PROMPT" | ${TIMEOUT:+$TIMEOUT 120} codex exec - --sandbox workspace-write --full-auto 2>>/tmp/harness-codex-$$.log
rm -f "$CODEX_PROMPT"
```

将任务内容写入唯一临时文件，通过 stdin 委托给 Codex CLI。
并行执行时路径也不会冲突，大提示词也不受 ARG_MAX 限制。
验证结果，不满足质量标准时自行修正。

### Breezing 模式（4 个以上任务时自动选择 / `--breezing` 强制）

通过 Lead / Worker / Reviewer 角色分离进行团队执行。
Codex 中使用 `spawn_agent`, `wait`, `send_input`, `resume_agent`, `close_agent`
进行原生子代理编排，
不采用基于旧 TeamCreate / TaskCreate 的说明。

**权限策略**:
- 当前默认为 `bypassPermissions`
- `--auto-mode` 作为兼容父会话的 opt-in rollout 标志处理
- 不要在 `permissions.defaultMode` 或 agent frontmatter 的 `permissionMode` 中写入未文档化的 `autoMode` 值

> **CC v2.1.69+**: 平台侧禁止嵌套 teammates，因此
> Worker/Reviewer 提示词中不添加冗余的嵌套防止措辞。

```
Lead (this agent)
├── Worker (task-worker agent) — 实现负责人
└── Reviewer (code-reviewer agent) — 审查负责人
```

**Phase A: Pre-delegate（准备）**:
1. 读取 Plans.md，确定目标任务
2. 解析依赖图，确定执行顺序（Depends 列）
3. 对各任务进行 effort 评分（ultrathink 注入判断）

**Phase B: Delegate（Worker spawn → 审查 → cherry-pick）**:

对各任务**顺序**执行（依赖顺序）:

> **API 注释**: 以下用 Claude Code 的 API 语法描述。
> Codex 环境中 `Agent(...)` → `spawn_agent(...)`, `SendMessage(...)` → `send_input(...)` 替换。
> 详见 `team-composition.md` 的 API 映射表。

```
for task in execution_order:
    # B-1. Worker spawn（前台，worktree 隔离）
    # Agent tool 返回值包含 agentId — 用于修复循环中的 SendMessage
    Plans.md: task.status = "cc:WIP"  # 开始时更新（未开始任务保持 cc:TODO）

    worker_result = Agent(
        subagent_type="claude-code-harness:worker",
        prompt="任务: {task.内容}\nDoD: {task.DoD}\nmode: breezing",
        isolation="worktree",
        run_in_background=false  # 前台执行 → 等待 Worker 完成
    )
    worker_id = worker_result.agentId  # 保留用于 SendMessage
    # worker_result 包含 {commit, worktreePath, files_changed, summary}

    # B-2. Lead 执行审查（优先 Codex exec）
    diff_text = git("-C", worker_result.worktreePath, "show", worker_result.commit)
    verdict = codex_exec_review(diff_text) or reviewer_agent_review(diff_text)

    # B-3. 修复循环（REQUEST_CHANGES 时，最多 3 次）
    # Worker 已在前台完成，但可通过 SendMessage 恢复
    # （CC: SendMessage(to: agentId) / Codex: resume_agent(agent_id) + send_input）
    review_count = 0
    latest_commit = worker_result.commit
    while verdict == "REQUEST_CHANGES" and review_count < 3:
        SendMessage(to=worker_id, message="指摘内容: {issues}\n请修复并 amend")
        # Worker 修复 → amend → 返回更新的 commit hash
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
        → 上报给用户

    # B-5. Progress feed
    print("📊 Progress: Task {completed}/{total} 完成 — {task.内容}")
```

**Phase C: Post-delegate（整合、报告）**:
1. 汇总所有任务的 commit log
2. 输出**丰富完成报告**（见"完成报告格式"的 Breezing 模板）
3. Plans.md 最终确认（所有任务是否都为 cc:完了）

## CI 失败时的处理

CI 失败时：

1. 确认日志并确定错误
2. 实施修复
3. 同一原因失败 3 次则停止自动修复循环
4. 汇总失败日志、尝试过的修复、遗留问题并上报

## 失败任务的自动重新票据化

任务完成后测试/CI 失败时，自动生成修复任务方案，批准后反映到 Plans.md：

### 触发条件

| 条件 | 操作 |
|-----|------|
| `cc:完了` 后测试失败 | 将修复任务方案保存到 state，等待批准 |
| CI 失败（3 次以内） | 实施修复，增加失败计数 |
| CI 失败（第 3 次） | 提示修复任务方案 + 上报 |

### 修复任务的自动生成

1. 分类失败原因（syntax_error / import_error / type_error / assertion_error / timeout / runtime_error）
2. 将修复任务方案保存到 `.claude/state/pending-fix-proposals.jsonl`:
   - 编号: 原任务编号 + `.fix` 后缀（例: `26.1.fix`）
   - 内容: `fix: [原任务名] - [失败原因类别]`
   - DoD: 测试/CI 通过
   - Depends: 原任务编号
3. 用户发送 `approve fix <task_id>` 则以 `cc:TODO` 追加到 Plans.md
4. `reject fix <task_id>` 则废弃方案。只有 1 个待处理时也可用 `yes` / `no` 回答

## 审查循环

实现完成后（步骤 5 之后）自动执行的质量验证阶段。
**所有模式通用**（Solo / Parallel / Breezing）统一应用。
Parallel 模式中各 Worker 作为 step 10（外部审查接收）执行相同循环。

### 审查执行的优先顺序

```
1. Codex exec（优先）
   ↓ codex 命令不存在或超时（120s）
2. 内部 Reviewer agent（回退）
```

### APPROVE / REQUEST_CHANGES 的判定标准

向审查者传递以下阈值标准，**仅按此标准**判定 verdict。
标准外的改进建议作为 `recommendations` 返回，不影响 verdict。

| 严重度 | 定义 | 对 verdict 的影响 |
|-------|------|-----------------|
| **critical** | 安全漏洞、数据丢失风险、生产环境故障可能性 | 1 件即 → REQUEST_CHANGES |
| **major** | 现有功能破坏、与规格明显矛盾、测试不通过 | 1 件即 → REQUEST_CHANGES |
| **minor** | 命名改进、注释不足、风格不统一 | 不影响 verdict |
| **recommendation** | 最佳实践建议、未来改进方案 | 不影响 verdict |

> **重要**: 仅 minor / recommendation 时**必须返回 APPROVE**。
> "有更好"不是 REQUEST_CHANGES 的理由。

### Codex exec 审查

将任务开始时的 HEAD 作为 `BASE_REF` 保留，以该 ref 的差异作为审查对象。

```bash
# 任务开始时记录 base ref（Step 2 更新 cc:WIP 之前执行）
BASE_REF=$(git rev-parse HEAD)

# ... 实现完成后 ...

TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")
REVIEW_PROMPT=$(mktemp /tmp/codex-review-XXXXXX.md)
AI_RESIDUALS_JSON="$(bash scripts/review-ai-residuals.sh --base-ref "${BASE_REF}" 2>/dev/null || echo '{"tool":"review-ai-residuals","scan_mode":"diff","base_ref":null,"files_scanned":[],"summary":{"verdict":"APPROVE","major":0,"minor":0,"recommendation":0,"total":0},"observations":[]}')"
cat > "$REVIEW_PROMPT" <<REVIEW_EOF
请审查以下 diff 和静态检测结果。

## 判定标准（仅以此决定 verdict）
- critical（安全漏洞、数据丢失、生产故障）: 1 件即 → REQUEST_CHANGES
- major（现有功能破坏、规格矛盾、测试不通过）: 1 件即 → REQUEST_CHANGES
- minor（命名、注释、风格）: 不影响 verdict → APPROVE
- recommendation（改进建议）: 不影响 verdict → APPROVE

仅 minor / recommendation 时必须返回 APPROVE。

## 附加观点
- AI Residuals（mock / dummy / localhost / TODO / test.skip / 硬编码设置等）
- 使用 `scripts/review-ai-residuals.sh` 的结果作为依据之一，只将 major 级别的反映到 verdict
- 单纯的残留候选或临时实现注释保留在 minor / recommendation

请返回 JSON 格式:
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

Codex exec 不可用时（`command -v codex` 失败，或 exit code ≠ 0）:

```
Agent tool: subagent_type="reviewer"
prompt: "请审查以下变更。判定标准: critical/major → REQUEST_CHANGES，仅 minor/recommendation → APPROVE。diff: {git diff ${BASE_REF}}"
```

Reviewer agent 以 Read-only（Write/Edit/Bash 无效）安全地执行审查。

### 修复循环（REQUEST_CHANGES 时）

```
review_count = 0
MAX_REVIEWS = 3

while verdict == "REQUEST_CHANGES" and review_count < MAX_REVIEWS:
    1. 分析审查指摘（仅 critical / major）
    2. 对各指摘实施修复
    3. 再次执行审查（相同判定标准、相同优先顺序）
    review_count++

if review_count >= MAX_REVIEWS and verdict != "APPROVE":
    → 上报给用户
    → "已修复 3 次但以下 critical/major 指摘仍存在" + 显示指摘列表
    → 等待用户判断（继续 / 中断）
```

### Breezing 模式中的应用

Breezing 模式中由 **Lead** 执行审查循环（见上文 Phase B）:

1. Worker 在 worktree 内实现、commit → 返回结果给 Lead
2. Lead 用 Codex exec 审查（优先）/ Reviewer agent（回退）
3. REQUEST_CHANGES → Lead 通过 SendMessage 向 Worker 发送修复指示 → Worker amend
4. 修复后再次审查（最多 3 次）
5. APPROVE → Lead cherry-pick 到 main → 更新 Plans.md 为 `cc:完了 [{hash}]`

## 完成报告格式

任务完成时（`cc:完了` + commit 后）自动输出的可视化摘要。
目的是让非专家也能理解变更内容和影响。

### 模板

```
┌─────────────────────────────────────────────┐
│  ✓ 任务 {N} 完成: {任务名}                    │
├─────────────────────────────────────────────┤
│                                              │
│  ■ 做了什么                                  │
│    • {变更内容 1}                            │
│    • {变更内容 2}                            │
│                                              │
│  ■ 有什么变化                                │
│    Before: {旧行为}                          │
│    After:  {新行为}                          │
│                                              │
│  ■ 变更文件 ({N} files)                      │
│    {文件路径 1}                              │
│    {文件路径 2}                              │
│                                              │
│  ■ 剩余任务                                  │
│    • 任务 {X} ({status}): {内容}  ← Plans.md │
│    • 任务 {Y} ({status}): {内容}  ← Plans.md │
│    （Plans.md 中有 {M} 个未完成任务）        │
│                                              │
│  commit: {hash} | review: {APPROVE}          │
└─────────────────────────────────────────────┘
```

### 生成规则

1. **做了什么**: 从 `git diff --stat HEAD~1` 和 commit message 自动提取。尽量少用技术术语，以动词开头
2. **有什么变化**: 从任务的"内容"和"DoD"推断 Before/After。重视用户体验变化
3. **变更文件**: 从 `git diff --name-only HEAD~1` 获取。超过 5 个文件则省略显示数量
4. **剩余任务**: 列出 Plans.md 的 `cc:TODO` / `cc:WIP` 任务。明确标示是否已记录在 Plans.md
5. **review**: 显示审查结果（APPROVE / REQUEST_CHANGES → APPROVE）

### Parallel 模式中的报告

- **1 个任务**（`--parallel` 强制时）: 使用 Solo 模板
- **多个任务**: 使用 Breezing 汇总模板（见下文）

### Breezing 模式中的报告

所有任务完成后汇总输出。各任务以简化版（做了什么 + commit hash）列出，
最后输出整体摘要（总变更文件数 + 剩余任务）:

```
┌─────────────────────────────────────────────┐
│  ✓ Breezing 完成: {N}/{M} 任务              │
├─────────────────────────────────────────────┤
│                                              │
│  1. ✓ {任务名 1}            [{hash1}]       │
│  2. ✓ {任务名 2}            [{hash2}]       │
│  3. ✓ {任务名 3}            [{hash3}]       │
│                                              │
│  ■ 整体变更                                  │
│    {N} files changed, {A} insertions(+),    │
│    {D} deletions(-)                         │
│                                              │
│  ■ 剩余任务                                  │
│    Plans.md 中有 {K} 个未完成任务            │
│    • 任务 {X}: {内容}                       │
│                                              │
└─────────────────────────────────────────────┘
```

## 相关技能

- `harness-plan` — 计划要执行的任务
- `harness-sync` — 同步实现与 Plans.md
- `harness-review` — 审查实现
- `harness-release` — 版本升级和发布
