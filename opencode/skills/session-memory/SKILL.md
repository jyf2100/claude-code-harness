---
name: session-memory
description: "管理跨会话学习和记忆持久化。Use when user asks about previous sessions, history, or to continue from before. Do NOT load for: implementation work, reviews, or ad-hoc information."
description-en: "Manages cross-session learning and memory persistence. Use when user asks about previous sessions, history, or to continue from before. Do NOT load for: implementation work, reviews, or ad-hoc information."
description-ja: "管理跨会话学习和记忆持久化。Use when user asks about previous sessions, history, or to continue from before. Do NOT load for: implementation work, reviews, or ad-hoc information."
allowed-tools: ["Read", "Write", "Edit"]
user-invocable: false
---

# Session Memory Skill

管理会话间学习和记忆的技能。
记录和参考过去的工作内容、决定事项、学到的模式。

---

## 触发短语

此技能在以下短语下自动启动：

- 「上次做了什么？」「从上次继续」
- 「给我看历史」「过去的工作」
- 「告诉我这个项目的情况」
- "what did we do last time?", "continue from before"

---

## 概要

此技能将工作历史保存到 `.claude/memory/`，
实现会话间的知识延续。

同时，明确重要信息「应该保存在哪里」（详情: `docs/MEMORY_POLICY.md`）。

---

## 内存结构

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

- **SSOT（共享推荐）**: `decisions.md` / `patterns.md`
  - 汇集「决定（Why）」和「可复用的解决方案（How）」
  - 每个条目附加 **标题 + 标签**（例: `#decision #db`），开头放置 **Index**
- **本地推荐**: `session-log.md` / `context.json` / `.claude/state/`
  - 容易产生噪音/膨胀，基本不进行 Git 管理（必要时个别判断）

---

## 自动记录的信息

### session-log.md

每个会话记录使用 `${CLAUDE_SESSION_ID}` 环境变量附加会话ID。
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

### 给下次的交接
- 登出功能未实现
- 还需要密码重置
```

> **Note**: `${CLAUDE_SESSION_ID}` 是 Claude Code 自动设置的环境变量。
> 每个会话分配唯一ID，有助于日志跟踪和问题调查。

### decisions.md

```markdown
## 技术选型

| 日期 | 决定事项 | 理由 |
|------|---------|------|
| 2024-01-15 | Supabase Auth | 有免费额度，设置简单 |
| 2024-01-14 | Next.js App Router | 最新的最佳实践 |

## 架构

- 组件: `src/components/`
- 工具函数: `src/lib/`
- 类型定义: `src/types/`
```

### patterns.md

```markdown
## 这个项目的模式

### 组件命名
- PascalCase
- 例: `UserProfile.tsx`, `LoginForm.tsx`

### API 端点
- `/api/v1/` 前缀
- RESTful 设计

### 错误处理
- 用 try-catch 包裹
- 错误信息使用中文
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
  "current_phase": "Phase 2: 核心功能",
  "last_session": "2024-01-15T14:30:00Z"
}
```

---

## 处理流程

### 会话开始时

1. 读取 `.claude/memory/context.json`
2. 确认上次会话日志
3. **从 Agent Trace 获取最近的编辑历史**
4. 确定未完成任务
5. 生成上下文摘要

**Agent Trace 应用**:
```bash
# 获取上次编辑的文件列表
tail -50 .claude/state/agent-trace.jsonl | jq -r '.files[].path' | sort -u

# 获取项目信息
tail -1 .claude/state/agent-trace.jsonl | jq '.metadata'
```

### 会话中

1. 记录重要决定到 `decisions.md`
2. 添加新模式到 `patterns.md`
3. 记录文件生成到 `session-log.md`

### 会话结束时

1. 生成会话摘要
2. 更新 `context.json`
3. 记录给下次的交接事项

---

## 内存优化（CC 2.1.49+）

Claude Code 2.1.49 以后，会话恢复时的内存使用量**减少了 68%**。

### 推荐工作流

```bash
# 长时间工作使用 --resume
claude --resume

# 大任务分割后会话恢复
claude --resume "继续"
```

| 场景 | 推荐 |
|---------|------|
| 长时间实现 | 每 1-2 小时会话恢复 |
| 大规模重构 | 按功能分割会话 |
| 内存不足警告 | 立即用 `--resume` 恢复 |

> 💡 内存效率大幅改善，请积极使用会话恢复。

---

## 使用示例

### 从上次继续开始

```
用户: 「从上次继续」

Claude Code:
📋 上次会话（2024-01-15）

完成的任务:
- 用户认证功能
- 登录页面

未完成:
- 登出功能
- 密码重置

说「创建登出功能」就会继续实现。
```

### 确认项目状况

```
用户: 「告诉我这个项目的情况」

Claude Code:
📁 项目: my-blog

技术栈:
- Next.js + Tailwind CSS + Supabase

当前阶段: 核心功能开发
进度: 40% 完成

最近的决定:
- 采用 Supabase Auth
- 使用 App Router
```

---

## 与 Claude Code 自动内存的关系（D22）

Claude Code 2.1.32+ 有「自动内存」功能，自动保存会话间的学习到 `~/.claude/projects/<project>/memory/MEMORY.md`。

与 Harness 的内存系统作为**3 层架构**共存:

| 层 | 系统 | 内容 | 管理 |
|----|---------|------|------|
| **Layer 1** | Claude Code 自动内存 | 通用学习（避免错误、工具用法） | 隐式/自动 |
| **Layer 2** | Harness SSOT | 项目固有决定事项/模式 | 显式/手动 |
| **Layer 3** | Agent Memory | 代理别任务学习 | 代理定义 |

**区分使用**:
- Layer 1 的知识对整个项目重要 → 用 `/memory ssot` 升级到 Layer 2
- 日常学习交给 Layer 1（不禁用）
- 使用 Agent Teams 时注意并行写入

详情: [D22: 3 层内存架构](../../.claude/memory/decisions.md#d22-3-layer-memory-architecture)

---

## 注意事项

- **自动保存**: 建议通过 `hooks/Stop` 在会话结束时自动追加摘要到 `session-log.md`（未导入时可手动运营）
- **隐私**: 不记录机密信息
- **Git 方针**: `decisions.md`/`patterns.md` 共享推荐，`session-log.md`/`context.json`/`.claude/state/` 本地推荐（详情: `docs/MEMORY_POLICY.md`）
- **容量管理**: 日志变大时推荐「整理会话日志」
