# Claude Code 2.1.74+ 新功能使用指南（完整版）

> **概述**: Harness 使用的 Claude Code 2.1.74+ 全部功能列表。
> CLAUDE.md Feature Table 的完整版（附带详细说明）。

## 功能列表

| 功能 | 活用技能 | 用途 |
|------|-----------|------|
| **Task tool 指标** | parallel-workflows | 统计子代理的 token/工具/时间 |
| **`/debug` 命令** | troubleshoot | 诊断复杂的会话问题 |
| **PDF 页面范围** | notebookLM, harness-review | 大型文档的高效处理 |
| **Git log 标志** | harness-review, CI, harness-release | 结构化的提交分析 |
| **OAuth 认证** | codex-review | DCR 非兼容 MCP 服务器设置 |
| **68% 内存优化** | session-memory, session | 积极使用 `--resume` |
| **子代理 MCP** | task-worker | 并行执行时的 MCP 工具共享 |
| **Reduced Motion** | harness-ui | 无障碍设置 |
| **TeammateIdle/TaskCompleted Hook** | breezing | 团队监控自动化 |
| **Agent Memory (memory frontmatter)** | task-worker, code-reviewer | 持久化学习 |
| **Fast mode (Opus 4.6)** | 全技能 | 高速输出模式 |
| **自动内存记录** | session-memory | 会话间知识自动持久化 |
| **技能预算缩放** | 全技能 | 自动调整为上下文窗口的 2% |
| **Task(agent_type) 限制** | agents/ | 子代理类型限制 |
| **Plugin settings.json** | setup | 减少 init token 消耗 + 即时安全保护 |
| **Worktree isolation** | breezing, parallel-workflows | 同一文件并行写入安全化 |
| **Background agents** | generate-video | 异步场景生成 |
| **ConfigChange hook** | hooks | 配置变更审计 |
| **last_assistant_message** | session-memory | 会话质量评估 |
| **Sonnet 4.6 (1M context)** | 全技能 | 大规模上下文处理 |
| **内存泄漏修复 (v2.1.50〜v2.1.63)** | breezing, work | 长时间团队会话稳定性提升 |
| **`claude agents` CLI (v2.1.50)** | troubleshoot | 代理定义的诊断和确认 |
| **WorktreeCreate/Remove hook (v2.1.50)** | breezing | Worktree 生命周期自动设置和清理（已实现） |
| **`claude remote-control` (v2.1.51)** | 已调研・将来支持 | 外部构建和本地环境服务 |
| **`/simplify` (v2.1.63)** | work | Phase 3.5 Auto-Refinement: 实现后的自动代码优化 |
| **`/batch` (v2.1.63)** | breezing | 横向展开任务的并行迁移委托 |
| **`code-simplifier` 插件** | work | `--deep-simplify` 时的深度重构 |
| **HTTP hooks (v2.1.63)** | hooks | 通过 JSON POST 的外部服务联动钩子（已实现） |
| **Auto-memory worktree 共享 (v2.1.63)** | breezing | worktree 代理间的内存共享 |
| **`/clear` 技能缓存重置 (v2.1.63)** | troubleshoot | 技能开发时的缓存问题诊断 |
| **`ENABLE_CLAUDEAI_MCP_SERVERS` (v2.1.63)** | setup | claude.ai MCP 服务器禁用选项 |
| **Effort levels + ultrathink (v2.1.68)** | harness-work | 多因素评分为复杂任务自动注入 ultrathink |
| **Agent hooks (v2.1.68)** | hooks | type: "agent" 的 LLM 代理代码质量守护 |
| **Opus 4/4.1 删除（v2.1.68）** | — | 从 first-party API 删除。自动迁移到 Opus 4.6 |
| **`${CLAUDE_SKILL_DIR}` 变量 (v2.1.69)** | 全技能 | 以执行环境无关的方式解析技能内的引用路径 |
| **InstructionsLoaded hook (v2.1.69)** | hooks | 跟踪会话前的 instructions 读取事件 |
| **`agent_id` / `agent_type` 添加 (v2.1.69)** | hooks, breezing | 稳定化队友的识别和角色判定 |
| **`{"continue": false}` teammate 响应 (v2.1.69)** | breezing | 实现全部任务完成时的自动停止 |
| **`/reload-plugins` (v2.1.69)** | 全技能 | 技能/钩子编辑后的即时反映 |
| **`includeGitInstructions: false` (v2.1.69)** | work, breezing | 减少 git 指令不需要场景的 token |
| **`git-subdir` plugin source (v2.1.69)** | setup, release | 支持子目录管理的 plugin source |
| **Auto Mode rollout prep** | breezing, work | 从 `bypassPermissions` 迁移的候选。现行 shipped default 是 `bypassPermissions`，`--auto-mode` 是兼容父会话的 opt-in marker |
| **Per-agent hooks (v2.1.69+)** | agents-v3/ | 在代理定义的 frontmatter 中添加 `hooks` 字段。Worker 设置 PreToolUse 守护，Reviewer 设置 Stop 日志 |
| **Agent `isolation: worktree` (v2.1.50+)** | agents-v3/worker | 在 Worker 代理定义中添加 `isolation: worktree`。并行写入时的自动 worktree 分离 |
| **Compaction 图片保留 (v2.1.70)** | notebookLM, harness-review | 在摘要请求中保留图片。改善提示词缓存重用 |
| **子代理最终报告简洁化 (v2.1.70)** | breezing, harness-work | 减少子代理完成报告的 token 消耗 |
| **`--resume` 技能列表再注入废除 (v2.1.70)** | session | 会话恢复时节省约 600 tokens |
| **Plugin hooks 修复 (v2.1.70)** | hooks | Stop/SessionEnd 在 /plugin 后触发、解决模板冲突、WorktreeCreate/Remove 正常运作 |
| **Teammate 嵌套防止追加修复 (v2.1.70)** | breezing | 除 v2.1.69 对应外，额外的嵌套防止修复 |
| **PostToolUseFailure hook (v2.1.70)** | hooks | 工具调用失败时触发的新钩子事件 |
| **`/loop` + Cron 调度 (v2.1.71)** | breezing, harness-work | 通过 `/loop 5m <prompt>` 定期执行。用于任务进度自动监控 |
| **Background Agent 输出路径修复 (v2.1.71)** | breezing, parallel-workflows | 完成通知中包含输出文件路径。压缩后也能回收结果 |
| **`--print` 团队代理 hang 修复 (v2.1.71)** | CI 联动 | 修复 `--print` 模式下团队代理 hang 的问题 |
| **Plugin 安装并行执行修复 (v2.1.71)** | breezing | 多实例时稳定化插件状态 |
| **Marketplace 改善 (v2.1.71)** | setup | @ref 解析器修复、update merge conflict 修复、MCP server 重复排除、/plugin uninstall 使用 settings.local.json |
| **Subagent `background` 字段 (v2.1.71+)** | breezing, parallel-workflows | 在代理定义中添加 `background: true`。始终作为后台任务执行 |
| **Subagent `local` 内存作用域 (v2.1.71+)** | agents-v3/ | 通过 `memory: local` 保存到 `.claude/agent-memory-local/`。分离不应提交到 VCS 的高机密性学习 |
| **Agent Teams 实验标志 (v2.1.71+)** | breezing | 通过 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 环境变量启用 Agent Teams。官方文档化已完成 |
| **`/agents` 命令 (v2.1.71+)** | troubleshoot, setup | 代理的交互式管理 UI。通过 GUI 操作创建/编辑/删除/列表 |
| **Desktop Scheduled Tasks (v2.1.71+)** | harness-work | 以 `~/.claude/scheduled-tasks/<task-name>/SKILL.md` 格式定义定期任务。通过 Desktop 应用管理 |
| **`CronCreate/CronList/CronDelete` 工具 (v2.1.71+)** | breezing, harness-work | `/loop` 的内部工具。会话内创建和管理定期任务 |
| **`CLAUDE_CODE_DISABLE_CRON` 环境变量 (v2.1.71+)** | setup | `=1` 禁用 Cron 调度器。用于安全策略限制定期执行的环境 |
| **`--agents` CLI 标志 (v2.1.71+)** | breezing, CI | 通过 JSON 传递会话级代理定义。不保存到磁盘的临时代理配置 |
| **`ExitWorktree` 工具 (v2.1.72)** | breezing, harness-work | 以编程方式退出 worktree 会话的工具 |
| **Effort levels 简化 (v2.1.72)** | harness-work | 废除 `max`，`low/medium/high` 的3个级别 + `○ ◐ ●` 符号。`/effort auto` 重置为默认 |
| **Agent tool `model` 参数恢复 (v2.1.72)** | breezing | per-invocation model override 再次可用 |
| **`/plan` description 参数 (v2.1.72)** | harness-plan | 可以通过 `/plan fix the auth bug` 带说明进入计划模式 |
| **并行工具调用修复 (v2.1.72)** | breezing, harness-work | Read/WebFetch/Glob 失败不再取消同级调用（仅 Bash 错误级联） |
| **Worktree isolation 修复 (v2.1.72)** | breezing | Task resume 时的 cwd 还原、background 通知包含 worktreePath |
| **`/clear` 后台代理保留 (v2.1.72)** | breezing | `/clear` 只停止前台任务。后台代理继续存在 |
| **Hooks 修复群 (v2.1.72)** | hooks | transcript_path 修复、PostToolUse 双重显示修复、async hooks stdin 修复、skill hooks 双重触发修复 |
| **HTML 注释隐藏 (v2.1.72)** | 全技能 | CLAUDE.md 的 `<!-- -->` 在自动注入时隐藏。通过 Read 工具仍然可见 |
| **Bash auto-approval 追加 (v2.1.72)** | guardrails | `lsof`, `pgrep`, `tput`, `ss`, `fd`, `fdfind` 添加到允许列表 |
| **提示词缓存修复 (v2.1.72)** | 全技能 | SDK `query()` 缓存无效化修复。输入 token 成本最多减少 12 倍 |
| **Output Styles (v2.1.72+)** | 全技能 | 在 `.claude/output-styles/` 中定义自定义输出样式。通过 `harness-ops` 提供 Plan/Work/Review 的结构化输出 |
| **`permissionMode` in agent frontmatter (v2.1.72+)** | agents-v3/ | 在代理定义 YAML 中显式声明 `permissionMode`。spawn 时不再需要 `mode` 指定 |
| **Agent Teams 官方最佳实践 (v2.1.72+)** | breezing | 将 5-6 tasks/teammate 指南、`teammateMode` 设置、plan approval 模式反映到 team-composition |
| **Sandboxing (`/sandbox`)** | breezing, harness-work | 操作系统级文件系统/网络隔离。`bypassPermissions` 的补充层 |
| **`opusplan` 模型别名** | breezing | 计划时自动切换 Opus，执行时切换 Sonnet。最适合 Lead 的 Plan → Execute 流程 |
| **`CLAUDE_CODE_SUBAGENT_MODEL` 环境变量** | breezing, harness-work | 统一指定子代理的模型。集中控制 Worker/Reviewer 的模型 |
| **`availableModels` 设置** | setup | 可用模型的限制列表。企业运营中的模型治理 |
| **Checkpointing (`/rewind`)** | harness-work | 跟踪/回滚/摘要会话状态。支持安全的探索和实验 |
| **Code Review (托管服务)** | harness-review | 多代理 PR 审查 + `REVIEW.md`。Teams/Enterprise 的 Research Preview |
| **Status Line (`/statusline`)** | 全技能 | 通过自定义 shell 脚本显示状态栏。持续监控上下文使用量/成本/git 状态 |
| **1M Context Window (`sonnet[1m]`)** | harness-review, breezing | 活用 100 万 token 上下文窗口进行大规模代码库分析 |
| **Per-model Prompt Caching Control** | 全技能 | 通过 `DISABLE_PROMPT_CACHING_*` 按模型控制缓存。调试/成本优化 |
| **`CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`** | harness-work | 禁用 Adaptive Reasoning 恢复到固定 thinking budget。可预测的成本控制 |
| **Chrome Integration (`--chrome`, beta)** | harness-work, harness-review | 通过浏览器自动化进行 UI 测试/表单输入/控制台调试。`/chrome` 在会话内切换 |
| **LSP 服务器集成 (`.lsp.json`)** | setup | 通过 Language Server Protocol 实时提供类型信息/诊断/引用搜索。可使用 `pyright-lsp`, `typescript-lsp`, `rust-lsp` |
| **`SubagentStart`/`SubagentStop` matcher (v2.1.72+)** | breezing, hooks | 在 settings.json 级别按 agent type 监控子代理生命周期。单独追踪 Worker/Reviewer/Scaffolder/Video Generator |
| **Agent Teams: Task Dependencies** | breezing | 自动管理任务间依赖。依赖完成后 blocked 任务自动 unblock。文件锁防止 claiming 竞争 |
| **`--teammate-mode` CLI 标志 (v2.1.72+)** | breezing | 按会话切换 `in-process`/`tmux` 显示模式。`claude --teammate-mode in-process` |
| **`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` (v2.1.72+)** | setup | `=1` 禁用所有后台任务功能。用于安全策略限制后台执行的环境 |
| **`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (v2.1.72+)** | breezing, harness-work | 调整子代理的 auto-compaction 阈值（默认 95%）。`50` 启用早期压缩，提高长时间 Worker 稳定性 |
| **`cleanupPeriodDays` 设置 (v2.1.72+)** | setup | 子代理 transcript 的自动清理期间（默认 30 天） |
| **`/btw` 侧边提问 (v2.1.72+)** | 全技能 | 保持当前上下文的简短提问。无工具访问，不留历史记录。子代理启动的轻量替代 |
| **Plugin CLI 命令群 (v2.1.72+)** | setup | `claude plugin install/uninstall/enable/disable/update` + `--scope` 标志。支持脚本自动化 |
| **Remote Control 增强 (v2.1.72+)** | 已调研・将来支持 | `/remote-control` (`/rc`) 在会话内启用。`--name`, `--sandbox`, `--verbose` 标志。`/mobile` 显示 QR 码。支持自动重连 |
| **`skills` 字段 in agent frontmatter (v2.1.72+)** | agents-v3/ | 为子代理预加载技能。Worker 注入 `harness-work`+`harness-review`，Reviewer 注入 `harness-review`，Scaffolder 注入 `harness-setup`+`harness-plan`（已实现） |
| **`modelOverrides` 设置 (v2.1.73)** | setup, breezing | 将模型选择器条目映射到 Bedrock ARN 等自定义提供商模型 ID |
| **`/output-style` 弃用化 (v2.1.73)** | 全技能 | 迁移到 `/config`。输出样式选择整合到配置菜单 |
| **Bedrock/Vertex Opus 4.6 默认化 (v2.1.73)** | breezing | 云提供商的默认 Opus 从 4.1 更新到 4.6 |
| **`autoMemoryDirectory` 设置 (v2.1.74)** | session-memory, setup | 自定义自动内存的保存路径。支持项目特定的内存分离 |
| **`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (v2.1.74)** | hooks | 可设置 SessionEnd 钩子超时（原来是固定 1.5 秒 kill） |
| **Full model ID 修复 (v2.1.74)** | agents-v3/, breezing | `claude-opus-4-6` 等完整模型 ID 可在代理 frontmatter/JSON config 中识别 |
| **Streaming API 内存泄漏修复 (v2.1.74)** | breezing, harness-work | 修复流式响应缓冲区的无限制 RSS 增长 |
| **`--remote` / Cloud Sessions** | breezing, harness-work | 通过 `--remote` 从终端启动云会话。异步任务执行 |
| **`/teleport` (`/tp`)** | session | 将云会话纳入本地终端 |
| **`CLAUDE_CODE_REMOTE` 环境变量** | hooks, session-env-setup | 检测云 vs 本地执行。用于钩子的条件分支 |
| **`CLAUDE_ENV_FILE` SessionStart 持久化** | hooks, session-env-setup | 从 SessionStart 钩子向后续 Bash 命令持久化环境变量 |
| **Slack Integration (`@Claude`)** | harness-work (将来支持) | 从 Slack 频道路由编码任务。可通过 HTTP hooks 联动 |
| **Server-managed settings (public beta)** | setup | 通过服务器分发统一设置管理。Teams/Enterprise 向 |
| **Microsoft Foundry** | setup, breezing | 作为新云提供商添加 |
| **`PreCompact` hook** | hooks | 上下文压缩前的状态保存和 WIP 任务警告（已实现） |
| **`Notification` hook event** | hooks | 通知触发时的自定义处理器（已实现） |
| **`/context` 命令 (v2.1.74)** | all skills | 可视化上下文消耗并提供优化建议 |
| **`maxTurns` 代理安全限制** | agents-v3/ | 通过轮次上限防止失控。Worker: 100, Reviewer: 50, Scaffolder: 75 |
| **Output token limits 64k/128k (v2.1.77)** | all skills | Opus 4.6 / Sonnet 4.6 默认 64k，上限 128k token |
| **`allowRead` sandbox 设置 (v2.1.77)** | harness-review | 在 `denyRead` 内重新允许特定路径的读取 |
| **PreToolUse `allow` 尊重 `deny` (v2.1.77)** | guardrails | 钩子 `allow` 不覆盖 settings.json `deny` |
| **Agent `resume` → `SendMessage` (v2.1.77)** | breezing | Agent tool `resume` 废弃，迁移到 `SendMessage({to: agentId})` |
| **`/branch` (旧 `/fork`) (v2.1.77)** | session | `/fork` → `/branch` 重命名。别名保留 |
| **`claude plugin validate` 增强 (v2.1.77)** | setup | 添加 frontmatter + hooks.json 语法验证 |
| **`--resume` 45% 加速 (v2.1.77)** | session | fork-heavy 会话恢复的加速和内存减少 |
| **Stale worktree 竞争修复 (v2.1.77)** | breezing | 防止活跃 worktree 被误删 |
| **`StopFailure` hook event (v2.1.78)** | hooks | 捕获 API 错误导致的会话停止失败 |
| **`${CLAUDE_PLUGIN_DATA}` 变量 (v2.1.78)** | hooks, setup | 插件更新后仍持久的状态目录 |
| **Agent `effort`/`maxTurns`/`disallowedTools` frontmatter (v2.1.78)** | agents-v3/ | 插件代理的声明式控制 |
| **`deny: ["mcp__*"]` 修复 (v2.1.78)** | setup | settings.json deny 正确阻止 MCP 工具 |
| **`ANTHROPIC_CUSTOM_MODEL_OPTION` (v2.1.78)** | setup | 自定义模型选择器条目 |
| **`--worktree` skills/hooks 读取修复 (v2.1.78)** | breezing | worktree 标志时技能和钩子正常加载 |
| **Large session truncation 修复 (v2.1.78)** | session | 修复 5MB+ 会话的截断问题 |
| **`--console` auth 标志 (v2.1.79)** | setup | Anthropic Console API 计费认证 |
| **Turn duration 显示 (v2.1.79)** | all skills | `/config` 切换轮次执行时间显示 |
| **`CLAUDE_CODE_PLUGIN_SEED_DIR` 多目录支持 (v2.1.79)** | setup | 多个种子目录指定 |
| **SessionEnd hooks `/resume` 修复 (v2.1.79)** | hooks | 交互式会话切换时 SessionEnd 正常触发 |
| **18MB startup memory 减少 (v2.1.79)** | all skills | 启动时内存使用量减少 |

