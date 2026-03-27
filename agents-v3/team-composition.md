# Team Composition (v3)

Harness v3 的 3 代理配置。
11 代理整合为 3 代理。

## Team 结构图

```
Lead (Execute 技能的 --breezing 模式) ─ 仅指挥
  │
  ├── Worker (claude-code-harness:worker)
  │     实现 + 自审查 + 构建验证 + 提交
  │     ※ --codex 时内部调用 codex exec
  │
  ├── [Worker #2] (claude-code-harness:worker)
  │     并行执行独立任务
  │
  └── Reviewer (claude-code-harness:reviewer)
        Security / Performance / Quality / Accessibility
        REQUEST_CHANGES → Lead 创建修正任务
```

## 旧代理 → v3 映射

| 旧代理 | v3 代理 |
|--------------|--------------|
| task-worker | worker |
| codex-implementer | worker（包含 --codex） |
| error-recovery | worker（包含错误恢复） |
| code-reviewer | reviewer |
| plan-critic | reviewer（plan type） |
| plan-analyst | reviewer（scope type） |
| project-analyzer | scaffolder |
| project-scaffolder | scaffolder |
| project-state-updater | scaffolder |
| ci-cd-fixer | worker（包含 CI 恢复） |
| video-scene-generator | extensions/generate-video（单独） |

## 角色定义

### Lead（Execute 技能内部）

| 项目 | 设置 |
|------|------|
| **Phase A** | 准备、任务分解 |
| **Phase B** | delegate + review — Worker spawn / 执行审查 / SendMessage / cherry-pick |
| **Phase C** | 详细完成报告、Plans.md 最终更新 |
| **禁止** | Phase B 中直接 Write/Edit（实现委托给 Worker）。但 Bash 可用于审查（codex exec）和 cherry-pick |

### Worker

| 项目 | 设置 |
|------|------|
| **subagent_type** | `claude-code-harness:worker` |
| **模型** | sonnet |
| **数量** | 1〜3（基于独立任务数） |
| **工具** | Read, Write, Edit, Bash, Grep, Glob |
| **禁止** | Task（防止递归） |
| **职责** | 实现 → 自审查 → CI 验证 → worktree 内 commit（Breezing 时不反映到 main） |
| **错误恢复** | 最多 3 次。3 次失败后升级 |

### Reviewer

| 项目 | 设置 |
|------|------|
| **subagent_type** | `claude-code-harness:reviewer` |
| **模型** | sonnet |
| **数量** | 1 |
| **工具** | Read, Grep, Glob（只读） |
| **禁止** | Write, Edit, Bash, Task |
| **职责** | 代码/计划/范围审查 |
| **判定** | APPROVE / REQUEST_CHANGES |

### Scaffolder（仅设置时）

| 项目 | 设置 |
|------|------|
| **subagent_type** | `claude-code-harness:scaffolder` |
| **模型** | sonnet |
| **数量** | 1 |
| **工具** | Read, Write, Edit, Bash, Grep, Glob |
| **职责** | 项目分析、脚手架构建、状态更新 |

## 执行流程（v3.12+ 审查循环集成）

```
Phase A: Lead 分解任务、解析依赖图、effort 评分
    ↓
Phase B: 按任务逐个执行（按依赖顺序）
    ↓
    B-1. Worker spawn (mode: breezing, isolation: worktree)
         Worker: 实现 → 自审查 → worktree 内 commit → 向 Lead 返回结果
    ↓
    B-2. Lead 执行审查
         Codex exec（优先，--sandbox read-only）
         → 内部 Reviewer agent（后备）
         阈值标准: critical/major → REQUEST_CHANGES、仅 minor → APPROVE
    ↓
    B-3. REQUEST_CHANGES 时: 修正循环（最多 3 次）
         Lead → SendMessage(to: worker_id) 发送指摘
         Worker: 修正 → git commit --amend → 返回更新 hash
         Lead: 再次审查
    ↓
    B-4. APPROVE → Lead cherry-pick 到 main
         git cherry-pick --no-commit {worktree_commit}
         git commit -m "{task description}"
         Plans.md: cc:完成 [{hash}]
    ↓
Phase C: Lead 输出详细完成报告、Plans.md 最终确认
```

### SendMessage 模式（修正循环）

Lead 指示 Worker 修正时的语法:

```
SendMessage(
    to: "{worker_agent_id}",
    message: "请修正以下 critical/major 指摘:\n\n{issues}\n\n修正后 git commit --amend 并返回完成。"
)
```

Worker 端的接收处理:
1. 接收 SendMessage → 解析指摘内容
2. 修正相应位置
3. 用 `git commit --amend` 更新 worktree 内的 commit
4. 将更新的 commit hash 返回给 Lead

