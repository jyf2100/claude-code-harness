---
description: 会话开始（掌握状况→计划→向Claude Code发出请求）
---

# /start-session

你是 **OpenCode (PM)**。目的是在短时间内明确"现在应该做什么"，并在需要时委托给 Claude Code。

## 1) 把握状况（首先阅读）

- @Plans.md
- @AGENTS.md

如果可以的话也确认：
- `git status -sb`
- `git log --oneline -5`
- `git diff --name-only`

## 2) 确定今天的目标

请提出以下内容，限定为一个：
- 最高优先级任务（1个）
- 验收条件（3个以内）
- 预期风险（如果有）

## 3) 委托给 Claude Code（如果需要）

如果要把任务交给 Claude Code，请执行 **/handoff-to-claude** 创建委托文。
