---
name: session
description: "会话管理的综合窗口。一手承担初始化、记忆、状态管理。Use when managing Claude Code sessions, /session command. Do NOT load for: app user sessions, login state, authentication features."
description-en: "Unified session management window. Handles initialization, memory, state all-in-one. Use when managing Claude Code sessions, /session command. Do NOT load for: app user sessions, login state, authentication features."
description-ja: "会话管理的综合窗口。一手承担初始化、记忆、状态管理。Use when managing Claude Code sessions, /session command. Do NOT load for: app user sessions, login state, authentication features."
allowed-tools: ["Read", "Bash", "Write", "Edit", "Glob"]
argument-hint: "[list|inbox|broadcast \"message\"]"
---

# Session Skill (Unified)

Consolidates all session-related functionality into one skill.

## Usage

```bash
/session              # Show available options
/session list         # Show active sessions
/session inbox        # Check incoming messages
/session broadcast "message"  # Send message to all sessions
```

## Subcommands

### `/session list` - List Active Sessions

Shows all active Claude Code sessions in the current project.

```
📋 Active Sessions

| Session ID | Status | Last Activity |
|------------|--------|---------------|
| abc123     | active | 2 min ago     |
| def456     | idle   | 15 min ago    |
```

### `/session inbox` - Check Inbox

Checks for incoming messages from other sessions.

```
📬 Session Inbox

| From | Time | Message |
|------|------|---------|
| abc123 | 5m ago | "Ready for review" |
| def456 | 10m ago | "API implementation done" |
```

### `/session broadcast "message"` - Broadcast Message

Sends a message to all active sessions.

```bash
/session broadcast "Review complete, ready for merge"
```

---

## Capabilities

| Feature | Description | Reference |
|---------|-------------|-----------|
| **Initialization** | Start new session, load context | See [../session-init/SKILL.md](../session-init/SKILL.md) |
| **Memory** | Persist learnings across sessions | See [../session-memory/SKILL.md](../session-memory/SKILL.md) |
| **State Control** | Resume/fork session based on flags | See [references/session-control.md](${CLAUDE_SKILL_DIR}/references/session-control.md) |
| **Communication** | Cross-session messaging | See [../session-state/SKILL.md](../session-state/SKILL.md) |

---

## 内存优化（CC 2.1.49+）

Claude Code 2.1.49 以后，会话恢复时的内存使用量**减少了 68%**。

### 长时间会话管理的最佳实践

| 工作负载 | 推荐策略 |
|------------|---------|
| **常规实现** | 每 1-2 小时用 `--resume` 恢复 |
| **大规模重构** | 按功能分割会话 → 每个会话使用 `--resume` |
| **并行任务** | 用 `/work all` 并行执行，长时间则在途中 `--resume` |
| **内存警告时** | 立即用 `--resume` 恢复（比以前更快） |

### 会话名自动生成（CC 2.1.41+）

不带参数运行 `/rename` 会从对话上下文自动生成会话名。
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
| **积极使用会话恢复** | 68% 内存削减使恢复成本低 |
| **定期恢复** | 整理上下文，保持专注力 |
| **按功能分割** | 将大任务分成小块再恢复 |
| **活用 Plans.md** | 恢复时的交接更顺畅 |

> 💡 内存效率大幅改善，请积极使用会话恢复。

---

## When to Use

- Session initialization (`/harness-init`)
- Session resume/fork (`/work --resume`, `/work --fork`)
- Memory persistence (automatic)
- Cross-session communication (`/session broadcast`)

## Execution Flow

### 1. Session Initialization

```
/harness-init
    ↓
├── Load project context
├── Initialize session.json
├── Load previous session memory (if exists)
└── Display session status
```

### 2. Session Control (from /work)

```
/work --resume
    ↓
├── Check session.json exists
├── Load session state
└── Continue from last checkpoint

/work --fork
    ↓
├── Create new session branch
├── Copy relevant context
└── Start fresh with context
```

### 3. Memory Persistence

```
Session end
    ↓
├── Extract learnings (gotchas, patterns)
├── Update .claude/memory/*.md
└── Prepare handoff summary
```

### 4. Cross-Session Communication

```
/session broadcast "message"
    ↓
├── Find active sessions
├── Write to session.events.jsonl
└── Notify all sessions
```

## Files Managed

| File | Purpose |
|------|---------|
| `.claude/state/session.json` | Current session state |
| `.claude/state/session.events.jsonl` | Event log for cross-session communication |
| `.claude/memory/*.md` | Persistent memory files |

## Migration Note

This skill consolidates:
- `session-init` → Session initialization
- `session-memory` → Memory persistence
- `session-control` → Resume/fork control
- `session-state` → State management & communication

The individual skills are deprecated but still work for backward compatibility.