## 功能详情

### Task tool 指标

可以统计子代理消耗的 token 数、工具调用数和执行时间。
`parallel-workflows` 技能汇总多个子代理的指标，用于成本分析。

```
metrics: {tokens: 40000, tools: 7, duration: 67s}
```

### `/debug` 命令

会话诊断用命令。用于调查复杂错误或意外行为的原因。
`troubleshoot` 技能自动启动，系统性地诊断问题。

### PDF 页面范围指定

读取大型 PDF 时可以指定页面范围（例: `pages: "1-5"`）。
用于 `notebookLM` 技能的文档处理和 `harness-review` 的大型规格书参考。

### Git log 标志

活用 `git log` 的结构化选项（`--format`, `--stat`, `--since` 等）。
提高发布说明生成、提交分析和变更追踪的效率。

### OAuth 认证

针对不支持 DCR（Dynamic Client Registration）的 MCP 服务器的 OAuth 认证设置。
用于 `codex-review` 技能的 Codex CLI 连接。

### 68% 内存优化

通过 `--resume` 标志恢复会话时减少内存使用量。
对长时间作业会话的上下文延续有效。

### 子代理 MCP

通过 Task tool 启动的子代理可以共享父会话的 MCP 工具。
在 `task-worker` 的并行实现时，各代理可以使用相同的 MCP 工具集。

