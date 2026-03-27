# Claude harness Architecture

## 1. Overview

`claude-code-harness` is a modular autonomous development framework to maximize Claude Code's capabilities. The core design philosophy supports the **Plan → Work → Review** systematic development cycle with three main extensions: **Skills**, **Rules**, and **Hooks**.

## 2. Three-Layer Architecture

This plugin adopts the following three-layer architecture to improve reusability and maintainability.

```mermaid
graph TD
    subgraph Profile Layer
        A[profiles/claude-worker.yaml]
    end
    subgraph Workflow Layer
        B[init.yaml, plan.yaml, work.yaml, review.yaml]
    end
    subgraph Skill Layer
        C[30+ SKILL.md files]
    end

    A -- references --> B;
    B -- uses --> C;
```

- **Skill Layer**: Self-contained knowledge units defined as `SKILL.md` files. Contains concrete procedures and knowledge for executing specific tasks (e.g., security review, code implementation).
- **Workflow Layer**: Defined as `*.yaml` files, orchestrates **Skills** for executing specific development phases (e.g., `/work`). Manages step ordering, conditional branching, error handling, etc.
- **Profile Layer**: Defines overall plugin behavior. Specifies which workflows to assign to which commands, which skill categories to allow, etc.

## 3. Directory Structure

```
claude-code-harness/
├── .claude-plugin/         # Plugin metadata
│   ├── plugin.json
│   └── hooks.json
├── skills/                 # Skill definitions (SKILL.md + references/)
│   ├── impl/               # Implementation skills
│   ├── harness-review/     # Review skills
│   ├── verify/             # Verification skills
│   ├── planning/           # Planning skills
│   ├── setup/              # Setup skills
│   ├── ci/                 # CI/CD related skills
│   └── ...                 # 30+ other skills
├── agents/                 # Sub-agent definitions (Markdown)
├── hooks/                  # Hooks definitions (hooks.json)
├── scripts/                # Shell scripts for automation
├── docs/                   # Documentation
└── templates/              # Various templates
```

## 4. Major Components

### 4.1. Skills

Each skill supports autonomous discovery and safe execution by Claude by clearly stating `description` (when to use) and `allowed-tools` (allowed tools).

### 4.2. Rules

Configuration files strictly defined in `claude-code-harness.config.schema.json` enforce safety (`dry-run` mode) and path restrictions (`protected` paths).

### 4.3. Hooks

Defined in `hooks.json`, automatically executes scripts at key points in the development process.
- **SessionStart**: Environment check at session start
- **PostToolUse**: Automatic testing and change tracking after file edits
- **Stop**: Summary generation at session end

### 4.4. Parallel Processing

The `/harness-review` command launches multiple `code-reviewer` sub-agents simultaneously, performing security, performance, and quality reviews in parallel, significantly reducing feedback time.
