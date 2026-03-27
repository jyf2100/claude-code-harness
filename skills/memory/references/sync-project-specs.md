# Sync Project Specs Reference

**工作完成后「Plans.md 更新了吗？」不安时执行。**

## When to Use

| Situation | Command to Use |
|-----------|----------------|
| "进行到哪了？接下来做什么？" | `/sync-status`（先用这个） |
| "做完了但忘记是否更新了 Plans.md" | **此命令** |
| "从旧模板开始，格式可能过时" | **此命令** |

> 提示：通常 `/sync-status` 就够了。此命令用于「以防万一」或「格式迁移」。

---

## Purpose

将项目规范/文档（如 `Plans.md`、`AGENTS.md`、`.claude/rules/*`）与最新 claude-code-harness 操作对齐（**PM ↔ Impl**、`pm:*` 标记、handoff 命令）。

## VibeCoder Phrases

- "**做完了但不确定 Plans.md 是否更新**" → 此命令
- "**想将旧格式文件对齐到最新**" → 统一标记和说明
- "**保留手动更改，只修复需要的部分**" → 保留现有文本，只应用差异

---

## Sync Targets（仅现有文件）

- `Plans.md`
- `AGENTS.md`
- `CLAUDE.md`（仅当有操作说明时）
- `.claude/rules/workflow.md`
- `.claude/rules/plans-management.md`

---

## Sync Content（最小差异策略）

### 1. 标记规范化

- **标准**：`pm:依頼中`、`pm:確認済`
- **兼容**：`cursor:依頼中`、`cursor:確認済`（视为同义词）

### 2. 状态转换文档

```
pm:依頼中 → cc:WIP → cc:完了 → pm:確認済
```

### 3. 添加 Handoff 路由

- PM→Impl：`/handoff-to-impl-claude`（用于 PM Claude）
- Impl→PM：`/handoff-to-pm-claude`
- Cursor 工作流：`/handoff-to-claude`、`/handoff-to-cursor`

### 4. 通知文件说明

- `.claude/state/pm-notification.md`（兼容：`.claude/state/cursor-notification.md`）

---

## Execution Steps

### Step 1：收集当前状态（必需）

- 检查目标文件存在性并提取相关部分
- 统计 `Plans.md` 标记出现次数（pm/cursor/cc）

### Step 2：声明更改策略（必需）

告诉用户：
- 原则上保留现有文本（不破坏性重写）
- 添加/替换仅限于「运行所需的最小范围」
- 以差异形式显示更改，可按需调整

### Step 3：同步（应用差异）

- **Plans.md**：在标记图例中添加 `pm:*`，注明 `cursor:*` 为兼容
- **AGENTS.md**：将角色更新为 PM/Impl
- **rules/*.md**：将 `cursor:*` 改为 `pm:*` 标准 + 兼容性说明
- **CLAUDE.md**：如有操作部分则添加 PM↔Impl 路由

### Step 4：完成（必需）

- 运行 `/sync-status` 验证标记
- 如需要用 `/remember` 锁定「项目特定操作」

---

## Parallel Execution

文件读取可并行：

| Process | Parallel |
|---------|----------|
| Plans.md 读取 | ✅ 独立 |
| AGENTS.md 读取 | ✅ 独立 |
| CLAUDE.md 读取 | ✅ 独立 |
| rules/*.md 读取 | ✅ 独立 |

更新为保持一致性串行运行。