### Reduced Motion

无障碍设置。减少动态/动画的选项。
`harness-ui` 技能在 UI 生成时考虑此设置。

### TeammateIdle/TaskCompleted Hook

当 Breezing 团队成员进入空闲状态或任务完成时触发的钩子。
由 `scripts/hook-handlers/teammate-idle.sh` 和 `task-completed.sh` 处理。

```json
"TeammateIdle": [{"hooks": [{"type": "command", "command": "...teammate-idle", "timeout": 10}]}],
"TaskCompleted": [{"hooks": [{"type": "command", "command": "...task-completed", "timeout": 10}]}]
```

### Agent Memory (memory frontmatter)

通过代理定义 YAML 的 `memory: project` 字段启用持久内存。
`task-worker`, `code-reviewer` 可以跨会话学习过去的实现模式、失败和解决方案。

### Fast mode (Opus 4.6)

通过 `/fast` 命令切换的高速输出模式。使用相同的 Opus 4.6 模型。
所有技能可用。对缩短长实现任务的等待时间有效。

### 自动内存记录

会话结束时自动将学习内容持久化到内存文件。
由 `session-memory` 技能管理。下次会话自动恢复上次的上下文。

### 技能预算缩放

SKILL.md 的字符预算自动调整为上下文窗口的 2%。
推荐 500 行是参考值。实际上限取决于模型的上下文窗口大小。

### Task(agent_type) 限制

调用 Task tool 时指定 `subagent_type`，限制子代理的种类。
与 `agents/` 定义结合，保证只启动预期的代理。

### Plugin settings.json

通过插件的 `settings.json` 预定义初始化时的设置。
减少 init token 消耗，从会话开始就应用安全策略。

### Worktree isolation

使用 `git worktree` 安全化对同一文件的并行写入。
防止 `breezing` 和 `parallel-workflows` 中多代理并行实现时的冲突。

### Background agents

异步启动后台代理。无需等待完成即可继续其他处理。
用于 `generate-video` 技能的多场景并行生成。

### ConfigChange hook

当设置文件（`settings.json` 等）被更改时触发的钩子。
由 `scripts/hook-handlers/config-change.sh` 记录和审计变更。

### last_assistant_message

可以引用会话结束时的最后一条助手消息的功能。
`session-memory` 技能用于会话质量的自我评估。

### Sonnet 4.6 (1M context)

拥有最大 1M token 上下文窗口的 Sonnet 4.6 模型。
支持大规模代码库分析和长文档处理。所有技能可用。

> 补充: 2.1.69 系以旧 Sonnet 4.5 引用自动迁移到 Sonnet 4.6 为前提运营。

### 内存泄漏修复 (v2.1.50~v2.1.63)

CC 2.1.50 修复了 LSP 诊断数据、大型工具输出、文件历史和 shell 执行相关的内存泄漏。
还实现了已完成任务的垃圾回收，大幅改善了 `/breezing` 等长时间团队会话的稳定性。
v2.1.63 进一步修复了 MCP 重连时的泄漏、git root 缓存、JSON 解析缓存、Teammate 消息保持和 shell 命令前缀缓存的泄漏。
Harness 侧通过 JSONL 轮换（500→400 行）和原子更新已实施独立对策。

### `claude agents` CLI (v2.1.50)

`claude agents list` 显示已注册代理的列表。
`troubleshoot` 技能用于代理 spawn 失败时的诊断。

```bash
claude agents list   # 已注册代理的列表
```

### WorktreeCreate/WorktreeRemove hook (v2.1.50)

Worktree 创建和删除时触发的生命周期钩子。
用于 `/breezing` 并行工作流的自动设置和清理。
已在 `scripts/hook-handlers/worktree-create.sh` 和 `worktree-remove.sh` 中实现。

### `claude remote-control` (v2.1.51)

使外部构建系统和本地环境服务成为可能的子命令。
将来有可能用于 Breezing 的跨会话控制和 CI 联动。

### `/simplify` (v2.1.63)

CC 2.1.63 添加的实现后自动代码优化命令。
作为 `/work` 的 Phase 3.5 Auto-Refinement 集成，实现完成后自动简化和整理代码。
与 `code-simplifier` 插件结合，通过 `--deep-simplify` 选项也可以进行深度重构。

### `/batch` (v2.1.63)

将横向展开任务（将相同更改应用到多个文件的迁移等）并行委托的命令。
与 `/breezing` 结合使用，让 Breezing 团队并行执行批量迁移。
对提高重复作业的效率和减少人为失误有效。

### `code-simplifier` 插件

负责 `/simplify` 深度重构模式的外部插件。
指定 `--deep-simplify` 时启动，自动执行复杂逻辑的分解、去除不必要的抽象化和改善命名。
普通的 `/simplify` 是轻量的，`--deep-simplify` 执行更深入的重构。

### HTTP hooks (v2.1.63)

CC 2.1.63 添加的新钩子格式。除了现有的 `command` / `prompt` 类型，还可以使用 `http` 类型。
将 JSON POST 到指定 URL，可以与外部服务（Slack、仪表盘、指标收集等）联动。
详情请参阅 [.claude/rules/hooks-editing.md](../.claude/rules/hooks-editing.md) 的"http Type"部分。

### Auto-memory worktree 共享 (v2.1.63)

CC 2.1.63 使使用 `isolation: "worktree"` 时 Agent Memory 可以在 worktree 之间共享。
`/breezing` 的并行 Implementer 可以在各自的 worktree 分离中作业，同时参照和更新同一个 MEMORY.md。
防止 Implementer 之间的知识共享和对同一 bug 的重复处理。

### `/clear` 技能缓存重置 (v2.1.63)

CC 2.1.63 添加的技能缓存重置命令。
编辑技能文件后用旧缓存运行的问题（技能开发时频发）可以通过 `/clear` 解决。
已内置到 `troubleshoot` 技能的缓存问题诊断步骤。

### `ENABLE_CLAUDEAI_MCP_SERVERS` (v2.1.63)

CC 2.1.63 添加的环境变量。设置 `false` 可以禁用 claude.ai 提供的 MCP 服务器。
用于安全策略上需要限制连接外部 MCP 服务器的环境。
已添加到 `setup` 技能的环境初始化检查列表。

### Agent hooks (v2.1.68)

CC 2.1.68 添加的 `type: "agent"` 钩子。通过 LLM 代理进行钩子判断，可以动态判断正则表达式难以检测的代码质量问题。
Harness 在 3 处有限采用，为了成本管理用 `model: "haiku"` 和 `matcher` 缩小对象:

- **PreToolUse Write|Edit**: 密钥嵌入/TODO 残留/安全漏洞的守护
- **Stop**: WIP 任务残留守护（确认 Plans.md 的 `cc:WIP` 任务是否残留）
- **PostToolUse Write|Edit**: 异步代码审查（质量/命名/单一职责）

效果不足时可以回滚到 `command` 型的设计。

### Effort levels + ultrathink (v2.1.68)

CC 2.1.68 将 Opus 4.6 的 **medium effort** 改为默认。可以通过 `ultrathink` 关键字仅启用 1 轮的 high effort（extended thinking）。
`harness-work` 技能通过多因素评分（变更文件数/目标目录/关键词/失败历史/PM 显式指定）计算分数，阈值 3 以上时在 Worker spawn prompt 开头自动注入 `ultrathink`。
详情请参阅 `skills-v3/harness-work/SKILL.md` 的"Effort 级别控制"部分。

### Opus 4/4.1 删除（v2.1.68）

CC 2.1.68 从 first-party API 删除了 Opus 4 和 Opus 4.1。如果 Harness 在目标代理中指定 `model: opus`，会自动迁移到 Opus 4.6。
Worker/Reviewer 代理使用 `model: sonnet`，所以不受影响。只有 Lead（使用 Opus 时）接受 medium effort 成为默认的变更。

### `${CLAUDE_SKILL_DIR}` 变量 (v2.1.69)

CC 2.1.69 引入了技能执行时的基准路径变量 `${CLAUDE_SKILL_DIR}`。
Harness 将 `SKILL.md` 到 `references/*.md` 的引用链接统一为 `${CLAUDE_SKILL_DIR}/references/...`，即使在镜像配置（codex/opencode）中也保持相同的引用。

### InstructionsLoaded hook (v2.1.69)

CC 2.1.69 添加了 `InstructionsLoaded` 事件。Harness 新建了
`scripts/hook-handlers/instructions-loaded.sh`，用于 instructions 读取完成时的轻量追踪和事前验证。

### `agent_id` / `agent_type` 添加 (v2.1.69)

Teammate 系事件添加了 `agent_id` / `agent_type`。
Harness 的 guardrail 从 `session_id` 前提扩展为 `agent_id` 优先（fallback: `session_id`），稳定化了角色守护。

### `{"continue": false}` teammate 响应 (v2.1.69)

`TeammateIdle` / `TaskCompleted` 现在可以返回 `{"continue": false, "stopReason": "..."}`。
Harness 在收到 stop 请求和全部任务完成时返回该响应，使 breezing 的停止判定明确化。

### `/reload-plugins` (v2.1.69)

为了在编辑技能/钩子后不重启会话就反映更改，在开发流程中添加 `/reload-plugins`。
编辑 → `/reload-plugins` → 重新执行，作为标准步骤。

### `includeGitInstructions: false` (v2.1.69)

对于不需要常时嵌入 git 指令的任务，可以应用 `includeGitInstructions: false` 来抑制 token 消耗。
Harness 推荐在 breezing/work 的轻量任务（如文档更新）中使用。

### `git-subdir` plugin source (v2.1.69)

