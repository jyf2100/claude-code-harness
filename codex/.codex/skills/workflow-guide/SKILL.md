---
name: workflow-guide
description: "提供 Cursor ↔ Claude Code 2-Agent 工作流指导。Use when user asks about workflow, collaboration, or process. Do NOT load for: implementation work, workflow setup, or executing handoffs."
description-en: "Provides guidance on Cursor ↔ Claude Code 2-agent workflow. Use when user asks about workflow, collaboration, or process. Do NOT load for: implementation work, workflow setup, or executing handoffs."
description-ja: "Cursor ↔ Claude Code 2-Agentワークフローのガイダンスを提供。Use when user asks about workflow, collaboration, or process. Do NOT load for: implementation work, workflow setup, or executing handoffs."
allowed-tools: ["Read"]
user-invocable: false
---

# Workflow Guide Skill

提供 Cursor ↔ Claude Code 2-Agent 工作流指导的技能。

---

## 触发短语

此技能在以下短语时启动：

- "告诉我关于工作流"
- "Cursor 的协作方式是？"
- "告诉我工作的流程"
- "该如何进行？"
- "how does the workflow work?"
- "explain 2-agent workflow"

---

## 概要

此技能说明 Cursor（PM）和 Claude Code（Worker）的角色分工和协作方法。

---

## 2-Agent 工作流

### 角色分工

| 代理 | 角色 | 职责 |
|-------------|------|------|
| **Cursor** | PM（项目经理） | 任务分配、审查、生产部署判断 |
| **Claude Code** | Worker（工作者） | 实现、测试、CI 修正、staging 部署 |

### 工作流图

```
┌─────────────────────────────────────────────────────────┐
│                    Cursor (PM)                          │
│  ・向 Plans.md 添加任务                                  │
│  ・向 Claude Code 请求工作（/handoff-to-claude）          │
│  ・审查完成报告                                          │
│  ・判断生产部署                                          │
└─────────────────────┬───────────────────────────────────┘
                      │ 任务请求
                      ▼
┌─────────────────────────────────────────────────────────┐
│                  Claude Code (Worker)                   │
│  ・用 $harness-work / $breezing 执行任务                 │
│  ・实现 → 测试 → 提交                                    │
│  ・CI 失败时自动修正（最多 3 次）                         │
│  ・用 /handoff-to-cursor 报告完成                        │
└─────────────────────┬───────────────────────────────────┘
                      │ 完成报告
                      ▼
┌─────────────────────────────────────────────────────────┐
│                    Cursor (PM)                          │
│  ・确认变更内容                                          │
│  ・staging 运行确认                                      │
│  ・执行生产部署（批准后）                                 │
└─────────────────────────────────────────────────────────┘
```

---

## Plans.md 任务管理

### 标记列表

| 标记 | 含义 | 设置者 |
|---------|------|--------|
| `pm:依頼中` | PM 请求（兼容: cursor:依頼中） | PM（Cursor/PM Claude） |
| `cc:TODO` | Claude Code 未开始 | 两者均可 |
| `cc:WIP` | Claude Code 进行中 | Claude Code |
| `cc:完了` | Claude Code 完成 | Claude Code |
| `pm:確認済` | PM 确认完成（兼容: cursor:確認済） | PM（Cursor/PM Claude） |
| `cursor:依頼中` | （兼容）与 pm:依頼中 同义 | Cursor |
| `cursor:確認済` | （兼容）与 pm:確認済 同义 | Cursor |
| `blocked` | 阻塞中 | 两者均可 |

### 任务状态迁移

```
pm:依頼中 → cc:WIP → cc:完了 → pm:確認済
```

---

## 主要命令

### Claude Code 侧

| 命令 | 用途 |
|---------|------|
| `$harness-setup init` | 项目设置 |
| `$harness-plan` | 规划・任务分解 |
| `$harness-work` / `$breezing` | 执行任务（根据需要并行执行） |
| `/handoff-to-cursor` | 完成报告（向 Cursor PM） |
| `$harness-sync` | 状态确认 |

### 技能（会话中自动启动）

| 技能 | 触发示例 |
|--------|-----------|
| `handoff-to-pm` | "向 PM 报告完成" |
| `handoff-to-impl` | "交给实现者" |

### Cursor 侧（参考）

| 命令 | 用途 |
|---------|------|
| `/handoff-to-claude` | 向 Claude Code 请求任务 |
| `/review-cc-work` | 审查完成报告 |

---

## CI/CD 规则

### Claude Code 的职责范围

- ✅ 到 staging 部署
- ✅ CI 失败时自动修正（最多 3 次）
- ❌ 禁止生产部署

### 3 次规则

CI 连续失败 3 次时：
1. 停止自动修正
2. 生成升级报告
3. 交由 Cursor 判断

---

## 常见问题

### Q: Cursor 不在怎么办？

A: 单人工作时也推荐用 Plans.md 管理任务。
生产部署请手动谨慎进行。

### Q: 任务不明确怎么办？

A: 请向 Cursor 确认，或用 `$harness-sync` 整理现状。

### Q: CI 多次失败怎么办？

A: 超过 3 次不自动修正，请升级到 Cursor。

---

## 相关文档

- AGENTS.md - 详细角色分工
- CLAUDE.md - Claude Code 固有设置
- Plans.md - 任务管理文件
