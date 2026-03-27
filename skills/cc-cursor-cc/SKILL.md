---
name: cc-cursor-cc
description: "用 Cursor PM 验证想法，更新 Plans.md 后交接。支持 Cursor ↔ Claude Code 双代理工作流。Use when user mentions Cursor PM handoff, 2-agent plan validation, CC-Cursor round trip, or brainstorm review. Do NOT load for: implementation work, single-agent tasks, or direct coding."
description-en: "Validates brainstormed ideas with Cursor PM, updates Plans.md, then handoff back. Cursor ↔ Claude Code 2-Agent workflow support. Use when user mentions Cursor PM handoff, 2-agent plan validation, CC-Cursor round trip, or brainstorm review. Do NOT load for: implementation work, single-agent tasks, or direct coding."
description-zh: "用 Cursor PM 验证想法，更新 Plans.md 后交接。支持 Cursor ↔ Claude Code 双代理工作流。触发短语：Cursor PM 交接、双代理计划验证、CC-Cursor 往返、头脑风暴审查。不用于：实现工作、单代理任务、直接编码。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
user-invocable: false
---

# CC-Cursor-CC 技能（计划验证往返）

支持将头脑风暴内容从 Claude Code 发送到 **Cursor (PM)** 进行可行性验证的流程。

## 前提条件

此技能假设**双代理运行**。

| 角色 | 代理 | 说明 |
|------|------|------|
| **PM** | Cursor | 验证计划，更新 Plans.md |
| **Impl** | Claude Code | 头脑风暴，实现 |

## 执行流程

### Step 1: 提取头脑风暴上下文

从最近的对话中提取：
1. **目标**（功能/目的）
2. **技术选择**
3. **已做决策**
4. **未决事项**
5. **顾虑点**

### Step 2: 添加临时任务到 Plans.md

```markdown
## 🟠 验证中: {{项目}} `pm:awaiting-validation`

### 临时任务（待验证）
- [ ] {{任务1}} `awaiting-validation`
- [ ] {{任务2}} `awaiting-validation`

### 未决事项
- {{事项1}} → **请求 PM 决定**
```

### Step 3: 生成验证请求给 Cursor

生成复制粘贴到 Cursor 的文本：

```markdown
## 📋 计划验证请求

**目标**: {{摘要}}

**临时任务**:
1. {{任务1}}
2. {{任务2}}

### ✅ 请求 Cursor (PM)：
1. 验证可行性
2. 分解任务
3. 决定未决事项
4. 更新 Plans.md（awaiting → cc:TODO）
```

### Step 4: 指导下一步操作

1. 复制并粘贴请求到 **Cursor**
2. 在 Cursor 中运行 `/plan-with-cc`
3. Cursor 更新 Plans.md
4. Cursor 运行 `/handoff-to-claude`
5. 复制并粘贴回 **Claude Code**

## 整体流程

```
Claude Code (头脑风暴)
    ↓ /cc-cursor-cc
Cursor (PM 验证并分解)
    ↓ /handoff-to-claude
Claude Code (/work 实现)
```
