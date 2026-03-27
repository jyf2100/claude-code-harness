<!-- Generated from CLAUDE.md by build-opencode.js -->
<!-- codex compatible version of Claude Code Harness -->

# AGENTS.md - Codex Harness 开发指南

此文件为 Codex CLI 在本仓库中工作时提供指导。

## 项目概述

**Harness** 是一个用于以"计划 → 执行 → 审查"模式运行 Codex CLI 的指南。

**特殊之处**: 本项目采用"使用 Harness 自身来改进 Harness"的自指式结构。

## Codex CLI 前提条件

- Codex 会加载 `${CODEX_HOME:-~/.codex}/skills/<skill-name>/SKILL.md`（用户级）和 `.codex/skills/...`（项目覆盖），并通过 `$skill-name` 进行显式调用
- Codex 优先使用 `AGENTS.override.md`，然后是 `AGENTS.md`，必要时会参考配置的 fallback 名称
- 由于暂不支持 Hooks，临时防护通过 `.codex/rules/*.rules` 的 `prefix_rule()` 实现

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

版本的真实来源是 `VERSION` 文件。
普通的功能添加、docs 更新、CI 修正时不要修改 `VERSION` 和 `.claude-plugin/plugin.json`。
变更历史记录在 `CHANGELOG.md` 的 `[Unreleased]` 部分，仅在创建 release 时使用 `./scripts/sync-version.sh bump`。

### CHANGELOG 记录规则（必填）

**遵循 [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) 格式**

每个版本条目应使用以下部分:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- 关于新功能

### Changed
- 关于现有功能的更改

### Deprecated
- 即将删除的功能

### Removed
- 已删除的功能

### Fixed
- 关于错误修复

### Security
- 与漏洞相关的内容

#### Before/After（仅用于重大更改）

| Before | After |
|--------|-------|
| 更改前的状态 | 更改后的状态 |
```

**部分使用区分**:

| 部分 | 使用时机 |
|------------|----------|
| Added | 添加全新功能时 |
| Changed | 更改现有功能的行为或体验时 |
| Deprecated | 告知将来计划删除的功能时 |
| Removed | 删除功能或命令时 |
| Fixed | 修复错误或缺陷时 |
| Security | 进行安全相关修复时 |

**Before/After 表格**: 仅在有重大体验变化（命令废弃/整合、工作流更改、破坏性更改）时添加。轻微修正可省略。

**版本比较链接**: 在 CHANGELOG.md 末尾以 `[X.Y.Z]: https://github.com/.../compare/vPREV...vX.Y.Z` 格式添加

### 代码风格

- 使用清晰且描述性的名称
- 为复杂逻辑添加注释
- 保持命令/代理/技能单一职责

## 仓库结构

```
claude-code-harness/
├── codex/              # Codex CLI 分发物
├── commands/           # Claude Code 命令
├── agents/             # 子代理定义（可通过 Task tool 并行启动）
├── skills/             # 代理技能
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
├── setup/                 # 设置（CLAUDE.md、Plans.md 生成）
├── 2agent/                # 2代理设置（PM 协调、Cursor 设置）
├── memory/                # 内存管理（SSOT、decisions.md、patterns.md）
├── principles/            # 原则·指南（VibeCoder、差异编辑）
├── auth/                  # 认证·支付（Clerk、Supabase、Stripe）
├── deploy/                # 部署（Vercel、Netlify、分析）
├── ui/                    # UI（组件、反馈）
├── handoff/               # 工作流（交接、自动修正）
├── notebookLM/            # 文档（NotebookLM、YAML）
├── ci/                    # CI/CD（失败分析、测试修正）
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
| harness-plan | 计划、任务分解、Plans.md 更新 | "计划"、"任务添加"、"现在在哪" |
| harness-sync | 实现与 Plans.md 的同步 | "进度确认"、"完成了多少" |
| harness-work / breezing | 实现、并行执行、团队执行 | "实现"、"全部做完"、"团队推进" |
| harness-review | 代码审查、质量检查 | "审查"、"安全"、"性能" |
| harness-setup | 项目初始化、Codex 分发更新 | "设置"、"Codex 配置"、"初始化" |
| 2agent | 2代理运行设置 | "2-Agent"、"Cursor 设置"、"PM 协调" |
| memory | SSOT 管理、内存初始化 | "SSOT"、"decisions.md"、"合并" |
| principles | 开发原则、指南 | "原则"、"VibeCoder"、"安全性" |
| auth | 认证、支付功能 | "登录"、"Clerk"、"Stripe"、"支付" |
| deploy | 部署、分析 | "部署"、"Vercel"、"GA" |
| ui | UI 组件生成 | "组件"、"hero"、"表单" |
| handoff | 交接、自动修正 | "交接"、"向 PM 报告"、"自动修正" |
| notebookLM | 文档生成 | "文档"、"NotebookLM"、"幻灯片" |
| ci | CI/CD 问题解决 | "CI 失败了"、"测试失败" |
| maintenance | 文件整理 | "整理"、"清理" |

## 开发流程

1. **计划**: 使用 `$harness-plan` 将任务写入 Plans.md
2. **同步**: 使用 `$harness-sync` 确认现状与 Plans.md 的偏差
3. **实现**: 使用 `$harness-work` 或 `$breezing` 执行 Plans.md 中的任务
4. **审查**: 使用 `$harness-review` 进行质量检查
5. **验证**: 使用 `./tests/validate-plugin.sh` 进行结构验证

## 测试方法

```bash
# 插件结构验证
./tests/validate-plugin.sh
./scripts/ci/check-consistency.sh

