---
name: migrate-workflow-files
description: "在精查现有项目 AGENTS.md/CLAUDE.md/Plans.md 内容的同时，通过对话确定继承项目，迁移到新格式（带备份，Plans 保持任务合并）。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
---

# Migrate Workflow Files (Interactive Merge)

## 目的

将现有项目中正在运行的以下内容，**在尊重现有内容的同时更新到新格式**。

- `AGENTS.md`
- `CLAUDE.md`
- `Plans.md`

要点：

- **通过对话形式确定继承信息**（不随意丢弃 / 不随意覆盖）
- 更改前**必须保留备份**
- `Plans.md` 按 `merge-plans` 的方针**在保持任务的同时更新结构**

---

## 前提（重要）

此技能为了兼顾「首次应用时的安全」和「预期行为（新格式）」，
按**用户同意→备份→生成→确认差异**的顺序进行。

---

## 输入（可在此技能内自动检测）

- `project_name`：用 `basename $(pwd)` 推测
- `date`：`YYYY-MM-DD`
- 现有文件的有无：
  - `AGENTS.md`
  - `CLAUDE.md`
  - `Plans.md`
- 新格式的参考模板：
  - `templates/AGENTS.md.template`
  - `templates/CLAUDE.md.template`
  - `templates/Plans.md.template`

---

## 执行流程

### Step 0：检测和取得同意（必需）

1. 用 `Read` 确认现有 `AGENTS.md` / `CLAUDE.md` / `Plans.md` 的存在。
2. 存在时向用户确认：
   - **是否可以迁移（更新到新格式）**
   - 重要：迁移**包含内容的重新整理**（= 可能发生布局调整或措辞变更）

用户回答 NO 时：

- 此技能中止（不重写任何内容）
- 代为提议「只安全合并 `.claude/settings.json`」等安全作业

### Step 1：精查现有内容（摘要）

用 `Read` 读取各文件，提取以下内容并简短摘要提示：

- **AGENTS.md**：角色分工、handoff 流程、禁止事项、环境/前提
- **CLAUDE.md**：重要约束（禁止事项/权限/分支运营）、测试流程、提交规范、运营规则
- **Plans.md**：任务结构、标记运营、当前的 WIP/请求中任务

### Step 2：确定继承项目（对话）

基于摘要，向用户提问**想保留/调整**的项目（最多 5-10 问即可）：

- 绝对要保留的约束（例：禁止生产部署、禁止特定目录、安全要求）
- 角色分工（Solo/2-agent）的前提
- 分支运营（main/staging 等）
- 测试/构建的代表性命令
- Plans 的标记运营（如有现有规则则对齐）

### Step 3：创建备份（必需）

备份汇总到项目内的 `.claude-code-harness/backups/`（大多不想放入 git）。

例：

- `.claude-code-harness/backups/2025-12-13/AGENTS.md`
- `.claude-code-harness/backups/2025-12-13/CLAUDE.md`
- `.claude-code-harness/backups/2025-12-13/Plans.md`

可用 `Bash` 的 `mkdir -p` 和 `cp`。

### Step 4：生成新格式（合并）

#### 4-1. Plans.md（任务保持合并）

按 `merge-plans` 的方针执行：

- 保留现有的 🔴🟡🟢📦 任务
- 标记图例/最后更新信息更新为模板侧
- 如无法解析则保留备份并采用模板

#### 4-2. AGENTS.md / CLAUDE.md（模板 + 继承块）

用模板构建骨架，将 Step 2 确定的项目**重新配置到新格式的适当位置**。

最低限度的方针：

- 不删除现有的「重要规则」，作为**「项目固有规则（迁移）」**部分保留
- 角色分工/流程按模板的格式重写（保持含义）

### Step 5：确认差异并完成

- 用 `git diff`（或文件差异）简短摘要更改点
- 最终确认重点（权限/禁止事项/任务状态）是否符合意图
- 如有问题立即修正

---

## 成果物（完成条件）

- 基于现有内容的**新格式版** `AGENTS.md` / `CLAUDE.md` / `Plans.md`
- `.claude-code-harness/backups/` 中保留备份
- Plans 的任务未丢失（已保留）


