---
name: session
description: "会话管理的综合窗口。一手包办初始化、记忆、状态。触发短语：管理 Claude Code 会话、/session 命令。不用于：应用用户会话、登录状态、认证功能。"
description-en: "Unified session management window. Handles initialization, memory, state all-in-one. Use when managing Claude Code sessions, /session command. Do NOT load for: app user sessions, login state, authentication features."
description-zh: "会话管理的综合窗口。一手包办初始化、记忆、状态。触发短语：管理 Claude Code 会话、/session 命令。不用于：应用用户会话、登录状态、认证功能。"
allowed-tools: ["Read", "Bash", "Write", "Edit", "Glob"]
argument-hint: "[list|inbox|broadcast \"message\"]"
---

# Session 技能（统一）

将所有会话相关功能整合到一个技能中。

## 用法

```bash
/session              # 显示可用选项
/session list         # 显示活跃会话
/session inbox        # 检查收件箱
/session broadcast "message"  # 向所有会话发送消息
```

## 子命令

### `/session list` - 列出活跃会话

显示当前项目中的所有活跃 Claude Code 会话。

```
📋 活跃会话

| 会话 ID | 状态 | 最后活动 |
|---------|------|---------|
| abc123  | 活跃 | 2 分钟前 |
| def456  | 空闲 | 15 分钟前 |
```

### `/session inbox` - 检查收件箱

检查来自其他会话的传入消息。

```
📬 会话收件箱

| 来源 | 时间 | 消息 |
|-----|------|------|
| abc123 | 5 分钟前 | "准备好审查" |
| def456 | 10 分钟前 | "API 实现完成" |
```

### `/session broadcast "message"` - 广播消息

向所有活跃会话发送消息。

```bash
/session broadcast "审查完成，准备合并"
```

---

## 功能

| 功能 | 说明 | 参考 |
|-----|------|------|
| **初始化** | 启动新会话、加载上下文 | 见 [../session-init/SKILL.md](../session-init/SKILL.md) |
| **记忆** | 跨会话持久化学习 | 见 [../session-memory/SKILL.md](../session-memory/SKILL.md) |
| **状态控制** | 基于标志恢复/分支会话 | 见 [references/session-control.md](${CLAUDE_SKILL_DIR}/references/session-control.md) |
| **通信** | 跨会话消息 | 见 [../session-state/SKILL.md](../session-state/SKILL.md) |

---

## 内存优化（CC 2.1.49+）

Claude Code 2.1.49 起，会话恢复时的内存使用量**减少 68%**。

### 长时间会话管理最佳实践

| 工作负载 | 推荐策略 |
|---------|---------|
| **常规实现** | 每 1-2 小时用 `--resume` 恢复 |
| **大规模重构** | 按功能分割会话 → 各会话用 `--resume` |
| **并行任务** | `/work all` 并行执行，长时间则中途 `--resume` |
| **内存警告时** | 立即用 `--resume` 恢复（比以前更快） |

### 会话名自动生成（CC 2.1.41+）

无参数运行 `/rename` 会从对话上下文自动生成会话名。
长时间会话或频繁使用 `--resume` 的工作流更容易识别会话。

### 高效工作流示例

```bash
# 实现阶段 1
claude "实现认证功能"
# → 1 小时后

# 会话恢复（内存高效）
claude --resume "添加密码重置功能"
# → 1 小时后

# 再次恢复
claude --resume "添加测试"
```

### 内存管理建议

| 建议 | 原因 |
|-----|------|
| **积极使用会话恢复** | 68% 内存减少，恢复成本低 |
| **定期恢复** | 整理上下文，保持专注 |
| **按功能分割** | 大任务分小后恢复 |
| **利用 Plans.md** | 恢复时交接更顺畅 |

> 💡 内存效率大幅改善，请积极使用会话恢复。

---

## 使用时机

- 会话初始化（`/harness-init`）
- 会话恢复/分支（`/work --resume`, `/work --fork`）
- 记忆持久化（自动）
- 跨会话通信（`/session broadcast`）

## 执行流程

### 1. 会话初始化

```
/harness-init
    ↓
├── 加载项目上下文
├── 初始化 session.json
├── 加载上次会话记忆（如存在）
└── 显示会话状态
```

### 2. 会话控制（从 /work）

```
/work --resume
    ↓
├── 检查 session.json 存在
├── 加载会话状态
└── 从上次检查点继续

/work --fork
    ↓
├── 创建新会话分支
├── 复制相关上下文
└── 带上下文重新开始
```

### 3. 记忆持久化

```
会话结束
    ↓
├── 提取学习（陷阱、模式）
├── 更新 .claude/memory/*.md
└── 准备交接摘要
```

### 4. 跨会话通信

```
/session broadcast "message"
    ↓
├── 查找活跃会话
├── 写入 session.events.jsonl
└── 通知所有会话
```

## 管理的文件

| 文件 | 用途 |
|-----|------|
| `.claude/state/session.json` | 当前会话状态 |
| `.claude/state/session.events.jsonl` | 跨会话通信事件日志 |
| `.claude/memory/*.md` | 持久化记忆文件 |

## 迁移说明

此技能整合了：
- `session-init` → 会话初始化
- `session-memory` → 记忆持久化
- `session-control` → 恢复/分支控制
- `session-state` → 状态管理和通信

各技能已废弃但为向后兼容仍可工作。
