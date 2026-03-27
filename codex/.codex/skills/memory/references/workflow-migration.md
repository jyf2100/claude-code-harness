---
name: migrate-workflow-files
description: "将现有项目的 AGENTS.md/CLAUDE.md/Plans.md，在审阅现有内容后通过对话确定交接项目，迁移到新格式（带备份・Plans 任务保持合并）。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
---

# Migrate Workflow Files (Interactive Merge)

## 目的

将现有项目运行中的以下文件，**在尊重现有内容的同时更新到新格式**：

- `AGENTS.md`
- `CLAUDE.md`
- `Plans.md`

要点：

- **通过对话形式确定交接信息**（不随意丢弃 / 不随意覆盖）
- 变更前**必须备份**
- `Plans.md` 按 `merge-plans` 方针**保持任务同时更新结构**

---

## 前提（重要）

此技能为兼顾「首次应用时的安全」和「预期行为（新格式）」，按**用户同意→备份→生成→确认差异**的顺序进行。

---

## 输入（可在此技能内自动检测）

- `project_name`：通过 `basename $(pwd)` 推断
- `date`：`YYYY-MM-DD`
- 现有文件是否存在：
  - `AGENTS.md`
  - `CLAUDE.md`
  - `Plans.md`
- 新格式参考模板：
  - `templates/AGENTS.md.template`
  - `templates/CLAUDE.md.template`
  - `templates/Plans.md.template`

---

## 执行流程

### Step 0: 检测与取得同意（必填）

1. 用 `Read` 确认现有 `AGENTS.md` / `CLAUDE.md` / `Plans.md` 是否存在。
2. 存在时向用户确认：
   - **是否迁移（更新到新格式）**
   - 重要：迁移**包含内容的重新整理**（= 可能会有布局调整或措辞变更）

用户回答 NO 时：

- 此技能中止（不修改任何内容）
- 改为建议「只安全合并 `.claude/settings.json`」等安全操作

### Step 1: 审阅现有内容（摘要）

用 `Read` 读取各文件，提取以下内容并简短摘要提示：

- **AGENTS.md**：角色分工、交接步骤、禁止事项、环境/前提
- **CLAUDE.md**：重要约束（禁止事项/权限/分支运行）、测试步骤、提交约定、运行规则
- **Plans.md**：任务结构、标记运行、当前 WIP/请求中任务

### Step 2: 确定交接项目（对话）

基于摘要，向用户提问要**保持/调整**的项目（最多 5~10 问即可）：

- 绝对应该保留的约束（如：禁止生产部署、禁止特定目录、安全要求）
- 角色分工（Solo/2-agent）的前提
- 分支运行（main/staging 等）
- 测试/构建的代表命令
- Plans 的标记运行（如有现有规则则保持一致）

### Step 3: 创建备份（必填）

备份统一放在项目内的 `.claude-code-harness/backups/`（多数情况不想放入 git）。

例如：

- `.claude-code-harness/backups/2025-12-13/AGENTS.md`
- `.claude-code-harness/backups/2025-12-13/CLAUDE.md`
- `.claude-code-harness/backups/2025-12-13/Plans.md`

可用 `Bash` 的 `mkdir -p` 和 `cp`。

### Step 4: 生成新格式（合并）

#### 4-1. Plans.md（任务保持合并）

按 `merge-plans` 方针执行：

- 保持现有 🔴🟡🟢📦 任务
- 标记图例・最终更新信息更新到模板侧
- 无法解析时保留备份并采用模板

#### 4-2. AGENTS.md / CLAUDE.md（模板 + 交接块）

用模板构建骨架，将 Step 2 确定的项目**重新放置到新格式的适当位置**。

最低方针：

- 不删除现有「重要规则」，作为**「项目固有规则（迁移）」**章节保留
- 角色分工/流程按模板格式重写（保持含义）

### Step 5: 确认差异与完成

- 用 `git diff`（或文件差异）简短摘要变更点
- 最终确认重点（权限/禁止事项/任务状态）是否符合意图
- 有问题立即修正

---

## 成果物（完成条件）

- 基于现有内容的**新格式版** `AGENTS.md` / `CLAUDE.md` / `Plans.md`
- `.claude-code-harness/backups/` 中留有备份
- Plans 任务未丢失（保持）