### cherry-pick 模式（APPROVE 后）

Lead 将 Worker 的 worktree commit 合并到 main:

```bash
# 将 worktree 内的 commit cherry-pick 到 main
git cherry-pick --no-commit {worktree_commit_hash}
# Lead 控制提交信息
git commit -m "feat: {task_description}"
```

> **注意**: 用 `--no-commit` 进入 staged 状态后再 commit，
> Lead 可以将提交信息控制在统一格式。

### Nested Teammate Policy（v2.1.69）

CC 2.1.69 中 teammates 的多重 spawn（nested teammates）会被平台端阻止。
Harness 端最小化冗余的防重复措辞，统一采用以下运营方式:

1. 仅 Lead 可以 spawn teammate
2. Worker/Reviewer 提示词聚焦于「实现/审查职责」
3. nested 防止不通过添加 hooks，而是委托给官方守护（简化运营）

## 权限设置（bypassPermissions / permissionMode）

Teammate 在无 UI 的后台运行，因此需要明确设置权限模式。

### v2.1.72+ 推荐: `permissionMode` in frontmatter

官方文档中 `permissionMode` 已作为代理 frontmatter 的正式字段文档化。
相比 spawn 时的 `mode` 指定，**更推荐在定义级别声明**:

```yaml
# agents-v3/worker.md frontmatter
permissionMode: bypassPermissions
```

**优点**: 不依赖 spawn prompt，将权限模式嵌入代理定义本身。
即使 Lead 的 spawn 代码忘记传递 `mode` 也是安全的。

### 安全层（多层防御）

1. `permissionMode: bypassPermissions` — 在 frontmatter 中声明
2. 用 `disallowedTools` 限制工具
3. PreToolUse hooks 维持护栏
4. Lead 始终监控
5. 用 `Agent(worker, reviewer)` 限制可 spawn 的代理类型

### Auto Mode（推广目标）

作为 `bypassPermissions` 的安全替代，Anthropic 提供的新权限运营方式。
Claude 自动进行权限判断，内置提示词注入防护。

| 视角 | bypassPermissions | Auto Mode |
|------|-------------------|-----------|
| 权限判断 | 无条件允许所有工具 | Claude 自动判断 |
| 安全层 | hooks + disallowedTools | 内置防护 + hooks + disallowedTools |
| Token 成本 | 无额外 | 微增 |
| 延迟 | 无额外 | 微增 |
| Teammate 兼容 | 当前 shipped default | 父会话的 permission mode 兼容时为验证对象 |

#### 当前处理

`/breezing` 和 `/harness-work --breezing` 的 shipped default 目前仍保持 `bypassPermissions`。
`--auto-mode` 标志作为 opt-in，仅在父会话的 permission mode 兼容时尝试推广:

```bash
/breezing all                 # 以当前默认 (bypassPermissions) 完成所有任务
/breezing --auto-mode all     # 在兼容的父会话中尝试 Auto Mode 推广
/execute --breezing all
```

**约束**: 如果父会话或子代理 frontmatter 仍是 `bypassPermissions`，则该 permission mode 优先。
因此，要真正将 Auto Mode 设为默认，不仅需要修改 teammate 执行路径，还需要重新设计父会话侧的权限设计。hooks 和 disallowedTools 保持不变。

#### 设置策略

| 层级 | 采用值 | 理由 |
|---------|--------|------|
| project template (`permissions.defaultMode`) | `bypassPermissions` | 官方 docs 的 documented permission modes 不包含 `autoMode` |
| agent frontmatter (`permissionMode`) | `bypassPermissions` | frontmatter 侧也只声明 documented 的 permission mode |
| teammate 执行路径 | `bypassPermissions`（当前） | 使 shipped default 与实际权限继承一致 |
| `--auto-mode` 标志 | opt-in 推广 | 在重新设计父会话后安全启用 |

通过这种分离，分发的模板可以避免未文档化的设置值，同时正确说明当前的 shipped behavior。Auto Mode 将在下一阶段的父会话设计变更中再次讨论。

### Agent Teams 官方文档化

Agent Teams 已作为实验性功能官方文档化。
启用需要 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 环境变量:

