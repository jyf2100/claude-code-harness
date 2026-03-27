<!-- Generated from CLAUDE.md by build-opencode.js -->
<!-- opencode.ai compatible version of Claude Code Harness -->

# AGENTS.md - Claude Harness 开发指南

此文件为 Claude Code 在本仓库中工作时提供指导。

## 项目概述

**Claude Harness** 是一个用于以"计划 → 执行 → 审查"模式自主运行 Claude Code 的插件。

**特殊之处**: 本项目采用"使用 Harness 自身来改进 Harness"的自指式结构。

## Claude Code 2.1.49+ 新功能使用指南

Harness 充分利用了 Claude Code 2.1.49 的新功能。

| 功能 | 使用技能 | 用途 |
|------|-----------|------|
| **Task tool 指标** | parallel-workflows | 汇总子代理的 token/工具/时间 |
| **`/debug` 命令** | troubleshoot | 复杂会话问题的诊断 |
| **PDF 页面范围** | notebookLM, harness-review | 大型文档的高效处理 |
| **Git log 标志** | harness-review, CI, release-harness | 结构化提交分析 |
| **OAuth 认证** | codex-review | 不支持 DCR 的 MCP 服务器设置 |
| **68% 内存优化** | session-memory, session | 积极使用 `--resume` |
| **子代理 MCP** | task-worker | 并行执行时的 MCP 工具共享 |
| **Reduced Motion** | harness-ui | 无障碍设置 |
| **TeammateIdle/TaskCompleted Hook** | breezing | 团队监控自动化 |
| **Agent Memory (memory frontmatter)** | task-worker, code-reviewer | 持久化学习 |
| **Fast mode (Opus 4.6)** | 所有技能 | 高速输出模式 |
| **自动内存记录** | session-memory | 跨会话知识的自动持久化 |
| **技能预算缩放** | 所有技能 | 自动调整为上下文窗口的 2% |
| **Task(agent_type) 限制** | agents/ | 子代理种类限制 |
| **Plugin settings.json** | setup | 减少 init token、即时安全保护 |
| **Worktree isolation** | breezing, parallel-workflows | 同一文件并行写入安全化 |
| **Background agents** | generate-video | 异步场景生成 |
| **ConfigChange hook** | hooks | 配置更改审计 |
| **last_assistant_message** | session-memory | 会话质量评估 |
| **Sonnet 4.6 (1M context)** | 所有技能 | 大规模上下文处理 |

详情请参阅各技能的 SKILL.md。

## 开发规则

### 提交信息