# Codex CLI 确认（手动）
# - 确认 `${CODEX_HOME:-~/.codex}/skills` 或 `.codex/skills` 被加载
# - 确认 `$harness-plan`, `$harness-sync`, `$harness-work`, `$breezing`, `$harness-review` 被识别
```

## 注意事项

- **注意自指性**: 在此仓库中运行 `$harness-work` / `$breezing` 会编辑自身的代码
- **暂不支持 Hooks**: Codex 中通过 `.codex/rules/` 进行临时防护
- **VERSION 同步**: 普通 PR 中不要触碰 VERSION，仅在 release 时更新
- **旧 skill 会被归档**: setup script 会将已删除的 legacy Harness skill 移动到 `~/.codex/backups/`，防止旧命令残留

## 主要命令（开发时使用）

| 命令 | 用途 |
|---------|------|
| `$harness-plan` | 将改进任务添加到 Plans.md |
| `$harness-sync` | 同步实现与 Plans.md 的状态 |
| `$harness-work` | 实现任务（必要时并行化） |
| `$breezing` | Lead/Worker/Reviewer 的团队执行 |
| `$harness-review` | 审查变更内容 |
| `$harness-setup codex` | 更新 Codex 分发物并整理旧 skill |

### 交接

| 命令 | 用途 |
|---------|------|
| `$handoff-to-cursor` | Cursor 运行时的完成报告 |

**技能（对话中自动启动）**:
- `handoff-to-impl` - "交给实现者" → PM → Impl 的请求
- `handoff-to-pm` - "向 PM 报告完成" → Impl → PM 的完成报告

## SSOT（Single Source of Truth）

- `.claude/memory/decisions.md` - 决策事项（Why）
- `.claude/memory/patterns.md` - 可复用模式（How）

## 测试篡改预防（质量保证）

> 详情: [D9: 测试篡改预防的3层防御策略](.claude/memory/decisions.md#d9-テスト改ざん防止の3層防御戦略)

这是为了防止 Coding Agent 在测试失败时"偷懒"（测试篡改、lint 放宽、形骸化实现）倾向的机制。

### 3层防御策略

| 层 | 机制 | 强制力 |
|----|--------|--------|
| 第1层: Rules | `.codex/rules/harness.rules`（临时） | 事前确认（prompt） |
| 第2层: Skills | `impl`, `verify` 技能内置质量护栏 | 上下文强制（使用技能时） |
| 第3层: Hooks | 未支持（支持后替换） | - |

### 禁止模式

**测试篡改**:
- 更改为 `it.skip()`, `test.skip()`
- 删除/放宽断言
- 添加 eslint-disable 注释

**形骸化实现**:
- 硬编码测试期望值
- stub/mock/空实现
- 仅对特定输入有效的代码

### 遇到困难时的处理流程

```
1. 诚实报告（"此方法难以实现"）
2. 说明理由（技术限制、前提条件不足）
3. 提供选项（替代方案、分阶段实现）
4. 请用户判断
```

> ⚠️ **绝对禁止事项**: 篡改测试以伪造"成功"

<!-- sync-rules-to-agents: start -->

## Rules (from .claude/rules/)

> 本节由 `scripts/codex/sync-rules-to-agents.sh` 自动生成。
> 请勿直接编辑。SSOT 为 `.claude/rules/`。

| 规则文件 | 说明 |
|--------------|------|
| `cc-update-policy.md` | CC 更新跟踪时的质量策略 |
| `codex-cli-only.md` | Codex CLI Only Rule |
| `command-editing.md` | Brief description |
| `github-release.md` | GitHub Release Notes Rules |
| `hooks-editing.md` | Rules for editing hook configuration (hooks.json) |
| `implementation-quality.md` | 实现质量规则 - 禁止形骸化实现，促进本质性实现 |
| `shell-scripts.md` | Rules for editing shell scripts |
| `skill-editing.md` | "English description for auto-loading. Include trigger phrases." |
| `test-quality.md` | 测试质量保护规则 - 禁止测试篡改，促进正确实现 |
| `v3-architecture.md` | v3 架构详细 |
| `versioning.md` | 版本管理规则 |

### cc-update-policy


# CC 更新跟踪策略

Claude Code 新版本对应时更新 Feature Table 的质量标准。

## 基本原则

Feature Table 的添加必须伴随**相应的实现更改**或**类别 C（CC 自动继承）的明确分类**。

不允许在"仅向 Feature Table 添加行"的状态下合并 PR。

## 3 类别分类

| 类别 | 定义 | PR 合并 |
|---------|------|----------|
| **(A) 有实现** | hooks / scripts / agents / skills / core 有相应的实现更改 | 可 |
| **(B) 仅书写** | 仅更改 Feature Table。无实现 | **不可** -- 必须提出实现方案 |
| **(C) CC 自动继承** | CC 本体的修复，Harness 侧无需更改（性能改进、错误修复等） | 可（在 Feature Table 中明确标注"CC 自动继承"） |

## 规则

### 1. Feature Table 添加必须伴随实现或分类

向 Feature Table 添加新行时，必须满足以下任一条件:

- **(A)** 同一 PR 内包含相应的实现文件更改
- **(C)** Feature Table 中明确标注为"CC 自动继承"

若均不符合，则该项目被判定为类别 B（仅书写）。

### 2. 检测到类别 B 时阻止 PR 并要求实现方案

若存在 1 件及以上类别 B 的项目:

- **阻止** PR 的合并
- 对每个类别 B 项目，要求提出包含以下内容的**实现方案**:
  - Harness 独有附加价值的说明
  - 变更目标文件和具体变更内容
  - 用户体验的改善（以前 / 以后）

实现方案获得批准后，创建包含实现的额外提交或后续 PR。

### 3. 推荐添加"附加价值"列

推荐在 Feature Table 中添加可视化 A / B / C 分类的"附加价值"列。

```markdown
| Feature | Skill | Purpose | 附加价值 |
|---------|-------|---------|---------|
| PostCompact 钩子 | hooks | 上下文再注入 | A: 有实现 |