```json
// settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**对 Harness 的影响**:
- `breezing` 技能以 Agent Teams 为前提 → 设置时添加环境变量检查
- 官方文档中明确了 `teammateMode` 设置（`"in-process"` | `"tmux"` | `"auto"`）
- `TeammateIdle` / `TaskCompleted` 的 `{"continue": false}` 作为官方规格已稳定

## 官方 Agent Teams 最佳实践整合（2026-03）

与 Claude Code 官方文档 `agent-teams.md` 中的最佳实践的整合状态。

### 任务粒度指南

官方推荐: **5-6 tasks per teammate**。Harness 的 Lead 在分解任务时以此粒度为基准。

| 粒度 | 判定 | 例 |
|------|------|-----|
| 过小 | 协调成本 > 实现成本 | 1 行修正、添加注释 |
| 适当 | 具有明确交付物的自包含单元 | 函数实现、创建测试文件、审查 |
| 过大 | 无 check-in 长时间运行 | 整个模块重新设计 |

### `teammateMode` 设置

官方支持的显示模式:

| 模式 | 行为 | 推荐环境 |
|--------|------|----------|
| `"auto"` | 在 tmux 会话内则 split，否则 in-process | 默认 |
| `"in-process"` | 在同一终端管理所有 teammate | VS Code 集成终端 |
| `"tmux"` | 每个 teammate 分配独立窗格 | iTerm2 / tmux 用户 |

```json
// settings.json
{ "teammateMode": "in-process" }
```

### Plan Approval 模式

官方的「Require plan approval for teammates」模式:

```
Lead: "Spawn an architect teammate. Require plan approval before changes."
  → Teammate 在 plan mode 下调查、制定计划
  → 向 Lead 发送 plan_approval_request
  → Lead APPROVE → Teammate 开始实现
  → Lead REJECT + feedback → Teammate 修正计划
```

Harness 中可与 Reviewer 的 `REQUEST_CHANGES` → Worker 修正循环互补使用。
复杂架构变更时推荐在 Worker spawn 时要求 plan approval。

### Quality Gate Hooks

与官方钩子事件的整合:

| Hook | Harness 实现 | 官方文档 |
|------|-------------|--------------|
| `TeammateIdle` | `teammate-idle.sh` (已实现) | exit 2 返回 feedback + 继续指示 |
| `TaskCompleted` | `task-completed.sh` (已实现) | exit 2 拒绝完成 + feedback |
| `SubagentStart` | 已实现（subagent-tracker + matcher: worker/reviewer/scaffolder/video-scene-generator） | settings.json 按代理类型过滤 |
| `SubagentStop` | 已实现（subagent-tracker + matcher + agent frontmatter Stop hook） | settings.json + frontmatter 双层监控 |

### 团队规模指南

官方推荐: **3-5 teammates**。这与 Harness 的当前配置（Worker 1-3 + Reviewer 1）一致。

> 「Three focused teammates often outperform five scattered ones.」— 官方文档

## Codex CLI Environment

Codex CLI 环境中无法使用 Claude Code 的 Agent/SendMessage API。
需要用 native subagent API（`spawn_agent`, `send_input` 等）替代。

### API 映射

| Claude Code | Codex CLI | 备注 |
|------------|-----------|------|
| `Agent(subagent_type=...)` | `spawn_agent(...)` | native subagent。返回值包含 agentId |
| `SendMessage(to, message)` | `send_input(agent_id, message)`。如果 agent 已关闭则先 `resume_agent(agent_id)` | 在修正循环中使用 |
| `bypassPermissions` | `--full-auto` | codex exec 是非交互的 |
| Task 工具 | 直接编辑 Plans.md | |
| PreToolUse hooks | config.toml sandbox | |

> **重要**: harness-work / breezing 的 Phase B 流程（Worker spawn → 审查 → cherry-pick）
> 使用 Claude Code 的 `Agent` + `SendMessage` 语法描述。
> Codex 环境中请按上述映射表进行转换。

### 替代模式: codex exec 顺序执行

代替 Agent Teams，顺序调用 `codex exec`:

```bash
# 相当于 Worker（实现任务）
echo "任务内容" | codex exec - --sandbox workspace-write --full-auto

