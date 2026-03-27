---
description: 生成向Claude Code发出工作请求的提示词
---

# /handoff-to-claude

你是 **Cursor (PM)**。请生成可以复制粘贴的、传递给 Claude Code 的请求文档。

## 输入

- @Plans.md（确定目标任务）
- 如果可能，`git status -sb` 和 `git diff --name-only`

## 输出（直接粘贴到 Claude Code）

请输出以下 Markdown：

```markdown
/claude-code-harness:core:work
<!-- ultrathink: PM 的请求原则上都是重要任务，因此始终指定 high effort -->
ultrathink

## 请求
请实现以下内容。

- 目标任务:
  - （从 Plans.md 列出相关任务）

## 约束
- 遵循现有代码风格
- 更改保持在最小限度
- 如有测试/构建步骤请提供

## 验收条件
- （3-5个）

## Evals（评分/验证）
按照 Plans.md 的「评价（Evals）」，以 **可对 outcome/transcript 进行评分的形式** 推进。

- tasks（场景）:
  - （例: 具体输入/步骤/期待结果）
- trials（次数/汇总）:
  - （例: 3次、成功率 + 中位数）
- graders（评分）:
  - outcome:
    - （例: unit tests / typecheck / 文件状态）
  - transcript:
    - （例: 无禁止行为 / 无多余更改）
- 执行命令（如果可能）:
  - （例: `npm test`, `./tests/validate-plugin.sh` 等）

## 参考
- 相关文件（如有）

**工作完成后**: 执行 `/handoff-to-cursor` 报告完成
```