支持在 monorepo 的子目录中管理 plugin source 的 `git-subdir` 方式。
Harness 目前不强制在 `.claude-plugin/plugin.json` 中添加额外字段，在发布时明确指定 `plugin source` 运营（优先兼容性）。

### Compaction 图片保留 (v2.1.70)

CC 2.1.70 使上下文压缩（Compaction）时的摘要请求可以保留图片。
这样，包含截图和图表的会话在 Compaction 后也能维持图片上下文。
提示词缓存的重用率也得到改善，处理图片的技能整体效率提高。

### 子代理最终报告简洁化 (v2.1.70)

子代理完成时的最终报告变得简洁，减少了 token 消耗。
在 `breezing` 和 `harness-work` 中启动大量子代理时，累积的 token 节约效果很大。

### `--resume` 技能列表再注入废除 (v2.1.70)

`--resume` 恢复会话时，技能列表的再注入被废除。
这节省了约 600 tokens，使 `session` 技能的恢复流程更轻量。

### Plugin hooks 修复 (v2.1.70)

v2.1.70 修复了多个 Plugin hooks 相关 bug:
- `Stop` / `SessionEnd` 钩子在 `/plugin` 命令执行后也正常触发
- 解决了具有相同模板的钩子之间的冲突
- 确认 `WorktreeCreate` / `WorktreeRemove` 钩子正常运作

### Teammate 嵌套防止追加修复 (v2.1.70)

对 v2.1.69 已处理的 Teammate 嵌套防止进行了追加修复。
强化了防止代理无限 spawn 其他代理的级联问题。

### PostToolUseFailure hook (v2.1.70)

CC 2.1.70 添加了 `PostToolUseFailure` 事件。工具调用失败时触发的新钩子事件。
Harness 在 `hooks` 技能和 `error-recovery` 中使用，用于连续失败时的自动升级（3 次连续失败停止）。

```json
"PostToolUseFailure": [{
  "hooks": [{
    "type": "command",
    "command": "...post-tool-failure.sh",
    "timeout": 10
  }]
}]
```

### `/loop` + Cron 调度 (v2.1.71)

CC 2.1.71 添加了 `/loop` 命令。像 `/loop 5m <prompt>` 这样指定间隔和提示词，可以定期执行命令的 Cron 风格调度。
`breezing` 中用 `/loop 5m /sync-status` 定期检查任务进度。
与现有的 `TeammateIdle`（被动/事件驱动）不同，可以主动进行定期监控。

### Background Agent 输出路径修复 (v2.1.71)

CC 2.1.71 使 Background Agent 的完成通知包含输出文件路径。
这样，压缩后也能安全回收后台代理的结果。
`breezing` 和 `parallel-workflows` 中的 `run_in_background: true` 变得实用。

### `--print` 团队代理 hang 修复 (v2.1.71)

修复了 `--print` 模式下团队代理 hang 的问题。
CI 管道中执行 `claude --print` 时团队代理的稳定性提高。

### Plugin 安装并行执行修复 (v2.1.71)

修复了多个 Claude Code 实例同时安装插件时的状态竞争。
`breezing` 中多个 Teammate 同时启动时的插件加载稳定性提高。

### Marketplace 改善 (v2.1.71)

CC 2.1.71 对 Marketplace 周边进行了多项改善:
- `@ref` 解析器修复: `owner/repo@vX.X.X` 格式的引用解析更准确
- update 时的 merge conflict 修复: 插件更新更稳定
- MCP server 重复排除: 防止同一 MCP 服务器的多重注册
- `/plugin uninstall` 使用 `settings.local.json`: 正确反映用户本地设置

### Per-agent hooks (v2.1.69+)

CC 2.1.69 在代理定义的 frontmatter 中添加了 `hooks` 字段。
可以与全局 hooks.json 分开定义代理特定的钩子。

Harness 中的活用:
- **Worker**: 通过 `PreToolUse` 应用 Write/Edit 时的 `pre-tool.sh` 护栏
- **Reviewer**: 通过 `Stop` 输出审查会话完成日志

代理定义内钩子仅在该代理的生命周期中有效，结束时自动清理。

### Agent `isolation: worktree` (v2.1.50+)

在代理定义的 frontmatter 中添加 `isolation: worktree`，
该代理在启动时自动创建 git worktree，在独立的仓库副本中作业。
如果没有变更，worktree 会自动清理。

Harness 在 Worker 代理中添加了 `isolation: worktree`。
与 `memory: project` 结合，worktree 之间共享 Agent Memory（MEMORY.md），
并行 Worker 可以参照和更新同一学习内容。

### Auto Mode rollout 策略

Auto Mode 作为将 Claude Code 的 team execution 转向更安全方向的迁移候选进行整理。
但 shipped default 仍然是 `bypassPermissions`，project template 和 frontmatter 中只保留官方 docs 中记载的 permission mode。

| 层级 | 采用值 | 理由 |
|---------|--------|------|
| project template (`permissions.defaultMode`) | `bypassPermissions` | 因为 documented permission modes 不包含 `autoMode` |
| agent frontmatter (`permissionMode`) | `bypassPermissions` | 因为声明式设置只使用 documented 值 |
| teammate 执行路径 | `bypassPermissions`（现行） | 为了使 shipped default 和实际 permission 继承一致 |
| `--auto-mode` | opt-in marker | 只在父会话兼容 permission mode 时尝试 rollout |

默认命令示例:

```bash
/breezing all
/execute --breezing all
```

### Subagent `background` 字段

在代理定义的 frontmatter 中添加 `background: true`，该代理将始终作为后台任务执行。
即使不显式指定 `run_in_background: true`，每次通过 Agent tool 启动时都会后台执行。

```yaml
---
name: long-running-analyzer
background: true
---
```

Harness 中的 `breezing` 技能在 Worker spawn 时可以考虑使用，但目前 Lead 显式控制 `run_in_background`，因此追加应用将在 Phase 2 及以后考虑。

### Subagent `local` 内存作用域

`memory: local` 保存到 `.claude/agent-memory-local/<name>/`，是应添加到 `.gitignore` 的路径。
与 `project` 的区别:

| 作用域 | 路径 | VCS 提交 | 用例 |
|---------|------|-------------|------------|
| `user` | `~/.claude/agent-memory/<name>/` | 不适用 | 全项目共通的学习 |
| `project` | `.claude/agent-memory/<name>/` | 可共享 | 团队共享的项目知识 |
| `local` | `.claude/agent-memory-local/<name>/` | 不推荐 | 个人特有・高机密性的学习 |

Harness 中 Worker/Reviewer 均使用 `memory: project`。`local` 适合记录个人调试模式，但优先团队共享，因此维持现行设置。

### Agent Teams 实验标志

Agent Teams 作为实验性功能，通过 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 环境变量启用。
也可以通过 settings.json 设置:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Harness 的 `breezing` 技能以 Agent Teams 功能为前提，
因此在设置时添加验证步骤确认此环境变量已配置。

### Desktop Scheduled Tasks

Desktop 应用的 Scheduled Tasks 保存在 `~/.claude/scheduled-tasks/<task-name>/SKILL.md`。
通过 YAML frontmatter 定义 `name` 和 `description`，正文中记录提示词。

调度设置（频率・时刻・文件夹）通过 Desktop 应用的 UI 管理。
可用于定期执行 `/harness-work` 或 `/harness-review`。

### `/agents` 命令

代理的交互式管理界面。支持以下操作:
- 显示所有可用代理列表（built-in, user, project, plugin）
- 通过引导或 Claude 生成创建代理
- 编辑现有代理的设置・工具访问权限
- 删除自定义代理

CLI 的非交互式列表显示: `claude agents`

### `--agents` CLI 标志

会话启动时通过 JSON 传递代理定义。不保存到磁盘的临时配置:

```bash
claude --agents '{
  "quick-reviewer": {
    "description": "Quick code review",
    "prompt": "Review for critical issues only",
    "tools": ["Read", "Grep", "Glob"],
    "model": "haiku"
  }
}'
```

用于 CI/CD 管道中临时注入代理。

### `ExitWorktree` 工具 (v2.1.72)

CC 2.1.72 中添加了 `ExitWorktree` 工具。可以从 `EnterWorktree` 创建的 worktree 会话中编程式退出。
以前只能在 worktree 会话结束时的提示中手动选择，现在代理可以在实现完成后自动退出 worktree。

Harness 中的使用:
- `breezing` 的 Worker 在 `isolation: worktree` 下完成工作后，通过 `ExitWorktree` 显式关闭 worktree
- 提高 worktree 清理的确定性（可与无更改时自动删除的现有行为结合使用）

### Effort levels 简化 (v2.1.72)

CC 2.1.72 中 effort 级别简化为 `low/medium/high` 三个档次。废弃了 `max` 级别，显示符号统一为 `○ ◐ ●`。可通过 `/effort auto` 重置为默认（medium）。

对 Harness 的影响:
- `ultrathink` 关键字注入 high effort 仍然有效（无变更）
- harness-work 的评分逻辑无需更改（ultrathink → high effort 的对应关系保持）
- 文档中对 `max` 的提及统一改为 `high`

### Agent tool `model` 参数恢复 (v2.1.72)

CC 2.1.72 中 Agent tool 的 `model` 参数恢复。可以 per-invocation 指定模型启动子代理。
与代理定义的 `model` 字段分开，spawn 时可以指定临时模型。

Harness 中的使用余地:
- 轻量任务（文档更新、格式修正等）使用 `model: "haiku"` spawn 以降低成本
- 安全审查或架构变更使用 `model: "opus"` spawn 以最大化质量
- 现状 Worker/Reviewer 均固定为 `model: sonnet`。Lead 根据任务特性动态切换模型的实现将在 Phase 2 及以后考虑

### `/plan` description 参数 (v2.1.72)

CC 2.1.72 中 `/plan` 命令开始接受可选的 description 参数。
可以像 `/plan fix the auth bug` 这样，带说明即时进入计划模式。

Harness 中的使用:
- 可与 `harness-plan` 技能的 `create` 子命令互补使用
- 作为用户想要简单进入计划模式时的快捷方式

### 并行工具调用修复 (v2.1.72)

CC 2.1.72 中修复了并行工具调用时的重要 bug。
以前 Read, WebFetch, Glob 中任何一个失败，并行执行中的 sibling 调用也会被取消。
修复后只有 Bash 错误会级联，其他工具的失败独立处理。