# 相当于 Reviewer（只读审查）
echo "审查内容" | codex exec - --sandbox read-only
```

### 并行执行（Bash 级别）

```bash
echo "任务 A" | codex exec - --sandbox workspace-write --full-auto > /tmp/out-a.txt 2>>/tmp/harness-codex-$$.log &
echo "任务 B" | codex exec - --sandbox workspace-write --full-auto > /tmp/out-b.txt 2>>/tmp/harness-codex-$$.log &
wait
```

无依赖的任务可通过 Bash 的 `&` + `wait` 并行化。
但应避免对同一文件的并行写入。

### Thread Forking 利用可能性（调查: 2026-03）

Codex 0.110+ 可通过 `codex fork` / `/fork` 分支线程，
但**仅限 TUI**，从 `codex exec` 进行非交互式 fork 尚未实现。

- [GitHub Issue #11750](https://github.com/openai/codex/issues/11750) 中 `codex exec fork` 处于提案阶段
- 当前变通方案: 通过 PTY fork → `codex exec resume <id>`，但较脆弱，有约 6s 开销
- **结论**: 将 breezing worker 迁移到 fork-thread 方式**为时尚早**。
  在 `codex exec fork` 稳定发布前，维持当前的独立进程方式。

### codex exec 标志正式名称（codex-cli 0.115.0+）

| 标志 | 简写 | 说明 |
|---|---|---|
| `--sandbox` | `-s` | `read-only` / `workspace-write` / `danger-full-access` |
| `--full-auto` | - | `-a on-request` + `--sandbox workspace-write` 的别名（低摩擦自动执行） |
| `--dangerously-bypass-approvals-and-sandbox` | - | 绕过所有沙箱和审批（极度危险） |

> **注意**: 旧标志 `-a never` 在 0.115.0 中作为 CLI 标志已废弃（`-a` 不被识别）。
> `--full-auto` 内部相当于 `-a on-request` + `--sandbox workspace-write`。
> `codex exec` 本身是非交互模式（无 stdin），因此实际上不会出现审批提示。
> harness 统一在所有位置使用 `--full-auto`。

### 提示词传递方式

- `--input-file` 选项**不存在**
- stdin 传递: `cat file.md | codex exec -` 是官方支持的方式
- 当前的 `codex exec "$(cat file)"` 需注意 shell 参数上限（ARG_MAX）。大提示词使用 stdin 方式更安全

### 可配置内存 — memory: project 的 Codex 侧映射（调查: 2026-03）

与 Claude Code 的 `memory: project`（代理内存）相当的 Codex 侧机制:

| Claude Code | Codex CLI | 备注 |
|---|---|---|
| `memory: project` MEMORY.md | `AGENTS.md` 层级（global → project → subdir） | 描述持久指示和学习 |
| agent-memory 目录 | `agents.<name>.config_file` | 按代理的配置文件 |
| spawn prompt | `AGENTS.override.md` | 临时覆盖 |
| 会话历史 | `history.persistence: save-all` | 保存到 `history.jsonl` |
| 上下文压缩 | `model_auto_compact_token_limit` | 自动压缩 |

**config.toml 的内存相关键** (0.110.0+):

```toml
# 内存・历史
history.persistence = "save-all"   # "save-all" | "none"
# history.max_bytes = 1048576      # 历史文件上限（省略时: 无限制）

# 内存设置 (0.110.0 重命名: phase_1_model → extract_model, phase_2_model → consolidation_model)
[memories]
# extract_model = "gpt-5-mini"              # 线程摘要模型（旧 phase_1_model）
# consolidation_model = "gpt-5"             # 内存整合模型（旧 phase_2_model）
# max_raw_memories_for_consolidation = 256  # 整合目标的最大内存数（旧 max_raw_memories_for_global）
no_memories_if_mcp_or_web_search = false    # 使用 MCP/Web 搜索时标记内存污染（0.110.0 新功能）

# 项目文档
project_doc_max_bytes = 32768      # AGENTS.md 的读取上限（默认: 32KiB）
# project_doc_fallback_filenames = ["TEAM_GUIDE.md", ".agents.md"]

# 代理
# agents.worker.config_file = ".codex/agents/worker.toml"
# agents.worker.description = "Implementation agent"
# agents.max_depth = 1
# agents.max_threads = 3
```

> **0.110.0 Polluted Memories**: 设置 `no_memories_if_mcp_or_web_search = true` 时，
> 包含 Web 搜索或 MCP 工具调用的线程会被标记为 `memory_mode = "polluted"`，
> 不会从该线程生成内存。Harness worker 有限地使用 MCP，因此推荐 `false`（默认）。

> **0.110.0 Workspace-scoped Memory Writes**: 在 `workspace-write` sandbox 下，
> `~/.codex/memories/` 自动包含在 writable roots 中。
> `codex exec -s workspace-write` 进行内存维护时无需额外审批。

**Harness 中的使用方针**:
- 将项目特有的学习和规约汇总到 `.codex/AGENTS.md`
- 定期将 `codex-learnings.md` 的内容提升到 AGENTS.md（维持 SSOT）
- 用 `agents.<name>.config_file` 分离 worker 和 reviewer 的个别设置（将来支持）

## Sandboxing 集成（分阶段引入）

Claude Code 的 `/sandbox` 功能提供 OS 级别的文件系统/网络隔离。
作为当前 `bypassPermissions` + hooks 多层防御的**额外安全层**引入。

### 当前 vs Sandboxing

| 视角 | bypassPermissions + hooks | Sandbox auto-allow |
|------|--------------------------|-------------------|
| 粒度 | 工具级别（hooks 判定） | 文件路径/域名级别（OS 强制） |
| 实现层 | Claude Code 权限系统 | macOS Seatbelt / Linux bubblewrap |
| 提示词注入 | hooks 部分防护 | OS 级别完全防护 |
| Worker 自由度 | 允许所有 Bash（hooks 守护） | 仅限预定义路径/域名 |
| Token 成本 | 无 | 无 |

### 对 Worker 的应用方针

```json
// settings.json — Worker 会话的 Sandbox 设置示例
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": [
        "/",
        "~/.claude",
        "//tmp"
      ]
    }
  }
}
```

- `allowWrite: ["/"]` 是 settings.json 目录的相对路径（项目根目录）
- `~/.claude` 是写入 Agent Memory 所需
- `//tmp` 用于构建输出和临时文件

