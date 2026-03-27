# Skill Catalog

Reference documentation for skill hierarchy, all category listings, and development skills.

## Skill Evaluation Flow

> For heavy tasks (parallel review, CI fix loops), skills use Task tool to launch sub-agents from `agents/` in parallel.

**Before starting work, always execute this flow:**

1. **Evaluate**: Check available skills and evaluate if any apply to this request
2. **Launch**: If a relevant skill exists, launch it with Skill tool before starting work
3. **Execute**: Proceed with work following skill procedures

```
User request
    ↓
Evaluate skills (is there a relevant one?)
    ↓
YES → Launch with Skill tool → Follow skill procedures
NO  → Handle with normal reasoning
```

## Skill Hierarchy

Skills have a hierarchical structure of **parent skills (categories)** and **child skills (specific features)**.

```
skills/
├── impl/                  # Implementation (feature addition, test creation)
├── harness-review/        # Review (quality, security, performance)
├── verify/                # Verification (build, error recovery, fix application)
├── setup/                 # Integration setup (project init, tool config, 2-Agent, harness-mem, Codex CLI, rule localization)
├── memory/                # Memory management (SSOT, decisions.md, patterns.md, SSOT promotion, memory search)
├── troubleshoot/          # Diagnosis and repair (including errors, CI failures)
├── principles/            # Principles and guidelines (VibeCoder, diff editing)
├── auth/                  # Authentication and payments (Clerk, Supabase, Stripe)
├── deploy/                # Deploy (Vercel, Netlify, analytics)
├── ui/                    # UI (components, feedback)
├── handoff/               # Workflow (handoff, auto-fix)
├── notebookLM/            # Documentation (NotebookLM, YAML)
└── maintenance/           # Maintenance (cleanup)
```

**Usage:**
1. Launch parent skill with Skill tool
2. Parent skill routes to appropriate child skill (doc.md) based on user intent
3. Execute work following child skill procedures

## All Skill Categories

| Category | Purpose | Trigger examples |
|----------|---------|------------------|
| work | Task implementation (auto scope detection, --codex support) | "implement", "do it all", "/work" |
| breezing | Agent Teams fully automated completion (--codex support) | "run with team", "breezing" |
| impl | Implementation, feature addition, test creation | "implement", "add feature", "write code" |
| harness-review | Code review, quality check | "review", "security", "performance" |
| verify | Build verification, error recovery | "build", "error recovery", "verify" |
| setup | Setup integration hub (project init, tool config, 2-Agent, harness-mem, Codex CLI, rule localization) | "setup", "CLAUDE.md", "initialize", "CI setup", "2-Agent", "Cursor config", "harness-mem", "codex-setup" |
| memory | SSOT management, memory search, SSOT promotion, Cursor integration memory | "SSOT", "decisions.md", "merge", "SSOT promotion", "memory search", "harness-mem" |
| principles | Development principles, guidelines | "principles", "VibeCoder", "safety" |
| auth | Authentication, payment features | "login", "Clerk", "Stripe", "payment" |
| deploy | Deploy, analytics | "deploy", "Vercel", "GA" |
| ui | UI component generation | "component", "hero", "form" |
| handoff | Handoff, auto-fix | "handoff", "report to PM", "auto-fix" |
| notebookLM | Document generation | "document", "NotebookLM", "slides" |
| troubleshoot | Diagnosis and repair (including CI failures) | "not working", "error", "CI failed" |
| maintenance | File cleanup | "cleanup", "clean up" |

## Development Skills (Private)

The following skills are for development/experimentation and are not included in the repository (excluded via .gitignore):

```
skills/
├── test-*/      # Test skills
└── x-promo/     # X post creation skill (development use)
```

These skills are only used in individual development environments and should not be included in plugin distribution.

## Related Documentation

- [CLAUDE.md](../CLAUDE.md) - Project Development Guide (overview)
- [docs/CLAUDE-feature-table.md](./CLAUDE-feature-table.md) - Claude Code New Feature Usage Table
- [docs/CLAUDE-commands.md](./CLAUDE-commands.md) - Major Commands List
- [.claude/rules/skill-editing.md](../.claude/rules/skill-editing.md) - Skill File Editing Rules
