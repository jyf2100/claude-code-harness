# CLAUDE.md - Claude Harness 开发指南

本文件为 Claude Code 在本仓库中工作时提供指导。

## 项目概述

**Claude harness** 是一个插件，用于在"计划 → 执行 → 审查"工作流中自主运行 Claude Code。

**特别说明**：本项目具有自指性——它使用 Harness 自身来改进 Harness。

## Claude Code 2.1.79+ 功能使用指南

Harness 充分利用了 Claude Code 2.1.79 引入的新功能。

| 功能 | 技能 | 用途 |
|---------|-------|---------|
| **Agent Memory (memory frontmatter)** | task-worker, code-reviewer | 持久化学习 |
| **TeammateIdle/TaskCompleted Hook** | breezing | 自动化团队监控 |
| **Skill budget scaling** | 所有技能 | 自动调整为上下文窗口的 2% |
| **Fast mode (Opus 4.6)** | 所有技能 | 高速输出模式 |
| **Worktree isolation** | breezing, parallel-workflows | 安全地并行写入同一文件 |
| **`/simplify` 自动优化** | work | 实现后自动简化代码 |
| **HTTP hooks** | hooks | JSON POST 到外部服务（Slack、仪表盘、指标） |
| **Effort levels + ultrathink (v2.1.68)** | harness-work | 多因素评分为复杂任务注入 ultrathink |
| **Agent hooks (v2.1.68)** | hooks | 基于 LLM 的代码质量守护（type: "agent"） |
| **`${CLAUDE_SKILL_DIR}` 变量 (v2.1.69)** | 所有技能 | 稳定的技能本地引用路径解析 |
| **InstructionsLoaded hook (v2.1.69)** | hooks | 会话前指令加载跟踪和环境检查 |
| **`agent_id` / `agent_type` 字段 (v2.1.69)** | hooks, breezing | 健壮的队友身份和角色感知守护 |
| **`{"continue": false}` 队友响应 (v2.1.69)** | breezing | 所有任务完成或请求停止时停止团队循环 |
| **`/reload-plugins` (v2.1.69)** | 所有技能 | 编辑技能/钩子后立即刷新，无需重启 |
| **`includeGitInstructions: false` (v2.1.69)** | breezing, work | 减少 git 指令轻量任务的提示词开销 |
| **`git-subdir` 插件源 (v2.1.69)** | setup, release | 支持从仓库子目录管理的插件源 |
| **Sonnet 4.5 → 4.6 自动迁移** | 所有技能 | 旧版 Sonnet 引用自动迁移到 4.6 行为 |
| **WorktreeCreate/Remove hook (v2.1.50)** | breezing | Worktree 生命周期自动设置和清理 |
| **Auto Mode (研究预览，第一阶段已启动)** | breezing, work | `--auto-mode` 标志作为更安全的 bypassPermissions 替代方案。第一阶段：研究预览于 2026-03-12 启动 |
| **Per-agent hooks (v2.1.69+)** | agents-v3/ | Worker PreToolUse 守护 + Reviewer Stop 日志在 agent frontmatter 中 |
| **Agent `isolation: worktree` (v2.1.50+)** | agents-v3/worker | 自动 worktree 隔离，支持共享 Agent Memory 的并行写入 |
| **`/loop` + Cron 调度 (v2.1.71)** | breezing, harness-work | 周期性任务监控，如 `/loop 5m /sync-status` |
| **PostToolUseFailure hook (v2.1.70)** | hooks | 连续 3 次失败后自动升级 |
| **Background Agent output fix (v2.1.71)** | breezing | 安全的后台 agent 使用，完成通知中包含输出路径 |
| **Compaction image retention (v2.1.70)** | 所有技能 | 上下文压缩时保留图片 |
| **Subagent `background` 字段 (v2.1.71+)** | breezing | 通过 frontmatter 实现始终后台执行的 agent |
| **Subagent `local` memory scope (v2.1.71+)** | agents-v3/ | 非 VCS agent memory 存储在 `.claude/agent-memory-local/` |
| **Agent Teams 实验性标志 (v2.1.71+)** | breezing | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 环境变量用于官方 Agent Teams |
| **`/agents` 命令 (v2.1.71+)** | setup, troubleshoot | 交互式 agent 管理 UI（创建/编辑/删除） |
| **Desktop Scheduled Tasks (v2.1.71+)** | harness-work | `~/.claude/scheduled-tasks/` 基于 SKILL.md 的周期性任务 |
| **`--agents` CLI 标志 (v2.1.71+)** | breezing, CI | 会话级 JSON agent 定义，无需磁盘持久化 |
| **`ExitWorktree` tool (v2.1.72)** | breezing, work | Agent 工作流的编程式 worktree 退出 |
| **Effort levels 简化 (v2.1.72)** | harness-work | 持久级别为 `low/medium/high`（`○ ◐ ●`）。`max` 仅作为 Opus 4.6 的会话专属选项保留 |
| **Agent tool `model` 参数恢复 (v2.1.72)** | breezing | 重新启用每次调用的模型覆盖 |
| **`/plan` 描述参数 (v2.1.72)** | harness-plan | `/plan fix the auth bug` 带上下文进入计划模式 |
| **Parallel tool call 修复 (v2.1.72)** | breezing, work | 失败的 Read/WebFetch/Glob 不再取消同级调用 |
| **Worktree isolation 修复 (v2.1.72)** | breezing | 任务恢复 cwd 还原 + 后台通知 worktreePath |
| **`/clear` 保留后台 agents (v2.1.72)** | breezing | `/clear` 只终止前台任务；后台 agents 保持运行 |
| **Hooks 修复 (v2.1.72)** | hooks | transcript_path 修复、skill hooks 双重触发修复、async stdin 修复 |
| **HTML comments hidden in CLAUDE.md (v2.1.72)** | 所有 | `<!-- -->` 对自动注入隐藏；通过 Read 工具可见 |
| **Sandboxing (`/sandbox`)** | breezing, work | 操作系统级文件系统/网络隔离，作为 bypassPermissions 的补充 |
| **`opusplan` model alias** | breezing | Lead 会话中自动切换 Opus（计划）↔ Sonnet（执行） |
| **`CLAUDE_CODE_SUBAGENT_MODEL` env var** | breezing, work | Worker/Reviewer 的集中式子 agent 模型控制 |
| **Checkpointing (`/rewind`)** | work | 会话状态跟踪、回滚和选择性摘要 |
| **Code Review (托管版，研究预览)** | harness-review | 多 agent PR 审查，带有 `REVIEW.md` 指导。Teams/Enterprise |
| **Status Line (`/statusline`)** | 所有技能 | 自定义 shell 脚本状态栏，用于上下文/成本/git 监控 |
| **1M Context (`sonnet[1m]`)** | harness-review, breezing | 大型代码库分析的 1M token 上下文窗口 |
| **Chrome Integration (`--chrome`, beta)** | harness-work, harness-review | 浏览器自动化，用于 UI 测试、控制台调试、数据提取 |
| **`modelOverrides` setting (v2.1.73)** | setup, breezing | 将模型选择器条目映射到自定义提供商模型 ID（Bedrock ARNs 等） |
| **`/output-style` 已弃用 (v2.1.73)** | 所有技能 | 改用 `/config`；输出样式选择已移至配置菜单 |
| **Bedrock/Vertex Opus 4.6 默认值 (v2.1.73)** | breezing | 云提供商上的默认 Opus 从 4.1 更新到 4.6 |
| **`autoMemoryDirectory` setting (v2.1.74)** | session-memory, setup | 项目特定内存隔离的自定义 auto-memory 存储路径 |
| **`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (v2.1.74)** | hooks | 可配置的 SessionEnd hooks 超时（原固定 1.5s kill） |
| **Full model ID fix (v2.1.74)** | agents-v3/, breezing | `claude-opus-4-6` 等现在可在 agent frontmatter 和 JSON 配置中识别 |
| **Streaming API memory leak fix (v2.1.74)** | breezing, work | 流式响应缓冲区中的无界 RSS 增长已修复 |
| **LSP server integration (`.lsp.json`)** | setup | 通过语言服务器协议实现实时诊断、代码导航 |
| **`SubagentStart`/`SubagentStop` matcher** | breezing, hooks | Agent 类型特定的生命周期监控，带有匹配器过滤 |
| **Agent Teams: Task Dependencies** | breezing | 带文件锁声明的自动解锁依赖任务 |
| **`--teammate-mode` CLI flag** | breezing | 每会话显示模式覆盖（`in-process`/`tmux`） |
| **`skills` field in agent frontmatter** | agents-v3/ | 启动时预加载技能内容到子 agent 上下文 |
| **`--remote` / Cloud Sessions** | breezing, harness-work | 终端到云端异步任务执行，通过 `/teleport` 获取结果 |
| **`CLAUDE_ENV_FILE` SessionStart persistence** | hooks | 从 SessionStart hooks 持久化环境变量到后续 Bash 命令 |
| **`PreCompact` hook** | hooks | 压缩前状态保存 + WIP 任务警告（已实现） |
| **Slack Integration (`@Claude`)** | harness-work (未来) | 通过云会话从 Slack 频道路由编码任务 |
| **Analytics Dashboard** | setup, harness-review | PR 归因（`claude-code-assisted` 标签）、使用/贡献指标、排行榜 |
| **OpenTelemetry Monitoring** | hooks, breezing | OTel 指标/事件导出（会话、tokens、成本、工具结果、活动时间） |
| **`/security-review` command** | harness-review | 分析待处理更改的安全漏洞（注入、认证、数据暴露） |
| **`/insights` command** | session-memory | 会话分析报告：项目领域、交互模式、摩擦点 |
| **`/stats` command** | session | 每日使用可视化、会话历史、连续天数、模型偏好 |
| **Prompt Suggestions** | 所有技能 | 基于 git 历史的上下文感知自动补全；Tab 接受，Enter 提交 |
| **PR Review Status footer** | breezing, harness-review | 可点击的 PR 链接，带颜色编码的审查状态（绿/黄/红/灰/紫） |
| **`CLAUDE_CODE_TASK_LIST_ID` env var** | breezing | 跨会话共享命名任务列表：`CLAUDE_CODE_TASK_LIST_ID=my-project claude` |
| **`fastModePerSessionOptIn` setting** | setup, breezing | 管理员控制：快速模式每次会话重置，用户必须 `/fast` 重新启用 |
| **1M Context Window (`opus[1m]`) (v2.1.75)** | breezing, harness-review | Opus 4.6 的 1M 上下文窗口。Max/Team/Enterprise 自动升级 |
| **Memory file timestamps (v2.1.75)** | session-memory, memory | 内存文件的最后更新时间戳。支持基于新鲜度的内存判断 |
| **Async hook suppression (v2.1.75)** | breezing, hooks | 异步 hook 完成消息默认隐藏。`--verbose` 显示 |
| **`/effort max` session-only (v2.1.75+)** | harness-work, harness-plan | Opus 4.6 专属的最深推理模式。会话级启用，不持久化 |
| **MCP Elicitation 支持 (v2.1.76)** | hooks, breezing | MCP 服务器的结构化输入请求。Breezing 中自动跳过 |
| **`Elicitation`/`ElicitationResult` hook (v2.1.76)** | hooks | MCP elicitation 前后拦截和日志记录 |
| **`PostCompact` hook (v2.1.76)** | hooks, breezing | 压缩完成后的上下文重新注入（PreCompact 的对应） |
| **`-n`/`--name` CLI flag (v2.1.76)** | breezing | 设置会话显示名称。用于会话列表中的识别 |
| **`worktree.sparsePaths` setting (v2.1.76)** | breezing, setup | 单体仓库中的 worktree sparse-checkout。加速并行 worker 启动 |
| **`/effort` slash command (v2.1.76)** | harness-work | 会话中切换 effort 级别（low/medium/high） |
| **`--worktree` 启动加速 (v2.1.76)** | breezing | 直接读取 git refs + 跳过冗余 fetch |
| **后台 agent 部分结果保留 (v2.1.76)** | breezing | kill 时部分结果也保存到上下文 |
| **stale worktree 自动清理 (v2.1.76)** | breezing | 自动删除中断的并行执行的 worktree |
| **自动压缩 circuit breaker (v2.1.76)** | 所有技能 | 连续 3 次失败自动停止（防止无限重试） |
| **`--plugin-dir` 规范变更 (v2.1.76, breaking)** | setup | 多目录通过重复 `--plugin-dir` 指定 |
| **Deferred Tools schema 修复 (v2.1.76)** | 所有技能 | 压缩后 ToolSearch 工具 schema 保留 |
| **`/context` command (v2.1.74)** | 所有技能 | 上下文消费可视化和优化建议。防止长时间会话膨胀 |
| **`maxTurns` agent 安全限制** | agents-v3/ | Worker: 100, Reviewer: 50, Scaffolder: 75。防止失控的安全阀 |
| **`Notification` hook 实现** | hooks | 通知事件（permission_prompt, idle_prompt 等）的日志记录。Breezing 可观测性提升 |
| **Output token limits 64k/128k (v2.1.77)** | 所有技能 | Opus 4.6 / Sonnet 4.6 默认输出 64k，上限 128k tokens |
| **`allowRead` sandbox setting (v2.1.77)** | harness-review | 在 `denyRead` 区域内重新允许特定路径的读取 |
| **PreToolUse `allow` respects `deny` (v2.1.77)** | guardrails | Hook `allow` 不会覆盖 settings.json 的 `deny` 规则（安全增强） |
| **Agent `resume` → `SendMessage` (v2.1.77)** | breezing | Agent tool 的 `resume` 参数已弃用。迁移到 `SendMessage({to: agentId})` |
| **`/branch` (原 `/fork`) (v2.1.77)** | session | `/fork` 重命名为 `/branch`（`/fork` 作为别名保留） |
| **`claude plugin validate` 增强 (v2.1.77)** | setup | 添加 frontmatter + hooks.json 语法验证 |
| **`--resume` 45% 加速 (v2.1.77)** | session | fork-heavy 会话恢复最多加速 45%，减少 100-150MB 内存 |
| **Stale worktree race fix (v2.1.77)** | breezing | 修复活跃 agent 的 worktree 被误删的竞态条件 |
| **`StopFailure` hook event (v2.1.78)** | hooks | 捕获 API 错误（速率限制、认证失败）导致的会话停止失败 |
| **`${CLAUDE_PLUGIN_DATA}` variable (v2.1.78)** | hooks, setup | 插件更新后仍持久的状态目录变量 |
| **Agent `effort`/`maxTurns`/`disallowedTools` frontmatter (v2.1.78)** | agents-v3/ | 插件 agent 定义中声明式设置 effort/轮次限制/工具禁用 |
| **`deny: ["mcp__*"]` permission fix (v2.1.78)** | setup | settings.json 的 deny 规则正确阻止 MCP 工具 |
| **`ANTHROPIC_CUSTOM_MODEL_OPTION` env var (v2.1.78)** | setup | 向 `/model` 选择器添加自定义模型条目 |
| **`--worktree` skills/hooks loading fix (v2.1.78)** | breezing | 使用 worktree 标志时技能和 hooks 也正确加载 |
| **Large session truncation fix (v2.1.78)** | session | 修复 `cc log` / `--resume` 中 5MB+ 会话被截断的问题 |
| **`--console` auth flag (v2.1.79)** | setup | Anthropic Console API 计费认证的 `claude auth login --console` |
| **Turn duration toggle (v2.1.79)** | 所有技能 | 在 `/config` 中切换轮次执行时间显示 |
| **`CLAUDE_CODE_PLUGIN_SEED_DIR` multiple dirs (v2.1.79)** | setup | 使用平台分隔符指定多个种子目录 |
| **SessionEnd hooks fix in `/resume` (v2.1.79)** | hooks | 交互式 `/resume` 会话切换时 SessionEnd hooks 正常触发 |
| **18MB startup memory reduction (v2.1.79)** | 所有技能 | 启动时内存使用减少约 18MB |

完整详情：[docs/CLAUDE-feature-table.md](docs/CLAUDE-feature-table.md)

## 开发规则

### 提交信息

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：`feat:` / `fix:` / `docs:` / `refactor:` / `test:` / `chore:`

### 版本管理

保持 `VERSION` 和 `.claude-plugin/plugin.json` 同步。
普通功能/文档 PR 必须保持两个文件不变，并在 `CHANGELOG.md` 的 `[Unreleased]` 部分记录更改。
仅在发布时使用 `./scripts/sync-version.sh bump`。

### CHANGELOG

详情：[.claude/rules/changelog.md](.claude/rules/changelog.md)（Keep a Changelog 格式；重大更改包含 Before/After 表格）

### 语言

所有回复必须使用**中文**（包括 `context: fork` 技能）。

### 代码风格

- 使用清晰且描述性的名称
- 为复杂逻辑添加注释
- 保持命令/agents/技能单一职责

## 仓库结构

`.claude-plugin/` 插件清单 / `agents/` 子 agents / `skills/` 技能 / `hooks/` 钩子 / `scripts/` Shell 脚本 / `docs/` 文档 / `tests/` 验证

## 使用技能（重要）

**开始工作前**：如果存在相关技能，先用 Skill 工具启动它。

> 对于繁重任务，技能通过 Task 工具并行生成 `agents/` 中的子 agents。

### 顶级技能类别（前 5）

| 类别 | 用途 | 触发示例 |
|---------|---------|-----------------|
| work | 任务实现（自动范围检测，--codex 支持） | "implement"、"do it all"、"/work" |
| breezing | Agent Teams 全自动运行（--codex 支持） | "run with team"、"breezing" |
| harness-review | 代码审查、质量检查 | "review"、"security"、"performance" |
| setup | 设置集成中心（init、harness-mem、Codex CLI 等） | "setup"、"initialize"、"harness-mem"、"codex-setup" |
| memory | SSOT 管理、内存搜索、SSOT 提升 | "SSOT"、"decisions.md"、"memory search"、"claude-mem" |

完整类别列表和层次结构：[docs/CLAUDE-skill-catalog.md](docs/CLAUDE-skill-catalog.md)

## 开发流程

0. **编辑 skills/hooks 时**：运行 `/reload-plugins` 立即刷新运行时缓存
1. **计划**：使用 `/plan-with-agent` 向 Plans.md 添加任务
2. **实现**：`/work`（Claude 实现）或 `/breezing`（团队全运行）。两者都支持 `--codex`
3. **审查**：自动运行（手动：`/harness-review`）
4. **验证**：运行 `./tests/validate-plugin.sh` 进行结构验证

## 测试

```bash
./tests/validate-plugin.sh          # 验证插件结构
./scripts/ci/check-consistency.sh   # 一致性检查
```

详情：[docs/CLAUDE-commands.md](docs/CLAUDE-commands.md)

## 注意事项

- **注意自指性**：在此插件上运行 `/work` 意味着编辑其自身的代码
- **Hooks 自动运行**：PreToolUse/PostToolUse 守护处于活动状态
- **VERSION 同步**：普通 PR 中不要修改版本文件；仅在发布时更新

## 关键命令（用于开发）

| 命令 | 用途 |
|---------|---------|
| `/plan-with-agent` | 向 Plans.md 添加改进任务 |
| `/work` | 实现任务（自动范围检测，--codex 支持） |
| `/breezing` | Agent Teams 全并行运行（--codex 支持） |
| `/harness-review` | 审查更改 |
| `/validate` | 验证插件 |
| `/remember` | 记录学习内容 |

详情和交接：[docs/CLAUDE-commands.md](docs/CLAUDE-commands.md)

## SSOT（单一事实来源）

- `.claude/memory/decisions.md` - 决策（为什么）
- `.claude/memory/patterns.md` - 可复用模式（如何做）

## 测试篡改预防

> **绝对禁止**：篡改测试以伪造"成功"

详情：[.claude/rules/test-quality.md](.claude/rules/test-quality.md) / [.claude/rules/implementation-quality.md](.claude/rules/implementation-quality.md)
