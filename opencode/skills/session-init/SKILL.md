---
name: session-init
description: "通过环境检查和任务状况概要进行会话初始化。Use when user mentions starting a session, beginning work, or status checks. Do NOT load for: implementation work, reviews, or mid-session tasks."
description-en: "Initializes session with environment checks and task status overview. Use when user mentions starting a session, beginning work, or status checks. Do NOT load for: implementation work, reviews, or mid-session tasks."
description-ja: "通过环境检查和任务状况概要进行会话初始化。Use when user mentions starting a session, beginning work, or status checks. Do NOT load for: implementation work, reviews, or mid-session tasks."
allowed-tools: ["Read", "Write", "Bash"]
user-invocable: false
---

# Session Init Skill

会话开始时的环境确认和当前任务状况把握技能。

---

## 触发短语

此技能在以下短语下启动：

- 「会话开始」
- 「开始工作」
- 「开始今天的工作」
- 「确认状况」
- 「该做什么？」
- "start session"
- "what should I work on?"

---

## 概要

Session Init 技能在 Claude Code 会话开始时自动确认以下内容：

1. **Git 状态**: 当前分支、未提交的变更
2. **Plans.md**: 进行中任务、被请求的任务
3. **AGENTS.md**: 角色分工、禁止事项的确认
4. **上次会话**: 交接事项的确认
5. **最新 snapshot**: 进度快照的摘要和上次差异

---

## 执行步骤

### Step 0: 文件状态检查（自动整理）

会话开始前检查文件大小：

```bash
# Plans.md 行数检查
if [ -f "Plans.md" ]; then
  lines=$(wc -l < Plans.md)
  if [ "$lines" -gt 200 ]; then
    echo "⚠️ Plans.md 有 ${lines} 行。建议用「整理」来整理"
  fi
fi

# session-log.md 行数检查
if [ -f ".claude/memory/session-log.md" ]; then
  lines=$(wc -l < .claude/memory/session-log.md)
  if [ "$lines" -gt 500 ]; then
    echo "⚠️ session-log.md 有 ${lines} 行。建议用「整理会话日志」来整理"
  fi
fi
```

需要整理时显示建议（不影响工作）。

### Step 0.5: 旧本地内存兼容的处理（可选）

当前标准是 Step 0.7 的 Unified Harness Memory。
旧本地内存兼容的确认原则上不需要，仅在需要特殊迁移确认时个别参考。

> **注**: 通常运营跳过此步骤，将共同 DB 的 Resume Pack 作为唯一的恢复入口。

### Step 0.7: Unified Harness Memory Resume Pack（必需）

从 Codex / Claude / OpenCode 共同 DB（`~/.harness-mem/harness-mem.db`）获取恢复上下文。

必需调用:

```text
harness_mem_resume_pack(project, session_id?, limit=5, include_private=false)
```

运营规则:
- `project` 必须指定当前项目名
- `session_id` 按 `$CLAUDE_SESSION_ID` → `.claude/state/session.json` 的 `.session_id` 的顺序获取
- `harness_mem_sessions_list(project, limit=1)` 的开头使用仅限于 read-only（resume 确认），不用于 `record_checkpoint` / `finalize_session` 的写入
- 获取结果注入会话开始时上下文
- 获取失败时用 `harness_mem_health()` 确认 daemon 状态，明确失败后继续
- 恢复按 `scripts/harness-memd doctor` → `scripts/harness-memd cleanup-stale` → `scripts/harness-memd start` 的顺序进行

### Step 1: 环境确认

并行执行以下内容：

```bash
# Git 状态
git status -sb
git log --oneline -3
```

```bash
# Plans.md
cat Plans.md 2>/dev/null || echo "Plans.md not found"
```

```bash
# AGENTS.md 要点
head -50 AGENTS.md 2>/dev/null || echo "AGENTS.md not found"
```

### Step 2: 把握任务状况

从 Plans.md 提取：

- `cc:WIP` - 从上次继续中的任务
- `pm:依頼中` - PM 新请求的任务（兼容: cursor:依頼中）
- `cc:TODO` - 未开始但已分配的任务

### Step 3: 输出状况报告

```markdown
## 🚀 会话开始

**日期**: {{YYYY-MM-DD HH:MM}}
**分支**: {{branch}}
**会话 ID**: ${CLAUDE_SESSION_ID}

---

### 📋 今天的任务

**优先任务**:
- {{pm:依頼中（兼容: cursor:依頼中） 或 cc:WIP 的任务}}

**其他任务**:
- {{cc:TODO 的任务列表}}

---

### ⚠️ 注意事项

{{来自 AGENTS.md 的重要约束/禁止事项}}

---

**开始工作吗？**
```

---

## 输出格式

会话开始时，简洁提供以下信息：

| 项目 | 内容 |
|------|------|
| 当前分支 | `staging` 等 |
| 优先任务 | 最重要的 1-2 件 |
| 注意事项 | 禁止事项摘要 |
| 下一步行动 | 具体建议 |

---

## 相关命令

- `/work` - 任务执行（支持并行执行）
- `/sync-status` - Plans.md 进度摘要
- `/maintenance` - 文件自动整理

---

## 注意事项

- **必须确认 AGENTS.md**: 把握角色分工后开始工作
- **没有 Plans.md 时**: 引导 `/harness-init`
- **上次工作中断时**: 确认是否继续
