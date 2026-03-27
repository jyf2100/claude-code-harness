---
name: session-control
description: "根据 --resume/--fork 标志控制 /work 的会话恢复/分支。更新 session.json 和 session.events.jsonl 的内部工作流专用技能。不用于：用户会话管理、登录状态、应用状态处理。"
description-en: "Controls session resume/fork(branch) for /work based on --resume/--fork flags. Updates session.json and session.events.jsonl. Internal workflow use only. Do NOT load for: user session management, login state, app state handling."
description-zh: "根据 --resume/--fork 标志控制 /work 的会话恢复/分支。更新 session.json 和 session.events.jsonl 的内部工作流专用技能。不用于：用户会话管理、登录状态、应用状态处理。"
allowed-tools: ["Read", "Bash", "Write", "Edit"]
user-invocable: false
---

# Session Control 技能

根据 /work 的 `--resume` / `--fork` 标志切换会话状态。

## 功能详情

| 功能 | 详情 |
|-----|------|
| **会话恢复/分支** | 见 [references/session-control.md](${CLAUDE_SKILL_DIR}/references/session-control.md) |

## 执行步骤

1. 确认从 workflow 传递的变量
2. 以适当参数执行 `scripts/session-control.sh`
3. 确认 `session.json` 和 `session.events.jsonl` 的更新
