# GitHub Release Notes Rules

Formatting rules applied when creating GitHub Release notes.

## Required Format

### Structure

```markdown
## What's Changed

**One-line description of the change's value**

### Before / After

| Before | After |
|--------|-------|
| Previous state | New state |
| ... | ... |

---

## Added

- **Feature name**: Description
  - Detail 1
  - Detail 2

## Changed

- **Change**: Description

## Fixed

- **Fix**: Description

## Requirements (if applicable)

- **Claude Code vX.X.X+** (recommended)
- Link: [Documentation](URL)

---

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

CHANGELOG 以"至今 → 今后"形式具体描述各功能:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### 主题: [一句话概括整体变更]

**[1-2句描述对用户的价值]**

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
- "至今"是**问题描述**（以"需要做〜"的形式）
- "今后"是**解决方案的具体形态**（包含命令示例、输出示例）
- 长一点没关系。可读性最优先
- 技术细节（文件名、步骤编号）作为"今后"的补充，保持在最低限度

## Prohibited

- No skipping the Before / After (CHANGELOG) or Before / After table (GitHub Release)
- No skipping the footer (GitHub Release)
- No technical-only descriptions (user perspective required)
- No bare change lists without value explanation

## Good Example (GitHub Release — English)

```markdown
## What's Changed

**`/work --full` now automates implement -> self-review -> improve -> commit in parallel**

### Before / After

| Before | After |
|--------|-------|
| `/work` executes tasks one at a time | `/work --full --parallel 3` runs in parallel |
| Reviews required separate manual step | Each task-worker self-reviews autonomously |
```

## Good Example (CHANGELOG — Japanese)

```markdown
#### 1. 失败任务的自动重新工单化

**至今**: 测试/CI 失败后只会重试 3 次就停止。
停止后需要自己调查"原因是什么"，并手动向 Plans.md 添加修正任务。

**今后**: 3 次失败停止时，Harness 会分类失败原因，并自动生成修正任务方案。
批准后会作为 `.fix` 任务自动添加到 Plans.md。
```

## Bad Example

```markdown
## What's New

### Added
- Added task-worker.md
- Added --full option
```

-> Doesn't communicate user value

## Release Creation Command

```bash
gh release create vX.X.X \
  --title "vX.X.X - Title" \
  --notes "$(cat <<'EOF'
## What's Changed
...
EOF
)"
```

## Editing Past Releases

```bash
gh release edit vX.X.X --notes "$(cat <<'EOF'
...
EOF
)"
```

## CC 版本整合时的 CHANGELOG 模式

包含 Claude Code 新版本整合的发布中，不使用常规的"至今 / 今后"形式，
而是使用 **"CC 的更新 → Harness 中的活用"形式**。
从上游（CC）的变更理由开始说明，让读者能从上下文理解"为什么这个变更与自己相关"。

### 判定条件

符合以下任一条件时，应用此模式:

- Feature Table 的版本标识已更新
- hooks.json 中添加了 CC 相关的新事件
- skills 中追加了 CC 新功能的使用指南

### 结构

```markdown
#### N. Claude Code X.Y.Z 整合

（1 行概述整体）

##### N-1. 功能名

**CC 的更新**: Claude Code 有什么变化。以用户视角说明该功能是做什么的。

**Harness 中的活用**: Harness 如何利用该变更。包含具体机制（脚本名、流程）。

##### N-2. 下一个功能名

**CC 的更新**: ...
**Harness 中的活用**: ...
```

### 写作规则

- 每个功能用 `##### N-X.` 作为独立章节
- "CC 的更新"写的不是文件变更，而是**用户体验的变化**
- "Harness 中的活用"写**具体机制**（什么在运行、什么被防止）
- 避免罗列文件名。不要写"更新 hooks.json"，而要写"防止 Worker 冻结"
- 仅文档的变更（Feature Table 更新、详细章节追加）不单独列条目，包含在开头的 1 行概述中

### Good Example

```markdown
##### 5-1. MCP Elicitation 自动对应

**CC 的更新**: MCP 服务器可以在任务执行中向用户"提问"了（Elicitation）。
例如可以要求填写"要推送到哪个仓库？"这样的表单输入。

**Harness 中的活用**: Breezing 的 Worker 是后台执行的，无法响应问题表单。
放置不管会导致 Worker 冻结。新创建 elicitation-handler.sh，
实现了 Breezing 会话中自动跳过、通常会话中原样通过让用户回答的机制。
```

### Bad Example

```markdown
#### CC 2.1.76 整合

- 在 hooks.json 中添加 Elicitation
- 创建 elicitation-handler.sh
- 更新 CLAUDE.md
```

→ 只是罗列文件变更，无法传达为什么需要这个变更、对用户来说有什么变化

## Reference

- Good examples: v2.8.0, v2.8.2, v2.9.1, v3.10.3 (CC整合模式)
- Keep consistent with CHANGELOG
