---
name: session-state
description: "基于 SESSION_ORCHESTRATION.md 的会话状态转换管理。控制 /work 阶段边界的状态更新、错误时的 escalated 转换、会话恢复时的 initialized 还原。Internal workflow use only. Do NOT load for: user session management, login state, app state handling."
description-en: "Manages session state transitions per SESSION_ORCHESTRATION.md. Controls state updates at /work phase boundaries, escalated transitions on error, and initialized restoration on session resume. Internal workflow use only. Do NOT load for: user session management, login state, app state handling."
description-ja: "基于 SESSION_ORCHESTRATION.md 的会话状态转换管理。控制 /work 阶段边界的状态更新、错误时的 escalated 转换、会话恢复时的 initialized 还原。Internal workflow use only. Do NOT load for: user session management, login state, app state handling."
allowed-tools: ["Read", "Bash"]
user-invocable: false
---

# Session State Skill

管理会话状态转换的内部技能。
按照 `docs/SESSION_ORCHESTRATION.md` 定义的状态机验证和执行转换。

## 功能详情

| 功能 | 详情 |
|------|------|
| **状态转换** | See [references/state-transition.md](${CLAUDE_SKILL_DIR}/references/state-transition.md) |

## 使用时机

- `/work` 阶段边界的状态更新
- 错误发生时的 `escalated` 转换
- 会话结束时的 `stopped` 转换
- 会话恢复时的 `initialized` 还原

## 注意事项

- 此技能仅供内部使用
- 不打算让用户直接调用
- 状态转换规则定义在 `docs/SESSION_ORCHESTRATION.md`