<!-- 全文: .claude/rules/cc-update-policy.md -->

### codex-cli-only

> 此规则适用于 Claude Code。在 Codex 环境中不适用。

<!-- 全文: .claude/rules/codex-cli-only.md -->

### command-editing

```

**Prohibited**:
- ❌ Adding `name:` field (automatically determined from filename)
- ❌ Adding custom fields (only description and description-en allowed)
- ❌ Omitting frontmatter

**Exceptions**:
- Only `harness-mem.md` has no frontmatter for historical reasons (planned for future unification)

### 2. File Naming Conventions

**Core Commands** (`commands/core/`):
- `harness-` prefix recommended (e.g., `harness-init.md`, `harness-review.md`)
- Naming that indicates plugin-specific functionality

**Optional Commands** (`commands/optional/`):
- **Harness integration**: `harness-` prefix (e.g., `harness-mem.md`, `harness-update.md`)
- **Feature setup**: `{feature}-setup` pattern (e.g., `ci-setup.md`, `lsp-setup.md`)
- **Operations**: `{action}-{target}` pattern (e.g., `sync-status.md`, `sync-ssot-from-memory.md`)

### 3. Fully Qualified Name Generation

The plugin system generates fully qualified names in the following format:

```
{plugin-name}:{category}:{command-name}
```

**Examples**:
- `commands/core/harness-init.md` → `claude-code-harness:core:harness-init`
- `commands/optional/cursor-mem.md` → `claude-code-harness:optional:cursor-mem`
- `commands/optional/ci-setup.md` → `claude-code-harness:optional:ci-setup`

## Command File Structure Template

### Standard Template

```markdown
---
description: Japanese description (one line, concise)
description-en: English description (one line, concise)
---

# {Command Name}

Overview description of the command.

## Quick Reference (Optional)


<!-- 全文: .claude/rules/command-editing.md -->

### github-release