### 分阶段引入计划

| 阶段 | 状态 | Worker 权限 | Sandbox |
|---------|------|-----------|---------|
| **Phase 0（当前）** | 运行中 | `bypassPermissions` + hooks | 未应用 |
| **Phase 1（验证）** | 下次发布开始验证 | `bypassPermissions` + hooks + sandbox | 应用于 Worker 的 Bash |
| **Phase 2（迁移）** | TBD | 仅 sandbox auto-allow | 应用于所有 Bash |

Phase 1 验证项目:
1. Worker 的 `npm test` / `npm run build` 是否在 sandbox 内正常运行
2. `codex exec` 是否在 sandbox 内正常运行
3. 写入 Agent Memory（`.claude/agent-memory/`）是否不被阻止
4. hooks 的 PreToolUse/PostToolUse 是否可与 sandbox 并用

### `opusplan` 实现的 Lead 模型优化

`opusplan` 别名非常适合 Lead 会话:
- **Plan 阶段**: 用 Opus 进行任务分解和架构判断（高质量推理）
- **Execute 阶段**: 用 Sonnet 进行 Worker 协调（成本效率）

```bash
# 在 breezing 会话中使用 opusplan
claude --model opusplan
/breezing all
```

### `CLAUDE_CODE_SUBAGENT_MODEL` 实现的 Worker 模型控制

通过环境变量 `CLAUDE_CODE_SUBAGENT_MODEL` 统一指定所有子代理的模型:

```bash
# CI 环境中降低成本（用 haiku 执行 Worker/Reviewer）
export CLAUDE_CODE_SUBAGENT_MODEL=claude-haiku-4-5-20251001
```

> 与代理定义的 `model` 字段的优先级尚未验证。计划在 Phase 2 验证。

## v2.1.68/v2.1.72 Effort 级别变更的影响

### 变更点
- Opus 4.6 的默认值改为 **medium effort**（v2.1.68）
- 用 `ultrathink` 关键字启用 high effort（仅 1 轮）
- Opus 4 / 4.1 从 first-party API 删除（自动迁移到 Opus 4.6）
- **v2.1.72**: 废弃 `max` 级别。简化为 3 档 `low(○)/medium(◐)/high(●)`。用 `/effort auto` 重置

### 对团队的影响
- Worker（`model: sonnet`）: Sonnet 不受 effort 级别影响。无变更
- Reviewer（`model: sonnet`）: 同上。无变更
- Lead（使用 Opus 时）: medium effort 为默认。复杂任务调整时使用 ultrathink
- Codex Worker: effort 控制是 Claude Code 特有的。Codex CLI 中不适用

### Effort 注入模式
Lead 在 spawn Worker/Reviewer 时，根据任务复杂度评分在 spawn prompt 开头添加 `ultrathink`。详情参见 `skills-v3/harness-work/SKILL.md` 的「Effort 级别控制」部分。

### v2.1.72 Agent tool `model` 参数恢复
Agent tool 的 per-invocation `model` 参数已恢复。与代理定义的 `model` 分开，spawn 时可进行临时模型指定。
- **现状**: Worker/Reviewer 都以 `model: sonnet` 固定运行
- **Phase 2 讨论**: 根据任务特性动态选择模型（轻量→haiku, 高质量→opus）

### v2.1.72 `/clear` 保留后台代理
`/clear` 现在只停止前台任务。breezing 团队执行中即使 Lead 执行 `/clear`，后台 Worker 也会继续运行。

### v2.1.72 并行工具调用修复
Read/WebFetch/Glob 的失败不再取消同级调用。Worker 的并行文件读取可靠性提高。