对 Harness 的影响:
- `breezing` 和 `harness-work` 中并行执行文件读取和 Web 搜索时的稳定性提高
- 不存在的文件的 Read 取消其他正常 Read 的问题已解决
- Worker 代理探索阶段的可靠性改善

### Worktree isolation 修复 (v2.1.72)

CC 2.1.72 中修复了 worktree isolation 相关的两个 bug:

1. **Task resume 的 cwd 恢复**: 通过 `resume` 参数恢复的任务可以正确恢复 worktree 的工作目录
2. **Background 通知的 worktreePath**: 后台任务的完成通知现在包含 `worktreePath` 字段

对 Harness 的影响:
- `breezing` 的 Worker 在 `isolation: worktree` 下工作，Lead 收集结果时的可靠性提高
- 可以从 `run_in_background: true` spawn 的 Worker 完成通知中获取 worktree 路径

### `/clear` 后台代理保留 (v2.1.72)

CC 2.1.72 中 `/clear` 的行为已更改。只停止前台任务，后台运行的代理和 Bash 任务不受影响。

对 Harness 的影响:
- `breezing` 团队执行中用户执行 `/clear` 后台 Worker 仍然存活
- Lead 通过 `/clear` 整理上下文时，正在执行的任务不会被中断，安全性提高

### Hooks 修复群 (v2.1.72)

CC 2.1.72 中修复了多个钩子相关 bug:

1. **transcript_path**: `--resume` / `--fork` 会话中的 `transcript_path` 现在正确设置
2. **PostToolUse 阻止理由双重显示**: PostToolUse 钩子阻止时的理由消息显示两次的问题已修复
3. **async hooks 的 stdin**: 异步钩子现在可以正确接收 stdin
4. **skill hooks 双重触发**: 技能钩子每个事件触发两次的问题已修复

对 Harness 的影响:
- `pre-tool.sh` / `post-tool.sh` 护栏钩子的触发准确变为 1 次，日志可靠性提高
- `session-memory` 的 transcript 引用在 `--resume` 会话中也能正常工作

### HTML 注释隐藏 (v2.1.72)

CC 2.1.72 中 CLAUDE.md 文件内的 HTML 注释（`<!-- ... -->`）在自动注入时被隐藏。
通过 Read 工具直接读取文件时仍然可见。

对 Harness 的影响:
- claude-mem 使用的 `<!-- This section is auto-generated by claude-mem. -->` 标记在自动注入时被隐藏
- **无实际影响**: 标记是信息注释，activity log 表本体存在于注释外，因此不影响显示
- 今后应避免在 HTML 注释中记录重要指示或设置

### Bash auto-approval 追加 (v2.1.72)

CC 2.1.72 中以下命令被添加到 Bash auto-approval 许可列表:
`lsof`, `pgrep`, `tput`, `ss`, `fd`, `fdfind`

对 Harness 的影响:
- Worker 可以在无权限提示的情况下执行进程确认（`pgrep`）和文件搜索（`fd`）
- guardrails 的 `pre-tool.sh` 仍然放行这些命令（不在阻止对象内）

### 提示词缓存修复 (v2.1.72)

CC 2.1.72 中修复了 SDK 的 `query()` 调用时提示词缓存禁用的 bug。
输入 token 成本最多削减 12 倍。

对 Harness 的影响:
- `breezing` 和 `harness-work` 中 spawn 大量子代理时成本大幅削减
- 特别是在同一会话内反复进行 API 调用的模式效果显著

### Output Styles (v2.1.72+)

CC 的 Output Styles 功能允许自定义系统提示词本身。
与 CLAUDE.md（作为用户消息添加）和 Skills（特定任务用）是不同的层。

Harness 提供 `.claude/output-styles/harness-ops.md`:
- `keep-coding-instructions: true` — 在保持编码指令的同时优化运营流程
- 结构化的进度报告格式（实施/当前位置/下一步行动）
- Quality Gate 的表格形式输出
- Review 判定的结构化格式
- 升级（3 次规则）的标准输出形式

```bash
# 有効化
/output-style harness-ops
```

### `permissionMode` in agent frontmatter (v2.1.72+)

官方文档已将 `permissionMode` 作为代理 frontmatter 的正式字段进行文档化。

Harness 中的反映:
- Worker/Reviewer/Scaffolder 三个代理全部添加 `permissionMode: bypassPermissions`
- 实现不依赖 spawn 时 `mode` 指定的声明式权限管理
- Auto Mode 作为 rollout 候选整理，当前 shipped default 维持 `bypassPermissions`

```yaml
# agents-v3/worker.md frontmatter
permissionMode: bypassPermissions  # 添加
```

### Agent Teams 官方最佳实践 (v2.1.72+)

Claude Code 官方已将 `agent-teams.md` 作为独立文档进行完善。
Harness 的 `agents-v3/team-composition.md` 反映了以下内容:

1. **任务粒度指南**: 5-6 tasks/teammate 的推荐值
2. **`teammateMode` 设置**: `"auto"` / `"in-process"` / `"tmux"` 的官方支持
3. **Plan Approval 模式**: 要求 Worker 进入 plan mode 的官方模式
4. **Quality Gate Hooks**: `TeammateIdle`/`TaskCompleted` 的 exit 2 反馈模式
5. **团队规模**: 3-5 teammates 的推荐值（与 Harness 的 Worker 1-3 + Reviewer 1 一致）

### Sandboxing (`/sandbox`)

Claude Code 原生集成的 OS 级沙盒功能。macOS 使用 Seatbelt，Linux 使用 bubblewrap，限制 Bash 命令的文件系统/网络访问。

**两种模式**:
- **Auto-allow mode**: 沙盒内的命令自动批准。超出约束的访问回退到常规权限流程
- **Regular permissions mode**: 即使在沙盒内，所有命令也需要批准

**Harness 中的使用策略**:
- 定位为 `bypassPermissions` 的 **补充层**（不是替代）
- 为 Worker 代理的 Bash 命令添加 OS 级安全边界
- 通过 `sandbox.filesystem.allowWrite` 明确限制 Worker 可写入的范围
- 通过 `sandbox.network` 将外部访问限制在可信域名（防止数据外泄）

**分阶段导入计划**:

| 阶段 | Worker 权限 | Sandbox |
|---------|-----------|---------|
| 现行 | `bypassPermissions` + hooks 守护 | 未应用 |
| 验证阶段 | `bypassPermissions` + hooks + sandbox auto-allow | 应用于 Worker 的 Bash |
| 稳定后 | 仅 sandbox auto-allow（考虑废弃 `bypassPermissions`） | 应用于所有 Bash |

```json
// settings.json (验证阶段用)
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": ["~/.claude", "//tmp"]
    }
  }
}
```

> `@anthropic-ai/sandbox-runtime` 已作为 OSS 公开，也可用于 MCP 服务器的沙盒化。

### `opusplan` 模型别名

Plan mode 使用 Opus，执行模式使用 Sonnet 的自动切换混合别名。

**Harness 中的使用**:
- Breezing 的 Lead 会话最适合: Plan 阶段（任务分解/架构决定）使用 Opus 的推理能力，Worker spawn 后的执行协调使用 Sonnet 提高成本效率
- 通过 `claude --model opusplan` 或 `/model opusplan` 启用

**通过环境变量控制**:
```bash
# 自定义 opusplan 的内部映射
ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-6    # Plan 时
ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-4-6  # 执行时
```

### `CLAUDE_CODE_SUBAGENT_MODEL` 环境变量

批量指定子代理（Worker/Reviewer）模型的环境变量。

**Harness 中的使用**:
- 现状: Worker/Reviewer 在代理定义中固定为 `model: sonnet`
- 使用此环境变量，可以在不更改代理定义的情况下切换模型
- 对 CI 环境中的成本控制（`CLAUDE_CODE_SUBAGENT_MODEL=haiku` 执行测试）很有用

```bash
# 使用 haiku 执行所有子代理（降低 CI 成本）
export CLAUDE_CODE_SUBAGENT_MODEL=claude-haiku-4-5-20251001
```

### `availableModels` 设置

限制用户可选择的模型的设置。在 managed/policy settings 中设置时，`/model`、`--model`、`ANTHROPIC_MODEL` 都会受到限制。

**Harness 中的使用**:
- 企业环境中的模型治理: 防止 Worker/Reviewer 使用非预期的模型
- 通过 `availableModels` + `model` 的组合可以统管所有用户的模型体验

```json
// managed settings
{
  "model": "sonnet",
  "availableModels": ["sonnet", "haiku", "opusplan"]
}
```

### Checkpointing (`/rewind`)

自动跟踪会话中的文件编辑，并可回滚到任意点的功能。
每个用户提示都会自动创建检查点。

**操作方法**:
- `Esc + Esc` 或 `/rewind` 打开回滚菜单
- 选项: 恢复代码 / 恢复对话 / 两者都恢复 / 从此处开始摘要

**Harness 中的使用**:
- `harness-work` 的自我审查阶段发现问题时，回滚到实现前的状态
- 通过"从此处开始摘要"回收冗长调试会话的上下文窗口
- 与 `/compact` 的区别: 检查点可以选择性地指定压缩范围

**限制事项**:
- Bash 命令造成的文件变更不会被跟踪（`rm`, `mv`, `cp` 等）
- 外部手动变更不会被跟踪
- 不是 Git 的替代品，而是会话级别的"本地 Undo"

### Code Review (托管服务)

在 Anthropic 基础设施上运行的多代理 PR 审查服务。Teams/Enterprise 版 Research Preview。

**运行概要**:
1. PR 创建/更新时自动启动
2. 多个专业代理并行分析差异和代码库
3. 在验证步骤过滤假阳性
4. 去重和重要性排序后作为内联评论发布

**重要性级别**:
| 标记 | 级别 | 含义 |
|---------|--------|------|
| 🔴 | Normal | 合并前应修复的 bug |
| 🟡 | Nit | 轻微问题（不阻塞） |
| 🟣 | Pre-existing | 此 PR 之前就存在的 bug |

**`REVIEW.md`**: 放置在仓库根目录的审查专用指导文件。与 `CLAUDE.md` 分开，定义仅在审查时适用的规则。

