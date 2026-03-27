# Sync Project Specs Reference

**工作完成后不确定「Plans.md 是否正确更新了」时执行。**

## When to Use

| Situation | Command to Use |
|-----------|----------------|
| "进展如何？接下来做什么？" | `/sync-status`（首先用这个） |
| "做了工作但忘记是否更新 Plans.md" | **此命令** |
| "从旧模板开始，格式可能过时" | **此命令** |

> Tip: 通常 `/sync-status` 就够了。用这个作为「以防万一」或「格式迁移」。

---

## Purpose

将项目规格/文档（如 `Plans.md`、`AGENTS.md`、`.claude/rules/*`）与最新 claude-code-harness 操作（**PM ↔ Impl**、`pm:*` 标记、handoff 命令）对齐。

## VibeCoder Phrases

- "**做了工作但不确定 Plans.md 是否更新**" → 此命令
- "**想将旧格式文件统一到最新**" → 统一标记和说明
- "**保留手动更改，只修复必要部分**" → 保留现有文本，只应用差分

---

## Sync Targets（仅现有文件）

- `Plans.md`
- `AGENTS.md`
- `CLAUDE.md`（仅当有操作说明时）
- `.claude/rules/workflow.md`
- `.claude/rules/plans-management.md`

---

## Sync Content（最小差分方针）

### 1. 标记规范化

- **标准**: `pm:依頼中`, `pm:確認済`
- **兼容**: `cursor:依頼中`, `cursor:確認済`（视为同义词）

### 2. 状态转换文档化

```
pm:依頼中 → cc:WIP → cc:完了 → pm:確認済
```

### 3. 添加 Handoff 路由

- PM→Impl: `/handoff-to-impl-claude`（用于 PM Claude）
- Impl→PM: `/handoff-to-pm-claude`
- Cursor 工作流: `/handoff-to-claude`, `/handoff-to-cursor`

### 4. 通知文件说明

- `.claude/state/pm-notification.md`（兼容: `.claude/state/cursor-notification.md`）

---

## 执行步骤

### Step 1: 收集当前状态（必需）

- 确认目标文件存在并提取相关区块
- 统计 `Plans.md` 标记出现次数（pm/cursor/cc）

### Step 2: 声明更改方针（必需）

告诉用户：
- 原则上保留现有文本（不破坏性重写）
- 添加/替换限于「操作所需的最小必要」
- 更改以差分显示，需要时调整

### Step 3: 同步（应用差分）

- **Plans.md**: 添加 `pm:*` 到标记图例，注明 `cursor:*` 为兼容
- **AGENTS.md**: 更新角色为 PM/Impl
- **rules/*.md**: 将 `cursor:*` 更改为 `pm:*` 标准 + 兼容说明
- **CLAUDE.md**: 如有操作区块则添加 PM↔Impl 路由

### Step 4: 完成（必需）

- 运行 `/sync-status` 验证标记
- 需要时用 `/remember` 锁定「项目特定操作」

---

## 并行执行

文件读取可以并行：

| Process | Parallel |
|---------|----------|
| Plans.md 读取 | ✅ 独立 |
| AGENTS.md 读取 | ✅ 独立 |
| CLAUDE.md 读取 | ✅ 独立 |
| rules/*.md 读取 | ✅ 独立 |

更新为保证一致性串行运行。
