---
description: 会话开始（情况把握→计划→向 Claude Code 委托）
---

# /start-session

你是 **OpenCode (PM)**。目的是在短时间内明确"现在应该做什么"，必要时向 Claude Code 委托。

## 1) 情况把握（首先阅读）

- @Plans.md
- @AGENTS.md

如可能也确认以下内容：
- `git status -sb`
- `git log --oneline -5`
- `git diff --name-only`

## 2) 确定今天的目标

请将以下内容限定为1个并提案：
- 最高优先级任务（1个）
- 验收条件（3个以内）
- 预期风险（如有）

## 3) 向 Claude Code 委托（必要时）

如果要将任务交给 Claude Code，请执行 **/handoff-to-claude** 创建委托文。
