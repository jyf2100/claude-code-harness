---
name: memory
description: "管理 SSOT 与记忆，提供跨工具的记忆搜索。是 decisions.md 和 patterns.md 的守护者。Use when user mentions memory, SSOT, decisions.md, patterns.md, merging, migration, SSOT promotion, sync memory, save learnings, memory search, harness-mem, past decisions, or record this. Do NOT load for: implementation work, reviews, ad-hoc notes, or in-session logging."
description-en: "Manage SSOT, memory, and cross-tool memory search. Guardian of decisions.md and patterns.md. Use when user mentions memory, SSOT, decisions.md, patterns.md, merging, migration, SSOT promotion, sync memory, save learnings, memory search, harness-mem, past decisions, or record this. Do NOT load for: implementation work, reviews, ad-hoc notes, or in-session logging."
description-ja: "SSOTと記憶を管理し、ツール横断の記憶検索を提供。decisions.mdとpatterns.mdの守護者です。Use when user mentions memory, SSOT, decisions.md, patterns.md, merging, migration, SSOT promotion, sync memory, save learnings, memory search, harness-mem, past decisions, or record this. Do NOT load for: implementation work, reviews, ad-hoc notes, or in-session logging."
allowed-tools: ["Read", "Write", "Edit", "Bash", "mcp__harness__harness_mem_*"]
argument-hint: "[ssot|sync|migrate|search|record]"
context: fork
---

# Memory Skills

负责内存和 SSOT 管理的技能集合。

## 功能详情

| 功能 | 详情 |
|------|------|
| **SSOT 初始化** | See [references/ssot-initialization.md](${CLAUDE_SKILL_DIR}/references/ssot-initialization.md) |
| **Plans.md 合并** | See [references/plans-merging.md](${CLAUDE_SKILL_DIR}/references/plans-merging.md) |
| **迁移处理** | See [references/workflow-migration.md](${CLAUDE_SKILL_DIR}/references/workflow-migration.md) |
| **项目规范同步** | See [references/sync-project-specs.md](${CLAUDE_SKILL_DIR}/references/sync-project-specs.md) |
| **内存 → SSOT 提升** | See [references/sync-ssot-from-memory.md](${CLAUDE_SKILL_DIR}/references/sync-ssot-from-memory.md) |

## Unified Harness Memory（通用 DB）

Claude Code / Codex / OpenCode 通用的记录和搜索优先使用 `harness_mem_*` MCP。

- 搜索: `harness_mem_search`, `harness_mem_timeline`, `harness_mem_get_observations`
- 注入: `harness_mem_resume_pack`
- 记录: `harness_mem_record_checkpoint`, `harness_mem_finalize_session`, `harness_mem_record_event`

## 与 Claude Code 自动内存的关系（D22）

Harness 的 SSOT 内存（Layer 2）与 Claude Code 的自动内存（Layer 1）共存。
自动内存隐式记录通用学习，SSOT 显式管理项目特有的决策。
当 Layer 1 的知识对整个项目重要时，请通过 `/memory ssot` 提升到 Layer 2。

详情: [D22: 3 层内存架构](../../.claude/memory/decisions.md#d22-3层内存架构)

## 执行步骤

1. 分类用户请求
2. 从上述"功能详情"读取相应的参考文件
3. 按照其内容执行

## SSOT 提升

将重要学习从内存系统（Claude-mem / Serena）持久化到 SSOT。

- "**Save what we learned**" → [references/sync-ssot-from-memory.md](${CLAUDE_SKILL_DIR}/references/sync-ssot-from-memory.md)
- "**Promote decisions to SSOT**" → [references/sync-ssot-from-memory.md](${CLAUDE_SKILL_DIR}/references/sync-ssot-from-memory.md)
