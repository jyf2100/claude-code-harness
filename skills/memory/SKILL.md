---
name: memory
description: "管理 SSOT 和记忆，提供跨工具的记忆搜索。decisions.md 和 patterns.md 的守护者。触发短语：memory、SSOT、decisions.md、patterns.md、合并、迁移、SSOT 提升、同步记忆、保存学习、记忆搜索、harness-mem、过去决定、记录这个。不用于：实现工作、审查、临时笔记或会话内日志。"
description-en: "Manage SSOT, memory, and cross-tool memory search. Guardian of decisions.md and patterns.md. Use when user mentions memory, SSOT, decisions.md, patterns.md, merging, migration, SSOT promotion, sync memory, save learnings, memory search, harness-mem, past decisions, or record this. Do NOT load for: implementation work, reviews, ad-hoc notes, or in-session logging."
description-zh: "管理 SSOT 和记忆，提供跨工具的记忆搜索。decisions.md 和 patterns.md 的守护者。触发短语：memory、SSOT、decisions.md、patterns.md、合并、迁移、SSOT 提升、同步记忆、保存学习、记忆搜索、harness-mem、过去决定、记录这个。不用于：实现工作、审查、临时笔记或会话内日志。"
allowed-tools: ["Read", "Write", "Edit", "Bash", "mcp__harness__harness_mem_*"]
argument-hint: "[ssot|sync|migrate|search|record]"
context: fork
---

# Memory 技能

负责记忆和 SSOT 管理的技能群。

## 功能详情

| 功能 | 详情 |
|-----|------|
| **SSOT 初始化** | 见 [references/ssot-initialization.md](${CLAUDE_SKILL_DIR}/references/ssot-initialization.md) |
| **Plans.md 合并** | 见 [references/plans-merging.md](${CLAUDE_SKILL_DIR}/references/plans-merging.md) |
| **迁移处理** | 见 [references/workflow-migration.md](${CLAUDE_SKILL_DIR}/references/workflow-migration.md) |
| **项目规格同步** | 见 [references/sync-project-specs.md](${CLAUDE_SKILL_DIR}/references/sync-project-specs.md) |
| **记忆→SSOT 提升** | 见 [references/sync-ssot-from-memory.md](${CLAUDE_SKILL_DIR}/references/sync-ssot-from-memory.md) |

## Unified Harness Memory（公共 DB）

Claude Code / Codex / OpenCode 通用的记录和搜索优先使用 `harness_mem_*` MCP。

- 搜索: `harness_mem_search`, `harness_mem_timeline`, `harness_mem_get_observations`
- 注入: `harness_mem_resume_pack`
- 记录: `harness_mem_record_checkpoint`, `harness_mem_finalize_session`, `harness_mem_record_event`

## 与 Claude Code 自动记忆的关系（D22）

Harness 的 SSOT 记忆（Layer 2）与 Claude Code 的自动记忆（Layer 1）共存。
自动记忆隐式记录通用学习，SSOT 显式管理项目特定决定。
当 Layer 1 的知识对整个项目重要时，用 `/memory ssot` 升级到 Layer 2。

详细: [D22: 3 层记忆架构](../../.claude/memory/decisions.md#d22-3层记忆架构)

## 执行步骤

1. 分类用户请求
2. 从上述"功能详情"读取适当的参考文件
3. 按其内容执行

## SSOT 提升

将记忆系统（Claude-mem / Serena）中的重要学习永久保存到 SSOT。

- "**保存学到的内容**" → [references/sync-ssot-from-memory.md](${CLAUDE_SKILL_DIR}/references/sync-ssot-from-memory.md)
- "**将决定提升到 SSOT**" → [references/sync-ssot-from-memory.md](${CLAUDE_SKILL_DIR}/references/sync-ssot-from-memory.md)