Generated with [Claude Code](https://claude.com/claude-code)
```

### Required Elements

| Element | Required | Description |
|---------|----------|-------------|
| `## What's Changed` | Yes | Section heading |
| **Bold summary** | Yes | One-line value description |
| `Before / After` table | Yes | User-facing changes |
| `Added/Changed/Fixed` | When applicable | Detailed changes |
| Footer | Yes | `Generated with [Claude Code](...)` |

### Language

- **GitHub Release**: English required（公开仓库）
- **CHANGELOG.md**: **日语**详细 Before/After 形式（后述）
- Keep descriptions user-focused

## CHANGELOG 格式（日语·详细 Before/After）

CHANGELOG 以各功能"至今 → 今后"形式具体描述:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### 主题: [一句话概括整体变更]

**[用户价值 1-2 句]**

---

#### 1. [功能名]

**至今**: [旧行为。具体描述用户体验到的不便]

**今后**: [新行为。解决了什么 + 具体例子]

```输出示例或命令示例```

#### 2. [下一个功能名]

**至今**: ...
**今后**: ...
```

**写作规则**:
- 每个功能用 `#### N. 功能名` 作为独立章节
- "至今"是**问题描述**（以"需要做~"的形式）

<!-- 全文: .claude/rules/github-release.md -->

### hooks-editing


# Hooks Editing Rules

Rules applied when editing `hooks.json` files.

## Important: Dual hooks.json Sync (Required)

**Two hooks.json files exist and must always be in sync:**

```
hooks/hooks.json           ← Source file (for development)
.claude-plugin/hooks.json  ← For plugin distribution (sync required)
```

### Editing Flow

1. Edit `hooks/hooks.json`
2. Apply the same changes to `.claude-plugin/hooks.json`
3. Sync cache with `./scripts/sync-plugin-cache.sh`

```bash
# Always run after changes
./scripts/sync-plugin-cache.sh
```

## Hook Types

4 种类型可用: `command`（通用）、`http`（外部集成）、`prompt`（LLM 单一判断）、`agent`（LLM 代理判断）。后两者在 v2.1.63+ 支持所有事件。

> **CC v2.1.69+**: 添加了 `InstructionsLoaded` 事件、`agent_id` / `agent_type` 字段、`{"continue": false, "stopReason": "..."}` 响应。
>
> **CC v2.1.76+**: 添加了 `Elicitation`、`ElicitationResult`、`PostCompact` 事件。
> MCP Elicitation 在后台代理中无法进行 UI 对话，需要通过钩子自动处理。
> PostCompact 与 PreCompact 配对，用于压缩后的上下文再注入。
>
> **CC v2.1.77+**: 即使 PreToolUse 钩子返回 `"allow"`，settings.json 的 `deny` 规则也会优先生效。
> 即使在钩子中 allow，如果有 deny 设置也会被拒绝。设计 guardrail 时请注意此优先级。
>
> **CC v2.1.78+**: 添加了 `StopFailure` 事件。当 API 错误（速率限制、认证失败等）
> 导致会话停止失败时触发。用于错误日志和恢复处理。

### command Type (General Purpose)

Available for all events:

```json
{
  "type": "command",
  "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/run-script.js\" script-name",
  "timeout": 30

<!-- 全文: .claude/rules/hooks-editing.md -->

### implementation-quality

## 绝对禁止事项

### 1. 形骸化实现（仅为了通过测试的实现）

以下模式**绝对禁止**：

| 禁止模式 | 例 | 为什么不行 |
|------------|-----|-----------|
| 硬编码 | 直接返回测试期望值 | 其他输入无法工作 |
| 存根实现 | `return null`, `return []` | 没有功能 |
| 特定值实现 | 只对应测试用例的值 | 没有通用性 |
| 复制粘贴实现 | 测试期望值字典 | 没有有意义的逻辑 |

### 禁止例：测试期望值的硬编码

```python
# ❌ 绝对禁止
def slugify(text: str) -> str:
    answers_for_tests = {
        "HelloWorld": "hello-world",
        "Test Case": "test-case",
        "API Endpoint": "api-endpoint",
    }
    return answers_for_tests.get(text, "")
```

```python
# ✅ 正确的实现
def slugify(text: str) -> str:
    import re
    text = text.strip().lower()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_]+', '-', text)
    return text
```

### 2. 仅表面的实现

```typescript
// ❌ 禁止：什么都没做
async function processData(data: Data[]): Promise<Result> {
  // TODO: implement later
  return {} as Result;
}

