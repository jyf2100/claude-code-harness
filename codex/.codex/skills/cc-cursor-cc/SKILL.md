---
name: cc-cursor-cc
description: "用 Cursor PM 验证想法并更新 Plans.md 后交接。支持 Cursor ↔ Claude Code 2-Agent 工作流。Use when user mentions Cursor PM handoff, 2-agent plan validation, CC-Cursor round trip, or brainstorm review. Do NOT load for: implementation work, single-agent tasks, or direct coding."
description-en: "Validates brainstormed ideas with Cursor PM, updates Plans.md, then handoff back. Cursor ↔ Claude Code 2-Agent workflow support. Use when user mentions Cursor PM handoff, 2-agent plan validation, CC-Cursor round trip, or brainstorm review. Do NOT load for: implementation work, single-agent tasks, or direct coding."
description-ja: "Cursor PM でアイデアを検証し Plans.md を更新してバトンタッチ。Cursor ↔ Claude Code 2-Agent ワークフロー対応。Use when user mentions Cursor PM handoff, 2-agent plan validation, CC-Cursor round trip, or brainstorm review. Do NOT load for: implementation work, single-agent tasks, or direct coding."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
user-invocable: false
---

# CC-Cursor-CC Skill (Plan Validation Round Trip)

支持从 Claude Code 将头脑风暴内容发送到 **Cursor (PM)** 进行可行性验证的流程。

## Prerequisites

此技能假设 **2-agent 操作**。

| Role | Agent | Description |
|------|-------|-------------|
| **PM** | Cursor | 验证计划，更新 Plans.md |
| **Impl** | Claude Code | 头脑风暴，实现 |

## Execution Flow

### Step 1: 提取头脑风暴上下文

从最近对话中提取：
1. **Goal**（功能/目的）
2. **Technology choices**
3. **Decisions made**
4. **Undecided items**
5. **Concerns**

### Step 2: 向 Plans.md 添加临时任务

```markdown
## 🟠 Under Validation: {{Project}} `pm:awaiting-validation`

### Provisional Tasks (To Validate)
- [ ] {{task1}} `awaiting-validation`
- [ ] {{task2}} `awaiting-validation`

### Undecided Items
- {{item1}} → **Requesting PM decision**
```

### Step 3: 生成给 Cursor 的验证请求

生成复制粘贴到 Cursor 的文本：

```markdown
## 📋 Plan Validation Request

**Goal**: {{summary}}

**Provisional tasks**:
1. {{task1}}
2. {{task2}}

### ✅ Requesting Cursor (PM) to:
1. Validate feasibility
2. Break down tasks
3. Decide undecided items
4. Update Plans.md (awaiting → cc:TODO)
```

### Step 4: 指导下一步操作

1. 复制并粘贴请求到 **Cursor**
2. 在 Cursor 运行 `/plan-with-cc`
3. Cursor 更新 Plans.md
4. Cursor 运行 `/handoff-to-claude`
5. 复制并粘贴回 **Claude Code**

## Overall Flow

```
Claude Code (Brainstorm)
    ↓ /cc-cursor-cc
Cursor (PM validates & breaks down)
    ↓ /handoff-to-claude
Claude Code (/work implements)
```