遵循 [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - 新功能
- `fix:` - 错误修复
- `docs:` - 文档更改
- `refactor:` - 重构
- `test:` - 测试添加/更新
- `chore:` - 维护

### 版本管理

版本在两处定义（必须同步）:
- `VERSION` - 真实来源
- `.claude-plugin/plugin.json` - 插件系统用

普通的功能添加、docs 更新、CI 修正时不要修改这两个文件。
变更历史记录在 `CHANGELOG.md` 的 `[Unreleased]` 部分，仅在创建 release 时使用 `./scripts/sync-version.sh bump`。

### CHANGELOG 记录规则

详情: [.claude/rules/changelog.md](.claude/rules/changelog.md)

- 遵循 [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) 格式
- 部分: Added / Changed / Deprecated / Removed / Fixed / Security
- 重大更改时添加 Before/After 表格

### 语言设置

所有回复必须使用**中文**（包括 `context: fork` 技能）。

### 代码风格

- 使用清晰且描述性的名称
- 为复杂逻辑添加注释
- 保持命令/代理/技能单一职责

## 仓库结构

```
claude-code-harness/
├── .claude-plugin/     # 插件清单
├── commands/           # 斜杠命令（面向用户）
├── agents/             # 子代理定义（可通过 Task tool 并行启动）
├── skills/             # 代理技能
├── hooks/              # 生命周期钩子
├── scripts/            # Shell 脚本（防护、自动化）
├── templates/          # 模板文件
├── docs/               # 文档
└── tests/              # 验证脚本
```

## 技能使用（重要）

### 技能评估流程

> 💡 对于繁重任务（并行审查、CI 修正循环），技能会通过 Task tool 并行启动 `agents/` 中的子代理。

**开始工作前，务必执行以下流程:**

1. **评估**: 确认可用技能，评估是否有适用于本次请求的技能
2. **启动**: 如有相关技能，先用 Skill 工具启动后再开始工作
3. **执行**: 按照技能的步骤进行工作

```
用户的请求
    ↓
评估技能（是否有适用的？）
    ↓
YES → 使用 Skill 工具启动 → 遵循技能步骤
NO  → 使用常规推理处理
```

### 技能层次结构

技能采用 **父技能（类别）** 和 **子技能（具体功能）** 的层次结构。

```
skills/
├── impl/                  # 实现（功能添加、测试编写）
├── harness-review/        # 审查（质量、安全、性能）
├── verify/                # 验证（构建、错误恢复、修正应用）
├── setup/                 # 集成设置（项目初始化、工具配置、2-Agent、harness-mem、Codex CLI、规则本地化）
├── memory/                # 内存管理（SSOT、decisions.md、patterns.md、SSOT 提升、记忆搜索）
├── troubleshoot/          # 诊断·修复（包括错误、CI 故障）
├── principles/            # 原则·指南（VibeCoder、差异编辑）
├── auth/                  # 认证·支付（Clerk、Supabase、Stripe）
├── deploy/                # 部署（Vercel、Netlify、分析）
├── ui/                    # UI（组件、反馈）
├── handoff/               # 工作流（交接、自动修正）
├── notebookLM/            # 文档（NotebookLM、YAML）
└── maintenance/           # 维护（清理）
```

**使用方法:**
1. 使用 Skill 工具启动父技能
2. 父技能根据用户意图路由到适当的子技能（doc.md）
3. 按照子技能的步骤执行工作

### 开发用技能（非公开）

以下技能用于开发/实验，不包含在仓库中（通过 .gitignore 排除）：

```
skills/
├── test-*/      # 测试用技能
└── x-promo/     # X 发布创建技能（开发用）
```

这些技能仅在个人开发环境中使用，不应包含在插件分发中。

### 主要技能类别

| 类别 | 用途 | 触发示例 |
|---------|------|-----------|
| work | 任务实现（自动范围检测，--codex 支持） | "实现"、"全部做完"、"/work" |
| breezing | Agent Teams 完全自动完跑（--codex 支持） | "团队完跑"、"breezing" |
| impl | 实现、功能添加、测试编写 | "实现"、"功能添加"、"写代码" |
| harness-review | 代码审查、质量检查 | "审查"、"安全"、"性能" |
| verify | 构建验证、错误恢复 | "构建"、"错误恢复"、"验证" |
| setup | 设置集成中心（项目初始化、工具配置、2-Agent、harness-mem、Codex CLI、规则本地化） | "设置"、"CLAUDE.md"、"初始化"、"CI setup"、"2-Agent"、"Cursor 设置"、"harness-mem"、"codex-setup" |
| memory | SSOT 管理、记忆搜索、SSOT 提升、Cursor 联动内存 | "SSOT"、"decisions.md"、"合并"、"SSOT 提升"、"记忆搜索"、"harness-mem" |
| principles | 开发原则、指南 | "原则"、"VibeCoder"、"安全性" |
| auth | 认证、支付功能 | "登录"、"Clerk"、"Stripe"、"支付" |
| deploy | 部署、分析 | "部署"、"Vercel"、"GA" |
| ui | UI 组件生成 | "组件"、"hero"、"表单" |
| handoff | 交接、自动修正 | "交接"、"向 PM 报告"、"自动修正" |
| notebookLM | 文档生成 | "文档"、"NotebookLM"、"幻灯片" |
| troubleshoot | 诊断与修复（包括 CI 故障） | "不工作"、"错误"、"CI 失败了" |
| maintenance | 文件整理 | "整理"、"清理" |

## 开发流程

1. **计划**: 使用 `/plan-with-agent` 将任务写入 Plans.md
2. **实现**: `/work`（Claude 实现）或 `/breezing`（团队完跑）。两者都支持 `--codex`
3. **审查**: 自动执行（手动使用 `/harness-review`）
4. **验证**: 使用 `./tests/validate-plugin.sh` 进行结构验证

## 测试方法

```bash
# 插件结构验证
./tests/validate-plugin.sh
./scripts/ci/check-consistency.sh

# 在其他项目中本地测试
cd /path/to/test-project
claude --plugin-dir /path/to/claude-code-harness
```

## 注意事项

- **注意自指性**: 在此插件上运行 `/work` 会编辑自身的代码
- **Hooks 自动运行**: PreToolUse/PostToolUse 防护处于活动状态
- **VERSION 同步**: 普通 PR 中不要触碰 VERSION，仅在 release 时更新

## 主要命令（开发时使用）

| 命令 | 用途 |
|---------|------|
| `/plan-with-agent` | 将改进任务添加到 Plans.md |
| `/work` | 实现任务（自动范围检测，--codex 支持） |
| `/breezing` | Agent Teams 团队并行完跑（--codex 支持） |
| `/harness-review` | 审查变更内容 |
| `/validate` | 验证插件 |
| `/remember` | 记录学习内容 |

### 交接

| 命令 | 用途 |
|---------|------|
| `/handoff-to-cursor` | Cursor 运行时的完成报告 |

**技能（对话中自动启动）**:
- `handoff-to-impl` - "交给实现者" → PM → Impl 的请求
- `handoff-to-pm` - "向 PM 报告完成" → Impl → PM 的完成报告

## SSOT（Single Source of Truth）

- `.claude/memory/decisions.md` - 决策事项（Why）
- `.claude/memory/patterns.md` - 可复用模式（How）

## 测试篡改预防（质量保证）

详情: [D9: 测试篡改预防的3层防御策略](.claude/memory/decisions.md#d9-テスト改ざん防止の3層防御戦略)

| 规则文件 | 内容 |
|---------------|------|
| [test-quality.md](.claude/rules/test-quality.md) | 测试篡改禁止模式 |
| [implementation-quality.md](.claude/rules/implementation-quality.md) | 形骸化实现禁止模式 |

> ⚠️ **绝对禁止**: 篡改测试以伪造"成功"
