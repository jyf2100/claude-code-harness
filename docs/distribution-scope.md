# Distribution Scope

Last Updated: 2026-03-06

This document is a scope table for "things that exist in the `claude-code-harness` repo but may not always be distributed in the same form".
When in doubt in `Plans.md`, README, distribution scripts, or validation scripts, treat this table as the master copy.

## Scope Table

| Path | Status | Why it exists | Enforcement signal |
|------|--------|---------------|--------------------|
| `core/` | Distribution-included | TypeScript guardrail engine body | `core npm test`, README architecture |
| `skills-v3/` | Distribution-included | Current 5 verb skills | README, mirror sync checks |
| `agents-v3/` | Distribution-included | Current worker / reviewer / scaffolder | README, validate-plugin-v3 |
| `hooks/` | Distribution-included | Runtime guardrail and lifecycle hook | `hooks/hooks.json`, validate-plugin |
| `scripts/hook-handlers/memory-bridge.sh`, `scripts/hook-handlers/memory-*.sh` | Distribution-included | Bridge and wrapper for harness-mem integration. Hooks reference stable bridge, wrapper used for compatibility and testing | `validate-plugin`, `test-memory-hook-wiring.sh` |
| `templates/` | Distribution-included | Master for project init and rules distribution | `check-consistency.sh` |
| `commands/` | Compatibility-retained | Legacy slash command assets. Retained for compatibility verification and mirror/build | `tests/validate-plugin.sh`, `scripts/build-opencode.js` |
| `skills/` | Compatibility-retained | Legacy skill group. Migrated but retained for existing path compatibility | README architecture, codex mirror tests |
| `agents/` | Compatibility-retained | Legacy agent group. Retained for migrated path compatibility | README architecture |
| `codex/`, `opencode/` | Distribution-included | Mirror / setup paths for alternative clients | `tests/test-codex-package.sh`, `opencode-compat.yml` |
| `mcp-server/` | Development-only and distribution-excluded | Optional feature. Retained in repo for development/investigation but not included in distribution payload | `.gitignore`, CHANGELOG history |
| `harness-ui/`, `harness-ui-archive/` | Development-only and distribution-excluded | Optional UI experiments / legacy implementation storage | `.gitignore`, CHANGELOG history |
| `docs/research/`, `docs/private/` | Private reference | Comparison notes, investigation records, pre-public drafts | repo reference only |

## Current Decisions

- `commands/` is not treated as deleted. Currently **Compatibility-retained**.
- `mcp-server/` is not treated as deleted. Currently **Development-only and distribution-excluded**.
- `scripts/hook-handlers/memory-bridge.sh` and `memory-*.sh` are **Distribution-included** even as local bridges. Hooks reference them, so they must be tracked in repo.
- When writing "deleted" in README or `Plans.md`, only use when actually removed from tree.
- Use "not distributed", "compatibility maintained", "dev-only" according to this document's labels.

## Update Rule

When any of these occur, update this table in the same PR / commit:

1. Changed README architecture / install / compatibility explanations
2. Changed `.gitignore` or build script exclusion rules
3. Changed handling of directories whose existence reasons are easily misunderstood, like `commands/` or `mcp-server/`
