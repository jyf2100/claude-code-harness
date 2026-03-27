---
name: session
description: "会话管理综合窗口。一手承担初始化、记忆、状态。Use when managing Codex Harness sessions or session command flows. Do NOT load for: app user sessions, login state, authentication features."
description-en: "Unified session management window. Handles initialization, memory, state all-in-one. Use when managing Codex Harness sessions or session command flows. Do NOT load for: app user sessions, login state, authentication features."
description-ja: "会话管理的综合窗口。一手承担初始化、记忆、状态。Use when managing Codex Harness sessions or session command flows. Do NOT load for: app user sessions, login state, authentication features."
allowed-tools: ["Read", "Bash", "Write", "Edit", "Glob"]
argument-hint: "[list|inbox|broadcast \"message\"]"
---

# Session Skill (Unified)

将所有会话相关功能整合到一个技能中。

## 使用方法

```bash
/session              # 显示可用选项
/session list         # 显示活动会话
/session inbox        # 检查收到的消息
/session broadcast "message"  # 向所有会话发送消息
```

## 子命令

### `/session list` - 列出活动会话

显示当前项目中的所有活动 Claude Code 会话。

```
📋 活动会话

| 会话 ID | 状态 | 最后活动 |
|------------|--------|---------------|
| abc123     | active | 2 分钟前     |
| def456     | idle   | 15 分钟前    |
```

### `/session inbox` - 检查收件箱

检查来自其他会话的传入消息。

```
📬 会话收件箱

| 发送者 | 时间 | 消息 |
|------|------|---------|
| abc123 | 5 分钟前 | "准备审查" |
| def456 | 10 分钟前 | "API 实现完成" |
```

### `/session broadcast "message"` - 广播消息

向所有活动会话发送消息。

```bash
/session broadcast "审查完成，准备合并"
```

---

## 功能

| 功能 | 描述 | 参考 |
|---------|-------------|-----------|
| **初始化** | 开始新会话，加载上下文 | 参考 [../session-init/SKILL.md](../session-init/SKILL.md) |
| **记忆** | 跨会话持久化学习内容 | 参考 [../session-memory/SKILL.md](../session-memory/SKILL.md) |
| **状态控制** | 基于标志恢复/分叉会话 | 参考 [references/session-control.md](${CLAUDE_SKILL_DIR}/references/session-control.md) |
| **通信** | 跨会话消息传递 | 参考 [../session-state/SKILL.md](../session-state/SKILL.md) |

---

## 内存优化（CC 2.1.49+）

Claude Code 2.1.49 起，会话恢复时的内存使用量减少了 **68%**。

### 长时间会话管理的最佳实践

| 工作负载 | 推荐策略 |
|------------|---------|
| **常规实现** | 每 1-2 小时用 `--resume` 恢复 |
| **大规模重构** | 按功能单位分割会话 → 各会话用 `--resume` |
| **并行任务** | 用 `$harness-work all` 或 `$breezing all` 执行，长时间则中途用 `--resume` |
| **内存警告时** | 立即用 `--resume` 恢复（比以前更快） |

### 会话名自动生成（CC 2.1.41+**

无参数执行 `/rename` 时，从会话上下文自动生成会话名。
在长时间会话或频繁使用 `--resume` 的工作流中更容易识别会话。

### 高效工作流示例

```bash
# 实现阶段 1
claude "实现认证功能"
# → 1 小时后

# 会话恢复（内存高效）
claude --resume "添加密码重置功能"
# → 1 小时后

# 继续恢复
claude --resume "添加测试"
```

### 内存管理推荐事项

| 推荐事项 | 理由 |
|---------|------|
| **积极使用会话恢复** | 68% 内存削减，恢复成本低 |
| **定期恢复** | 整理上下文，保持专注 |
| **按功能单位分割** | 大任务分割后恢复 |
| **利用 Plans.md** | 恢复时交接更顺畅 |

> 💡 内存效率大幅改善，请积极使用会话恢复。

---

## 使用时机

- 会话初始化（`$harness-setup init` 或 session-init）
- 会话恢复/分叉（`$harness-work --resume`、`$harness-work --fork`）
- 记忆持久化（自动）
- 跨会话通信（`/session broadcast`）

## 执行流程

### 1. 会话初始化

```
$harness-setup init
    ↓
├── 加载项目上下文
├── 初始化 session.json
├── 加载上次会话记忆（如存在）
└── 显示会话状态
```

### 2. 会话控制（从 $harness-work）

```
$harness-work --resume
    ↓
├── 检查 session.json 存在
├── 加载会话状态
└── 从上次检查点继续

$harness-work --fork
    ↓
├── 创建新会话分支
├── 复制相关上下文
└── 带上下文重新开始
```

### 3. 记忆持久化

```
会话结束
    ↓
├── 提取学习内容（gotchas、patterns）
├── 更新 .claude/memory/*.md
└── 准备交接摘要
```

### 4. 跨会话通信

```
/session broadcast "message"
    ↓
├── 查找活动会话
├── 写入 session.events.jsonl
└── 通知所有会话
```

## 管理的文件

| 文件 | 用途 |
|------|---------|
| `.claude/state/session.json` | 当前会话状态 |
| `.claude/state/session.events.jsonl` | 跨会话通信的事件日志 |
| `.claude/memory/*.md` | 持久化记忆文件 |

## 迁移说明

此技能整合了:
- `session-init` → 会话初始化
- `session-memory` → 记忆持久化
- `session-control` → 恢复/分叉控制
- `session-state` → 状态管理和通信

各独立技能已废弃但为向后兼容仍可工作。
