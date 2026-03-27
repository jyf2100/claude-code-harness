---
name: workflow-guide
description: "提供 Cursor ↔ Claude Code 双代理工作流指导。Use when user asks about workflow, collaboration, or process. Do NOT load for: implementation work, workflow setup, or executing handoffs."
description-en: "Provides guidance on Cursor ↔ Claude Code 2-agent workflow. Use when user asks about workflow, collaboration, or process. Do NOT load for: implementation work, workflow setup, or executing handoffs."
description-zh: "提供 Cursor ↔ Claude Code 双代理工作流指导。触发短语：工作流、协作、流程。不用于：实现工作、工作流设置、执行交接。"
allowed-tools: ["Read"]
user-invocable: false
---

# Workflow Guide 技能

提供 Cursor ↔ Claude Code 双代理工作流指导的技能。

---

## 触发短语

此技能在以下短语时启动：

- "告诉我工作流"
- "和 Cursor 怎么协作？"
- "告诉我工作流程"
- "该怎么推进？"
- "how does the workflow work?"
- "explain 2-agent workflow"

---

## 概要

此技能说明 Cursor（PM）和 Claude Code（Worker）的角色分工和协作方法。

---

## 双代理工作流

### 角色分工

| 代理 | 角色 | 职责 |
|------|------|------|
| **Cursor** | PM（项目经理） | 任务分配、审查、生产部署决策 |
| **Claude Code** | Worker（工作者） | 实现、测试、CI 修复、staging 部署 |

### 工作流图

```
┌─────────────────────────────────────────────────────────┐
│                    Cursor (PM)                          │
│  ・将任务添加到 Plans.md                                │
│  ・向 Claude Code 请求工作（/handoff-to-claude）         │
│  ・审查完成报告                                         │
│  ・决定生产部署                                         │
└─────────────────────┬───────────────────────────────────┘
                      │ 任务请求
                      ▼
┌─────────────────────────────────────────────────────────┐
│                  Claude Code (Worker)                   │
│  ・用 /work 执行任务（支持并行执行）                    │
│  ・实现 → 测试 → 提交                                   │
│  ・CI 失败时自动修复（最多 3 次）                       │
│  ・用 /handoff-to-cursor 完成报告                       │
└─────────────────────┬───────────────────────────────────┘
                      │ 完成报告
                      ▼
┌─────────────────────────────────────────────────────────┐
│                    Cursor (PM)                          │
│  ・确认更改内容                                         │
│  ・staging 运行确认                                     │
│  ・执行生产部署（批准后）                               │
└─────────────────────────────────────────────────────────┘
```

---

## Plans.md 任务管理

### 标记一览

| 标记 | 含义 | 设置者 |
|------|------|--------|
| `pm:依頼中` | PM 请求（兼容: cursor:依頼中） | PM（Cursor/PM Claude） |
| `cc:TODO` | Claude Code 未开始 | 任意 |
| `cc:WIP` | Claude Code 工作中 | Claude Code |
| `cc:完了` | Claude Code 完成 | Claude Code |
| `pm:確認済` | PM 确认完成（兼容: cursor:確認済） | PM（Cursor/PM Claude） |
| `cursor:依頼中` | （兼容）与 pm:依頼中 同义 | Cursor |
| `cursor:確認済` | （兼容）与 pm:確認済 同义 | Cursor |
| `blocked` | 阻塞中 | 任意 |

### 任务状态转换

```
pm:依頼中 → cc:WIP → cc:完了 → pm:確認済
```

---

## 主要命令

### Claude Code 侧

| 命令 | 用途 |
|------|------|
| `/harness-init` | 项目设置 |
| `/plan-with-agent` | 计划/任务分解 |
| `/work` | 执行任务（支持并行执行） |
| `/handoff-to-cursor` | 完成报告（给 Cursor PM） |
| `/sync-status` | 状态确认 |

### 技能（对话中自动启动）

| 技能 | 触发示例 |
|------|---------|
| `handoff-to-pm` | "向 PM 完成报告" |
| `handoff-to-impl` | "交给实现者" |

### Cursor 侧（参考）

| 命令 | 用途 |
|------|------|
| `/handoff-to-claude` | 向 Claude Code 请求任务 |
| `/review-cc-work` | 审查完成报告 |

---

## CI/CD 规则

### Claude Code 的职责范围

- ✅ staging 部署为止
- ✅ CI 失败时的自动修复（最多 3 次）
- ❌ 生产部署禁止

### 3 次规则

CI 连续失败 3 次时：
1. 中止自动修复
2. 生成升级报告
3. 交给 Cursor 判断

---

## 常见问题

### Q: 没有 Cursor 怎么办？

A: 一个人工作时也推荐用 Plans.md 管理任务。
生产部署请手动谨慎进行。

### Q: 任务不明确怎么办？

A: 向 Cursor 请求确认，或用 `/sync-status` 整理现状。

### Q: CI 多次失败怎么办？

A: 3 次以上不要自动修复，请升级到 Cursor。

---

## 相关文档

- AGENTS.md - 详细的角色分工
- CLAUDE.md - Claude Code 特定设置
- Plans.md - 任务管理文件
