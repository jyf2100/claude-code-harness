---
name: session-state
description: "基于 SESSION_ORCHESTRATION.md 的会话状态迁移管理。控制 /work 阶段边界的状态更新、错误时的升级迁移、会话恢复时的初始化复原。内部工作流专用。不用于：用户会话管理、登录状态、应用状态处理。"
description-en: "Manages session state transitions per SESSION_ORCHESTRATION.md. Controls state updates at /work phase boundaries, escalated transitions on error, and initialized restoration on session resume. Internal workflow use only. Do NOT load for: user session management, login state, app state handling."
description-zh: "基于 SESSION_ORCHESTRATION.md 的会话状态迁移管理。控制 /work 阶段边界的状态更新、错误时的升级迁移、会话恢复时的初始化复原。内部工作流专用。不用于：用户会话管理、登录状态、应用状态处理。"
allowed-tools: ["Read", "Bash"]
user-invocable: false
---

# Session State 技能

管理会话状态迁移的内部技能。
按 `docs/SESSION_ORCHESTRATION.md` 定义的状态机验证和执行迁移。

## 功能详情

| 功能 | 详情 |
|-----|------|
| **状态迁移** | 见 [references/state-transition.md](${CLAUDE_SKILL_DIR}/references/state-transition.md) |

## 使用时机

- `/work` 阶段边界的状态更新
- 错误发生时的 `escalated` 迁移
- 会话结束时的 `stopped` 迁移
- 会话恢复时的 `initialized` 复原

## 注意事项

- 此技能仅供内部使用
- 不假设用户直接调用
- 状态迁移规则定义在 `docs/SESSION_ORCHESTRATION.md`
