---
name: principles
description: "提供开发原则、指南和 VibeCoder 指导。Use when user mentions principles, guidelines, safety, or diff-aware editing. Do not use for actual implementation—use the impl skill instead."
description-en: "Provides development principles, guidelines, and VibeCoder guidance. Use when user mentions principles, guidelines, safety, or diff-aware editing. Do not use for actual implementation—use the impl skill instead."
description-ja: "提供开发原则、指南和 VibeCoder 指导。Use when user mentions principles, guidelines, safety, or diff-aware editing. Do not use for actual implementation—use the impl skill instead."
allowed-tools: ["Read"]
user-invocable: false
---

# Principles Skills

提供开发原则和指南的技能群。

## 功能详情

| 功能 | 详情 |
|------|------|
| **基本原则** | See [references/general-principles.md](${CLAUDE_SKILL_DIR}/references/general-principles.md) |
| **差分编辑** | See [references/diff-aware-editing.md](${CLAUDE_SKILL_DIR}/references/diff-aware-editing.md) |
| **上下文读取** | See [references/repo-context-reading.md](${CLAUDE_SKILL_DIR}/references/repo-context-reading.md) |
| **VibeCoder** | See [references/vibecoder-guide.md](${CLAUDE_SKILL_DIR}/references/vibecoder-guide.md) |

## 执行步骤

1. 分类用户请求
2. 从上述「功能详情」读取适当的参考文件
3. 参考并应用其内容
