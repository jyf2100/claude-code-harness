---
name: session-memory
description: "管理会话间的学习和记忆持久化。触发短语：上次做了什么、从上次继续、历史记录、过去的工作、关于这个项目。不用于：实现工作、审查、临时信息。"
description-en: "Manages cross-session learning and memory persistence. Use when user asks about previous sessions, history, or to continue from before. Do NOT load for: implementation work, reviews, or ad-hoc information."
description-zh: "管理会话间的学习和记忆持久化。触发短语：上次做了什么、从上次继续、历史记录、过去的工作、关于这个项目。不用于：实现工作、审查、临时信息。"
allowed-tools: ["Read", "Write", "Edit"]
user-invocable: false
---

# Session Memory 技能

管理会话间学习和记忆的技能。
记录和参照过去的工作内容、决定事项、学到的模式。

---

## 触发短语

此技能由以下短语自动启动：

- "上次做了什么"、"从上次继续"
- "看历史记录"、"过去的工作"
- "介绍一下这个项目"
- "what did we do last time?", "continue from before"

---

## 概要

此技能将工作历史保存到 `.claude/memory/`，
实现会话间的知识延续。

同时明确重要信息"应该保存在哪里"（详见：`docs/MEMORY_POLICY.md`）。

---

## 记忆结构

```
.claude/
├── memory/
│   ├── session-log.md      # 每个会话的日志
│   ├── decisions.md        # 重要决定事项
│   ├── patterns.md         # 学到的模式
│   └── context.json        # 项目上下文
└── state/
    └── agent-trace.jsonl   # Agent Trace（工具执行历史）
```

### 推荐运营（SSOT/本地分离）

- **SSOT（推荐共享）**: `decisions.md` / `patterns.md`
  - 集中"决定（Why）"和"可复用的解法（How）"
  - 每个条目附加 **标题 + 标签**（例：`#decision #db`），开头放置 **Index**
- **推荐本地**: `session-log.md` / `context.json` / `.claude/state/`
  - 容易产生噪音/膨胀，原则上不进行 Git 管理（必要时个别判断）

---

## 自动记录的信息

### session-log.md

每个会话记录使用 `${CLAUDE_SESSION_ID}` 环境变量附加会话 ID。
这样可以提高会话间的可追溯性。

```markdown
## 会话: 2024-01-15 14:30 (session: abc123def)

### 执行的任务
- [x] 实现用户认证功能
- [x] 创建登录页面

### 生成的文件
- src/lib/auth.ts
- src/app/login/page.tsx

### 重要决定
- 认证方式: 采用 Supabase Auth

### 下次交接
- 登出功能未实现
- 还需要密码重置
```

> **注意**: `${CLAUDE_SESSION_ID}` 是 Claude Code 自动设置的环境变量。
> 每个会话分配唯一 ID，有助于日志跟踪和问题调查。

### decisions.md

```markdown
## 技术选型

| 日期 | 决定事项 | 原因 |
|-----|---------|------|
| 2024-01-15 | Supabase Auth | 有免费额度，设置简单 |
| 2024-01-14 | Next.js App Router | 最新最佳实践 |

## 架构

- 组件: `src/components/`
- 工具函数: `src/lib/`
- 类型定义: `src/types/`
```

### patterns.md

```markdown
## 本项目的模式

### 组件命名
- PascalCase
- 例: `UserProfile.tsx`, `LoginForm.tsx`

### API 端点
- `/api/v1/` 前缀
- RESTful 设计

### 错误处理
- 用 try-catch 包围
- 错误消息使用中文
```

### context.json

```json
{
  "project_name": "my-blog",
  "created_at": "2024-01-14",
  "stack": {
    "frontend": "next.js",
    "backend": "next-api",
    "database": "supabase",
    "styling": "tailwind"
  },
  "current_phase": "阶段 2: 核心功能",
  "last_session": "2024-01-15T14:30:00Z"
}
```

---

## 处理流程

### 会话开始时

1. 读取 `.claude/memory/context.json`
2. 确认上次会话日志
3. **从 Agent Trace 获取最近编辑历史**
4. 确定未完成任务
5. 生成上下文摘要

**Agent Trace 活用**:
```bash
# 获取上次编辑的文件列表
tail -50 .claude/state/agent-trace.jsonl | jq -r '.files[].path' | sort -u

# 获取项目信息
tail -1 .claude/state/agent-trace.jsonl | jq '.metadata'
```

### 会话中

1. 将重要决定记录到 `decisions.md`
2. 向 `patterns.md` 添加新模式
3. 将文件生成记录到 `session-log.md`

### 会话结束时

1. 生成会话摘要
2. 更新 `context.json`
3. 记录下次交接事项

---

## 内存优化（CC 2.1.49+）

Claude Code 2.1.49 起，会话恢复时的内存使用量**减少 68%**。

### 推荐工作流

```bash
# 长时间工作使用 --resume
claude --resume

# 大任务分割后会话恢复
claude --resume "从上次继续"
```

| 场景 | 推荐 |
|-----|------|
| 长时间实现 | 每 1-2 小时会话恢复 |
| 大规模重构 | 按功能分割会话 |
| 内存不足警告 | 立即用 `--resume` 恢复 |

> 💡 内存效率大幅改善，请积极使用会话恢复。

---

## 使用示例

### 从上次继续开始

```
用户: "从上次继续"

Claude Code:
📋 上次会话（2024-01-15）

完成的任务:
- 用户认证功能
- 登录页面

未完成:
- 登出功能
- 密码重置

说"创建登出功能"就可以继续实现。
```

### 确认项目状况

```
用户: "介绍一下这个项目"

Claude Code:
📁 项目: my-blog

技术栈:
- Next.js + Tailwind CSS + Supabase

当前阶段: 核心功能开发
进度: 40% 完成

最近决定:
- 采用 Supabase Auth
- 使用 App Router
```

---

## 与 Claude Code 自动记忆的关系（D22）

Claude Code 2.1.32+ 有"自动记忆"功能，会自动将跨会话学习保存到 `~/.claude/projects/<project>/memory/MEMORY.md`。

与 Harness 的记忆系统以**3 层架构**共存：

| 层 | 系统 | 内容 | 管理 |
|----|------|------|------|
| **Layer 1** | Claude Code 自动记忆 | 通用学习（避免错误、工具用法） | 隐式、自动 |
| **Layer 2** | Harness SSOT | 项目特定决定事项、模式 | 显式、手动 |
| **Layer 3** | Agent Memory | 代理特定任务学习 | 代理定义 |

**使用区分**:
- Layer 1 的知识对整个项目重要 → 用 `/memory ssot` 升级到 Layer 2
- 日常学习交给 Layer 1（不禁用）
- 使用 Agent Teams 时注意并行写入

详细: [D22: 3 层记忆架构](../../.claude/memory/decisions.md#d22-3层记忆架构)

---

## 注意事项

- **自动保存**: 推荐通过 `hooks/Stop` 在会话结束时自动向 `session-log.md` 追加摘要（未引入时可手动运营）
- **隐私**: 不记录机密信息
- **Git 策略**: `decisions.md`/`patterns.md` 推荐共享，`session-log.md`/`context.json`/`.claude/state/` 推荐本地（详见：`docs/MEMORY_POLICY.md`）
- **容量管理**: 日志变大时推荐"整理会话日志"