**Harness 中的使用**:
- 作为 `harness-review` 技能的 Code Review 支持，考虑生成 `REVIEW.md` 模板
- Harness 的 Worker 自我审查和托管 Code Review 是互补的（本地 + 远程双重检查）
- 平均成本 $15-25/审查。注意 `on-push` 触发器会产生与 push 次数相当的成本

### Status Line (`/statusline`)

在 Claude Code 终端底部显示的可自定义状态栏。将 JSON 会话数据传递给 shell 脚本，显示输出文本。

**可用数据**:
- `model.id`, `model.display_name` — 当前模型
- `context_window.used_percentage` — 上下文使用率
- `cost.total_cost_usd` — 会话成本
- `cost.total_duration_ms` — 经过时间
- `worktree.*` — 工作树信息
- `agent.name` — 代理名称
- `output_style.name` — 输出样式名称

**Harness 中的使用**:
- 通过 `scripts/statusline-harness.sh` 提供 Harness 专用状态栏
- 常时显示模型名称、上下文使用率、会话成本、git 分支、Harness 版本
- 使用 ANSI 颜色显示上下文使用率的阈值（70% 黄色，90% 红色）

### 1M Context Window (`sonnet[1m]`)

Opus 4.6 和 Sonnet 4.6 可用的 100 万 token 上下文窗口。超过 200K token 时应用 long-context pricing。

**Harness 中的使用**:
- 对 `harness-review` 的大规模代码库分析很有用
- `breezing` 中同时处理大量文件的会话
- 通过 `/model sonnet[1m]` 启用。可通过 `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` 禁用

### Per-model Prompt Caching Control

按模型控制 prompt cache 的环境变量群。

| 环境变量 | 用途 |
|---------|------|
| `DISABLE_PROMPT_CACHING` | 禁用所有模型的缓存 |
| `DISABLE_PROMPT_CACHING_HAIKU` | 仅禁用 Haiku |
| `DISABLE_PROMPT_CACHING_SONNET` | 仅禁用 Sonnet |
| `DISABLE_PROMPT_CACHING_OPUS` | 仅禁用 Opus |

**Harness 中的使用**:
- 调试时禁用特定模型的缓存以确认行为
- 云提供商（Bedrock/Vertex）的缓存实现不同时进行选择性控制

### `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`

禁用 Opus 4.6 / Sonnet 4.6 的 Adaptive Reasoning，恢复到由 `MAX_THINKING_TOKENS` 控制的固定 thinking budget 的环境变量。

**Harness 中的使用**:
- 对需要 token 成本可预测性的 CI 环境很有用
- 与 `harness-work` 的 effort 评分不互斥（两者可同时使用，但通常保持 adaptive thinking 启用并通过 ultrathink 控制更有效）

### Chrome Integration (`--chrome`)

与 Claude Code 的 Chrome 扩展协作，从终端执行浏览器自动化的 beta 功能。
使用 `--chrome` 标志启动会话，或在会话内通过 `/chrome` 启用。

**主要功能**:
- 实时调试: 读取控制台错误，立即修正问题代码
- UI 测试: 表单验证、视觉回归确认、用户流程验证
- 数据提取: 从 Web 页面提取结构化数据并本地保存
- GIF 录制: 将浏览器操作序列录制为 GIF

**Harness 中的使用**:
- `harness-work` 中 UI 组件实现后的自动验证
- `harness-review` 中 Web 应用程序的视觉审查
- 启用 `/chrome` 让 Worker 可以执行浏览器测试

**限制**: 仅支持 Google Chrome / Microsoft Edge。不支持 Brave, Arc 等。不支持 WSL。

### LSP 服务器集成 (`.lsp.json`)

通过 Plugin 集成 Language Server Protocol 服务器，提供实时代码诊断。

**可用的 LSP 插件**:
| 插件 | Language Server | 安装 |
|-----------|----------------|------------|
| `pyright-lsp` | Pyright (Python) | `pip install pyright` |
| `typescript-lsp` | TypeScript Language Server | `npm install -g typescript-language-server typescript` |
| `rust-lsp` | rust-analyzer | 参考 rust-analyzer 官方指南 |

**提供的功能**:
- 即时诊断: 编辑后立即显示错误/警告
- 代码导航: 跳转到定义、引用搜索、悬停信息
- 类型信息: 显示符号的类型和文档

**设置示例** (`.lsp.json`):
```json
{
  "typescript": {
    "command": "typescript-language-server",
    "args": ["--stdio"],
    "extensionToLanguage": {
      ".ts": "typescript",
      ".tsx": "typescriptreact"
    }
  }
}
```

### `SubagentStart`/`SubagentStop` matcher

在 settings.json 级别按 agent type 监视子代理生命周期的钩子。
官方文档已记录在 matcher 中指定代理名称的模式。

**Harness 的实现**:
- `SubagentStart`: 分别跟踪 Worker/Reviewer/Scaffolder/Video Generator 的启动
- `SubagentStop`: 分别记录各代理的完成
- 为现有的 `subagent-tracker` Node.js 脚本添加 matcher

```json
"SubagentStart": [
  { "matcher": "worker", "hooks": [{ "type": "command", "command": "...subagent-tracker start" }] },
  { "matcher": "reviewer", "hooks": [{ "type": "command", "command": "...subagent-tracker start" }] }
]
```

### Agent Teams: Task Dependencies

可以为 Agent Teams 的任务设置依赖关系。依赖任务完成后，被阻塞的任务自动解除阻塞。

**行为**:
- 任务有 `pending`, `in_progress`, `completed` 三种状态
- 有未解决依赖的 pending 任务不可被 claim
- 依赖完成时自动解除阻塞（无需手动干预）
- 使用文件锁防止多个 teammate 同时 claim

**Harness 中的使用**:
- Breezing 的 Lead 在任务分解时明确指定依赖关系
- 例: "API 端点实现" → "测试创建" → "文档更新" 的顺序保证

### `--teammate-mode` CLI 标志

按会话指定 Agent Teams 显示模式的标志。

```bash
claude --teammate-mode in-process  # 所有 teammate 在同一终端
claude --teammate-mode tmux        # 每个 teammate 有独立窗格
```

覆盖 settings.json 的 `teammateMode` 设置。VS Code 集成终端推荐使用 `in-process`。

### `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`

设置为 `=1` 时禁用所有后台任务功能的环境变量。

**Harness 中的使用**:
- 适用于安全策略限制后台执行的环境
- Breezing 的后台 Worker spawn 也会被禁用，使用时需注意

### `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`

调整子代理 auto-compaction 阈值的环境变量（默认 95%）。

**Harness 中的使用**:
- 设置为 `50` 启用早期压缩。提高长时间运行的 Worker 的稳定性
- 防止 Breezing 的 Worker 读取大量文件时上下文溢出

### `cleanupPeriodDays` 设置

控制子代理 transcript 自动清理周期的设置（默认 30 天）。
transcript 保存在 `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`。

### `/btw` 旁支问题

在保持当前上下文的情况下进行简短提问的命令。
回答后不会留在主对话历史中，因此不消耗上下文窗口。

**与子代理的使用区分**:
- `/btw`: 在当前上下文中可立即回答的问题（无工具访问）
- 子代理: 独立的调查/实现任务（有工具访问）

### Plugin CLI 命令群

插件的非交互式管理命令。支持脚本自动化。

```bash
claude plugin install <plugin> [--scope user|project|local]
claude plugin uninstall <plugin> [--scope user|project|local]
claude plugin enable <plugin> [--scope user|project|local]
claude plugin disable <plugin> [--scope user|project|local]
claude plugin update <plugin> [--scope user|project|local|managed]
```

### Remote Control 增强

通过 `/remote-control` (`/rc`) 可在会话内启用 Remote Control。

**新功能**:
- `--name "My Project"`: 指定会话名称
- `--sandbox` / `--no-sandbox`: 启用/禁用沙盒
- `--verbose`: 显示详细日志
- `/mobile`: 显示 QR 码，快速连接 iOS/Android 应用
- 自动重连: 从网络断开自动恢复（10 分钟以内）
- `/config` → "Enable Remote Control for all sessions" 可常时启用

### `skills` 字段 in agent frontmatter

在子代理的 frontmatter 中添加 `skills` 字段，启动时预加载技能的全部内容。
父会话的技能不会被继承，因此需要明确列出。

**Harness 的实现状况**:
- Worker: `skills: [harness-work, harness-review]` — 预加载实现和自我审查的技能
- Reviewer: `skills: [harness-review]` — 预加载审查技能
- Scaffolder: `skills: [harness-setup, harness-plan]` — 预加载设置和计划技能

> 与 skill 的 `skills` (`context: fork`) 相反的模式。不是 skill 控制 agent，而是 agent 加载 skill。

### `modelOverrides` 设置 (v2.1.73)

CC 2.1.73 添加的设置。可以将模型选择器（`/model` 菜单）的条目映射到自定义提供商的模型 ID。
可以指定 Bedrock ARN 或 Vertex AI 的模型 ID 等提供商特定的标识符。

**Harness 中的使用**:
- 在企业环境中通过 Bedrock/Vertex 使用 Anthropic 模型时，通过 `modelOverrides` 将模型选择器的显示名称与实际提供商模型 ID 对应
- Worker/Reviewer 的 `model: sonnet` 自动解析为提供商特定的 ARN
- 与 `availableModels` 结合使用，可以统管整个团队的模型体验

```json
// settings.json
{
  "modelOverrides": {
    "sonnet": "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-6-20250514-v1:0",
    "opus": "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-opus-4-6-20250610-v1:0"
  }
}
```

### `/output-style` 废弃化 (v2.1.73)

CC 2.1.73 中 `/output-style` 命令已废弃，输出样式的选择已整合到 `/config` 菜单。
现有的 `/output-style harness-ops` 等仍可继续使用，但官方推荐通过 `/config` 进行选择。

**对 Harness 的影响**:
- 推荐将文档中对 `/output-style harness-ops` 的引用更新为 `/config` 方式
- `.claude/output-styles/harness-ops.md` 本身仍然有效（配置文件位置无变化）
- 如果技能内有执行 `/output-style` 的地方，考虑切换到 `/config`