// ❌ 禁止：吞掉错误
async function fetchUser(id: string): Promise<User | null> {
  try {
    // ...
  } catch {
    return null; // 隐藏错误
  }
}
```

---

## 实现时的自查

实现完成前，请确认以下内容：

<!-- 全文: .claude/rules/implementation-quality.md -->

### shell-scripts


# Shell Scripts Rules

Rules applied when editing shell scripts in the `scripts/` directory.

## Required Patterns

### 1. Header Format

```bash
#!/bin/bash
# script-name.sh
# One-line description of the script's purpose
#
# Usage: ./scripts/script-name.sh [arguments]

set -euo pipefail
```

### 2. JSON Output Format for Hook Scripts

Hook scripts (`*-hook.sh`, `stop-*.sh`, etc.) return results in JSON:

```bash
# On success
echo '{"decision": "approve", "reason": "explanation"}'

# On warning
echo '{"decision": "approve", "reason": "explanation", "systemMessage": "notification to user"}'

# On rejection
echo '{"decision": "deny", "reason": "reason"}'
```

### 3. Handling Environment Variables

```bash
# CLAUDE_PLUGIN_ROOT must always be verified
if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  echo "Error: CLAUDE_PLUGIN_ROOT not set" >&2
  exit 1
fi

# PROJECT_ROOT fallback
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
```

## Prohibited

- ❌ Execution without `set -e`

<!-- 全文: .claude/rules/shell-scripts.md -->

### skill-editing

```

### 3. Available Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (matches directory name) |
| `description` | Yes | English description for auto-loading (include trigger phrases). Token-efficient. |
| `description-ja` | Recommended | Japanese description for i18n. Use `scripts/set-locale.sh ja` to swap into `description`. |
| `allowed-tools` | No | Tools the skill can use |
| `argument-hint` | No | Usage hint (e.g., `"[option1|option2]"`) |
| `disable-model-invocation` | No | Set `true` for dangerous operations |
| `user-invocable` | No | Set `false` for internal-only skills |
| `context` | No | `fork` for isolated context |
| `hooks` | No | Event hooks configuration |

### 4. File Size Guidelines

| Guideline | Recommendation |
|-----------|----------------|
| SKILL.md | 推荐 500 行以下 |
| Large content | Split into `references/` files |
| References | Use descriptive filenames |

> **Note (CC 2.1.32+)**: 技能的字符预算会自动缩放到上下文窗口的 **2%**。
> 500 行只是推荐值，实际上限取决于模型的上下文窗口大小。
> 大型技能文件可能会被自动裁剪，因此
> 请将重要信息放在 SKILL.md 的开头附近，详细内容请分割到 `references/` 中。

### 5. Description Best Practices

The `description` field is critical for auto-loading. Include:
- What the skill does
- Trigger phrases (e.g., "Use when user mentions...")
- What NOT to load for (e.g., "Do NOT load for: ...")

**Good example**:
```yaml
description: "Manages CI/CD failures. Use when user mentions CI failures, build errors, or test failures. Do NOT load for: local builds or standard implementation."
```

**Bad example**:
```yaml
description: "CI skill"
```

## Skill File Structure Template

### SKILL.md Template


<!-- 全文: .claude/rules/skill-editing.md -->

### test-quality

## 绝对禁止事项

### 1. 测试篡改（为了通过测试的更改）

以下行为**绝对禁止**：

| 禁止模式 | 例 | 正确对应 |
|------------|-----|-----------|
| 测试 `skip` / `only` 化 | `it.skip(...)`, `describe.only(...)` | 修正实现 |
| 删除/放宽断言 | 删除 `expect(x).toBe(y)` | 确认期望值是否正确，修正实现 |
| 随意改写期望值 | 根据错误更改期望值 | 理解测试为什么失败 |
| 删除测试用例 | 删除失败的测试 | 修正实现以满足规格 |
| 过度使用 mock | mock 本应测试的部分 | 保持最小限度的 mock |

### 2. 配置文件篡改

以下文件的**放宽更改禁止**：

```
.eslintrc.*         # 不要 disable 规则
.prettierrc*        # 不要放宽格式
tsconfig.json       # 不要放宽 strict
biome.json          # 不要禁用 lint 规则
.husky/**           # 不要绕过 pre-commit 钩子
.github/workflows/** # 不要跳过 CI 检查
```

### 3. 设置例外时（必须步骤）

不得已更改上述内容时，**必须先按以下格式获得批准**：

```markdown

<!-- 全文: .claude/rules/test-quality.md -->

### v3-architecture


<!-- 全文: .claude/rules/v3-architecture.md -->

### versioning


<!-- 全文: .claude/rules/versioning.md -->

<!-- sync-rules-to-agents: end -->
