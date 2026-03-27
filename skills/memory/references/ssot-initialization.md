---
name: init-memory-ssot
description: "初始化项目的 SSOT 内存（decisions/patterns）和可选的 session-log。首次设置或 .claude/memory 未整理的项目使用。"
allowed-tools: ["Read", "Write"]
---

# Init Memory SSOT

初始化 `.claude/memory/` 下的 **SSOT**。

- `decisions.md`（重要决策的 SSOT）
- `patterns.md`（可复用解决方案的 SSOT）
- `session-log.md`（会话日志。推荐本地使用）

详细方针：`docs/MEMORY_POLICY.md`

---

## 执行步骤

### Step 1：确认现有文件

- `.claude/memory/decisions.md`
- `.claude/memory/patterns.md`
- `.claude/memory/session-log.md`

已存在的**不覆盖**。

### Step 2：从模板初始化（仅当不存在时）

模板：

- `templates/memory/decisions.md.template`
- `templates/memory/patterns.md.template`
- `templates/memory/session-log.md.template`

将 `{{DATE}}` 替换为当天（例：`2025-12-13`）生成。

### Step 3：完成报告

- 创建的文件列表
- Git 方针（`decisions/patterns` 推荐共享，`session-log/.claude/state` 推荐本地）