### Bedrock/Vertex Opus 4.6 默认化 (v2.1.73)

CC 2.1.73 中云提供商（Amazon Bedrock / Google Vertex AI）上的默认 Opus 模型从 4.1 更新到 4.6。
first-party API 在 v2.1.68 时已将 Opus 4.6 设为默认，现在云提供商也统一了。

**对 Harness 的影响**:
- Bedrock/Vertex 环境中 Lead（使用 Opus 时）也以 medium effort 默认运行
- `opusplan` 别名在 Bedrock/Vertex 环境中也引用 Opus 4.6
- 通过 `ANTHROPIC_DEFAULT_OPUS_MODEL` 环境变量覆盖仍然有效

### `autoMemoryDirectory` 设置 (v2.1.74)

CC 2.1.74 添加的设置。可以自定义自动内存（auto-memory）的保存目录。
可以从默认的 `~/.claude/` 下更改为项目特定路径。

**Harness 中的使用**:
- 在多个项目中使用 Harness 时，按项目隔离自动内存
- 在 CI 环境中将内存保存到临时目录，会话结束时清理
- 与 Agent Memory（`memory: project`）是不同层级（自动内存是用户级别的学习）

```json
// settings.json (项目级别)
{
  "autoMemoryDirectory": ".claude/auto-memory"
}
```

### `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (v2.1.74)

CC 2.1.74 添加的环境变量。可以以毫秒为单位指定 `SessionEnd` 钩子的超时时间。
以前固定 1.5 秒就会被 kill，导致重的清理处理在完成前被中断的问题。

**Harness 中的使用**:
- 在 `SessionEnd` 钩子中执行 `harness-mem` 的会话记录或 JSONL 轮转时，确保足够的超时时间
- 推荐值: `5000`（5秒）。需要复杂清理时可到 `10000`（10秒）

```bash
export CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS=5000
```

### Full model ID 修复 (v2.1.74)

CC 2.1.74 中 `claude-opus-4-6`、`claude-sonnet-4-6` 等完整模型 ID（连字符分隔格式）在代理 frontmatter 和 JSON config 中可被正确识别。
以前只有别名（`opus`, `sonnet`）能稳定工作。

**对 Harness 的影响**:
- 代理定义的 `model` 字段可以指定完整模型 ID（例: `model: claude-sonnet-4-6`）
- `--agents` CLI 标志的 JSON 中也可以使用完整模型 ID
- 当前 Harness 使用别名（`sonnet`, `opus`），无即时影响。在 Bedrock/Vertex 环境中需要指定完整 ID 时有用

```yaml
# agents-v3/worker.md frontmatter（完整模型 ID 使用示例）
model: claude-sonnet-4-6
```

### Streaming API 内存泄漏修复 (v2.1.74)

CC 2.1.74 修复了流式 API 响应缓冲区无限制 RSS（Resident Set Size）增长的问题。
长时间流式会话中 Node.js 进程内存使用量无限增长的问题已解决。

**对 Harness 的影响**:
- `breezing` 的长时间团队会话稳定性提高
- `harness-work` 中包含大量文件读写的长时间 Worker 会话的内存消耗稳定化
- 继 v2.1.50~v2.1.63 的内存泄漏修复系列（LSP 诊断、工具输出、文件历史等）之后的追加修复
- 与 Harness 侧的 JSONL 轮转对策（独立的内存管理）结合，双重确保稳定性

### `--remote` / Cloud Sessions

通过 CC 的 `--remote` 标志可从终端启动云会话。任务在 Anthropic 管理的隔离 VM 上执行，完成后可创建 PR。

**Harness 中的使用**:
- 将 `breezing` 的大规模任务委托给云端，节省本地资源
- 通过 `--remote` 并行启动多个任务（每个任务是独立的云会话）
- 通过 `/teleport` 将云端成果物导入本地，连接后续的 `/harness-review`

```bash
# 在云端执行任务
claude --remote "Fix the authentication bug in src/auth/login.ts"

# 完成后导入本地
/teleport
```

### `/teleport` (`/tp`)

将云会话导入本地终端的命令。通过 `/teleport` 或 `/tp` 交互式选择会话，也可通过 `claude --teleport <session-id>` 直接指定。

**前提条件**:
- 本地 git working directory 必须是干净的
- 必须从同一仓库执行
- 必须使用同一 Claude.ai 账户认证

### `CLAUDE_CODE_REMOTE` 环境变量

在云会话中 `CLAUDE_CODE_REMOTE=true` 会被设置。Harness 的 `session-env-setup.sh` 将此值持久化为 `HARNESS_IS_REMOTE`，其他钩子处理器可用于判断是否跳过本地专用处理。

```bash
# 钩子脚本中的云端检测示例
if [ "$HARNESS_IS_REMOTE" = "true" ]; then
  # 在云端环境跳过本地专用处理
  exit 0
fi
```

### `CLAUDE_ENV_FILE` SessionStart 持久化

CC 的 `SessionStart` 钩子通过向 `CLAUDE_ENV_FILE` 环境变量指向的文件写入 `KEY=VALUE`，可以将环境变量持久化到后续的 Bash 命令。

Harness 的 `session-env-setup.sh` 利用此机制，使 `HARNESS_VERSION`、`HARNESS_AGENT_TYPE`、`HARNESS_IS_REMOTE` 等在整个会话中可用。

### Slack Integration (`@Claude`)

在 Slack 频道中向 `@Claude` 提及编码任务，会自动创建云会话。需要与 GitHub 仓库集成。

**与 Harness 的关系**:
- 将 Harness 的 HTTP hooks（`type: "http"`）设置为 Slack Webhook URL，可以在任务完成时发送 Slack 通知
- 云会话中 `.claude/settings.json` 的钩子也会运行，因此 Harness 的护栏也适用于 Slack 经由的任务

### Server-managed settings (public beta)

从 Claude.ai 管理画面向团队全体服务器分发 Claude Code 设置的功能。Teams/Enterprise 版。

**Harness 中的使用**:
- 批量管理团队全体的 `permissions.deny` 规则
- 通过服务器分发 Harness 的钩子设置（但钩子设置会显示安全确认对话框）
- 通过 `availableModels` + `model` 的组合统管团队的模型体验

### Microsoft Foundry

基于 Azure 的新云提供商。作为继 Bedrock / Vertex 之后的第三家第三方提供商添加。
可以通过 `modelOverrides` 设置映射到 Foundry 的模型 ID。

### `PreCompact` hook

在上下文压缩执行前直接触发的钩子事件。Harness 已在以下两层实现:

1. **`pre-compact-save.js`**: 持久化会话状态（进度、指标）
2. **agent hook**: 检查是否有 `cc:WIP` 任务残留，注入警告消息

```json
"PreCompact": [
  { "hooks": [
    { "type": "command", "command": "...pre-compact-save.js" },
    { "type": "agent", "prompt": "Check Plans.md for WIP tasks...", "model": "haiku" }
  ]}
]
```

### `Notification` hook event

Claude Code 发出通知时触发的钩子事件。记录在插件参考中。
可用于向外部监控工具或仪表板转发通知。

### `--plugin-dir` 规范变更 (v2.1.76, breaking)

**变更内容**: `--plugin-dir` 更改为只接受一个路径。多个目录需重复指定。

```bash
# 旧（不再支持）
claude --plugin-dir path1,path2

# 新
claude --plugin-dir path1 --plugin-dir path2
```

**对 Harness 的影响**: 仅使用 Harness 插件的常见配置无影响。
只有同时使用多个插件时需要更改语法。

---

## Claude Code 2.1.76 新功能

### MCP Elicitation 支持

**运行概要**: MCP 服务器在任务执行中可向用户请求结构化输入的协议。通过表单字段或浏览器 URL 显示交互式对话框。

**Harness 中的使用**:
- Breezing 的后台 Worker/Reviewer 无法进行 UI 对话，因此通过 `Elicitation` 钩子实现自动跳过
- 常规会话中直接通过（用户通过对话响应）
- `elicitation-handler.sh` 记录事件日志

**限制事项**:
- 后台代理无法响应 elicitation（必须通过钩子自动处理）
- MCP 服务器端需要支持 elicitation

### `Elicitation`/`ElicitationResult` 钩子

**运行概要**: MCP Elicitation 前后可拦截的两个新钩子事件。`Elicitation` 在响应返回给 MCP 服务器前触发，`ElicitationResult` 在返回后触发。

**Harness 中的使用**:
- `Elicitation`: Breezing 会话中的自动跳过判定 + 日志记录
- `ElicitationResult`: 结果的日志记录（`.claude/state/elicitation-events.jsonl`）
- 在 hooks.json 中注册两个事件的处理程序

**限制事项**:
- 在 `Elicitation` 钩子中阻止（deny）会导致输入无法到达 MCP 服务器
- 推荐 timeout: Elicitation 10s / ElicitationResult 5s

### `PostCompact` 钩子

**运行概要**: 上下文压缩完成后触发的新钩子事件。与 `PreCompact` 钩子（现有）成对。

**Harness 中的使用**:
- 压缩后的上下文再注入（WIP 任务状态恢复）
- 在 `.claude/state/compaction-events.jsonl` 记录事件
- 提高长时间会话的状态连续性
- PreCompact（状态保存）→ PostCompact（状态恢复）的对称结构

**限制事项**:
- 推荐 timeout: 15s
- 压缩失败时（circuit breaker 触发时）PostCompact 可能不会触发

### `-n`/`--name` CLI 标志

**运行概要**: 会话启动时设置显示名称的 CLI 标志。如 `claude -n "auth-refactor"` 使用，用于会话列表中的识别。

**Harness 中的使用**:
- 为 Breezing 会话自动设置 `breezing-{timestamp}` 格式的名称
- 用于会话列表的过滤和跟踪
- 便于日志分析时的会话定位

**代码示例**:
```bash
claude -n "breezing-$(date +%Y%m%d-%H%M%S)"
```

### `worktree.sparsePaths` 设置

**运行概要**: 在大型单体仓库中使用 `claude --worktree` 时，通过 git sparse-checkout 仅检出必要目录的设置。大幅改善工作树创建性能。

