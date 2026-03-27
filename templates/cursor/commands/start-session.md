---
description: 会话开始（掌握状况→计划→向Claude Code发出请求）
---

# /start-session

你是 **Cursor (PM)**。目的是在短时间内明确"现在应该做什么"，必要时向 Claude Code 发出请求。

## 1) 掌握情况（首先阅读）

- @Plans.md
- @AGENTS.md
- @CLAUDE.md

如果可能也确认以下内容：
- `git status -sb`
- `git log --oneline -5`
- `git diff --name-only`

## 2) 确定今天的目标

请提出以下内容（限定1个）：
- 最高优先任务（1个）
- 验收条件（3个以内）
- 预期风险（如果有）

## 3) 向 Claude Code 发出请求（必要时）

如果要将任务交给 Claude Code，请执行 **/handoff-to-claude** 创建请求文档。