**Harness 中的使用**:
- 缩短 Breezing 的并行 Worker 启动时间（大型仓库）
- 在 `.claude/settings.json` 中设置:
```json
{
  "worktree": {
    "sparsePaths": ["src/", "tests/", "package.json"]
  }
}
```

**限制事项**:
- 未 sparse-checkout 的路径的文件 Worker 无法访问
- 有依赖关系的目录都必须包含在 sparsePaths 中

### `/effort` 斜杠命令

**运行概要**: 在会话中切换 effort 级别（low/medium/high）的斜杠命令。`/effort auto` 重置为默认。

**Harness 中的使用**:
- 与 harness-work 的多因素评分联动，可以按任务复杂度控制 effort
- 复杂任务可手动设置 `/effort high`（启用 ultrathink）
- 简单任务可通过 `/effort low` 抑制 token 消耗

### `--worktree` 启动加速

**运行概要**: 通过直接读取 git refs，以及在远程分支可用时跳过冗余的 `git fetch`，缩短 `--worktree` 的启动时间。

**Harness 中的使用**:
- 自动减少 Breezing 的 Worker 启动开销
- 特别是在同时启动多个 Worker 时效果显著

### 后台代理部分结果保留

**运行概要**: 即使后台代理被 kill，部分结果也会保存到会话上下文中。

**Harness 中的使用**:
- Breezing 的 Worker 因超时或手动停止中断时，工作的部分内容会传达给 Lead
- 可以利用 Worker 的中间成果物进行重新分配
- 减少"重做"的浪费

### stale worktree 自动清理

**运行概要**: 被中断的并行执行中残留的 stale 工作树会被自动清理。

**Harness 中的使用**:
- 补充 `worktree-remove.sh` 的手动清理
- Breezing 会话崩溃后也能自动恢复
- 防止磁盘空间的浪费

### 自动压缩 circuit breaker

**运行概要**: 自动压缩连续失败时，引入了 3 次后停止的熔断器。防止无限重试造成的 token 浪费。

**Harness 中的使用**:
- 与 Harness 的"3 次规则"（CI 失败时的 3 次限制）一致的设计思想
- 防止长时间 Breezing 会话中意外的成本增加
- circuit breaker 触发时与 PostToolUseFailure 钩子联动进行升级

### Deferred Tools schema 修复

**运行概要**: 修复了通过 `ToolSearch` 加载的工具在压缩后丢失输入 schema，导致数组/数值参数因类型错误被拒绝的问题。

**Harness 中的使用**:
- 提高长时间会话中 ToolSearch 经由工具的稳定性
- Breezing 压缩后 MCP 工具也能正常运行

### `/context` 命令 (v2.1.74)

**运行概要**: 分析上下文窗口的消费情况，确定占用上下文的工具和内存。显示可操作的优化建议（断开不需要的 MCP 服务器、整理膨胀的内存等）。

**Harness 中的使用**:
- 确定"Breezing 长时间会话中压缩为何频繁发生"的原因
- 在连接了大量 hooks 和 MCP 服务器的环境中优化上下文
- 会话中只需执行 `/context` 即可立即获得分析结果

**限制事项**:
- 仅在会话中可用（不支持批处理模式）
- 子代理中不可用

### `maxTurns` 代理安全限制

**运行概要**: 限制子代理最大轮次数的 frontmatter 字段。达到设置轮次数后，代理会自动停止并返回结果。CC 官方文档推荐的安全机制。

**Harness 中的使用**:
- Worker: `maxTurns: 100` — 面向复杂实现任务。保持足够余量同时防止失控
- Reviewer: `maxTurns: 50` — 专注于 Read-only 分析。50 轮未完成则有问题
- Scaffolder: `maxTurns: 75` — 脚手架构建和状态更新的中等复杂度

**设计判断**:
- 达到上限时，Lead 可回收中间结果并做出判断
- 与 `bypassPermissions` 结合，作为失控时的安全阀

### `Notification` 钩子实现

**运行概要**: Claude Code 发出通知时触发的钩子事件。拦截 `permission_prompt`（权限确认）、`idle_prompt`（空闲通知）、`auth_success`（认证成功）等事件。

**Harness 中的使用**:
- 通过 `notification-handler.sh` 将所有通知事件记录到 `.claude/state/notification-events.jsonl`
- 追踪 Breezing 后台 Worker 中发生的 `permission_prompt`（用于事后分析）
- hooks-editing.md 从 v3.10.3 开始已文档化，但此次完成了 hooks.json 的实现

**日志格式**:
```json
{"event":"notification","notification_type":"permission_prompt","session_id":"...","agent_type":"worker","timestamp":"2026-03-15T..."}
```

### Output token limits 64k/128k (v2.1.77)

CC 2.1.77 中 Opus 4.6 和 Sonnet 4.6 的默认最大输出 token 提升到 64k，上限扩展到 128k token。

**对 Harness 的影响**:
- 长实现代码和大规模重构的输出更不容易被截断
- Worker 代理一次性输出大量文件变更时的可靠性提高
- 128k 输出会导致成本增加，需要注意成本管理

### `allowRead` sandbox 设置 (v2.1.77)

在通过 `sandbox.filesystem.denyRead` 阻止大范围的同时，可以通过 `allowRead` 重新允许特定路径的读取。

**Harness 中的使用**:
- 在 Reviewer 代理的沙盒中对 `/etc/` 进行 denyRead，同时仅对特定配置文件进行 allowRead
- 安全审查时提供敏感目录的受限读取访问

### PreToolUse `allow` 尊重 `deny` (v2.1.77)

CC 2.1.77 中即使 PreToolUse 钩子返回 `"allow"`，settings.json 的 `deny` 权限规则仍会继续应用。以前钩子的 `allow` 会覆盖全局 `deny`。

**对 Harness 的影响**:
- guardrails 的安全模型得到加强
- 在 settings.json 中设置 `deny: ["mcp__codex__*"]`，无论 PreToolUse 钩子的判断如何都能确保阻止
- 除了 `.claude/rules/codex-cli-only.md` 的基于钩子的 MCP 阻止外，settings.json deny 成为推荐模式

### Agent `resume` → `SendMessage` (v2.1.77)

CC 2.1.77 中 Agent tool 的 `resume` 参数已废弃。要恢复停止中的代理，需使用 `SendMessage({to: agentId})`。`SendMessage` 会自动在后台恢复停止中的代理。

**对 Harness 的影响**:
- `breezing` 技能的 Lead 与 Worker/Reviewer 通信时使用 `SendMessage`
- `team-composition.md` 的 Lead Phase B 中 `SendMessage` 作为正式通信手段记录

### `/branch` (原 `/fork`) (v2.1.77)

CC 2.1.77 中 `/fork` 命令重命名为 `/branch`。`/fork` 作为别名继续有效。

### `claude plugin validate` 增强 (v2.1.77)

CC 2.1.77 中 `claude plugin validate` 开始验证技能/代理/命令的 YAML frontmatter 和 hooks.json 的语法。

**Harness 中的使用**:
- 在 CI 管道中添加 `claude plugin validate`，早期发现 frontmatter 错误
- 可作为 `tests/validate-plugin.sh` 的补充使用

### `StopFailure` hook event (v2.1.78)

CC 2.1.78 中添加了 `StopFailure` 事件。当 API 错误（速率限制 429、认证失败 401 等）导致会话停止失败时触发。

**Harness 中的使用**:
- 通过 `stop-failure.sh` 处理程序将错误信息记录到 `.claude/state/stop-failures.jsonl`
- 用于 Breezing 的 Worker 因速率限制停止失败时的事后分析
- 作为 10 秒超时的轻量处理程序实现（无需恢复处理）

### `${CLAUDE_PLUGIN_DATA}` 变量 (v2.1.78)

CC 2.1.78 中添加了 `${CLAUDE_PLUGIN_DATA}` 目录变量。可用作插件更新后仍持久的状态存储。

**Harness 中的使用余地**:
- 当前使用 `${CLAUDE_PLUGIN_ROOT}/.claude/state/`，但插件更新时可能消失
- 长期考虑将指标、通知日志等持久数据迁移到 `${CLAUDE_PLUGIN_DATA}`
- 迁移模式: `STATE_DIR="${CLAUDE_PLUGIN_DATA:-${CLAUDE_PLUGIN_ROOT}/.claude/state}"`

### Agent frontmatter: `effort`/`maxTurns`/`disallowedTools` (v2.1.78)

CC 2.1.78 中插件代理定义的 frontmatter 正式支持 `effort`, `maxTurns`, `disallowedTools`。

**Harness 中的现状**:
- `maxTurns`: v3.10.4 已实现（Worker: 100, Reviewer: 50, Scaffolder: 75）
- `disallowedTools`: Worker 为 `[Agent]`，Reviewer 为 `[Write, Edit, Bash, Agent]` 已实现
- `effort`: 未使用。可在 Worker/Reviewer 定义中添加 `effort` 字段，声明式控制默认 thinking 级别

### `deny: ["mcp__*"]` 修复 (v2.1.78)

CC 2.1.78 中修复了 settings.json 的 `deny` 权限规则对 MCP 服务器工具正确生效的问题。

**Harness 中的使用**:
- 可将 `.claude/rules/codex-cli-only.md` 推荐的 Codex MCP 阻止从基于钩子的方式迁移到 settings.json `deny`
- `"permissions": { "deny": ["mcp__codex__*"] }` 是更干净的模式

### `--console` auth 标志 (v2.1.79)

CC 2.1.79 中添加了 `claude auth login --console` 标志，支持 Anthropic Console API 计费认证。

### SessionEnd hooks `/resume` 修复 (v2.1.79)

CC 2.1.79 中交互式 `/resume` 会话切换时 `SessionEnd` 钩子可正常触发。以前会话切换时 SessionEnd 不会触发，导致清理处理未执行的情况。

## 相关文档

- [CLAUDE.md](../CLAUDE.md) - 开发指南（Feature Table 摘要版）
- [CLAUDE-skill-catalog.md](./CLAUDE-skill-catalog.md) - 技能目录
- [CLAUDE-commands.md](./CLAUDE-commands.md) - 命令参考
- [ARCHITECTURE.md](./ARCHITECTURE.md) - 架构概要
