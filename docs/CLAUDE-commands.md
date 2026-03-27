# Major Commands List

List of commands and handoffs used during Claude harness development.

## Major Commands (used during development)

| Command | Purpose |
|---------|---------|
| `/plan-with-agent` | Add improvement tasks to Plans.md |
| `/work` | Implement tasks (auto scope detection, --codex support) |
| `/breezing` | Team parallel completion with Agent Teams (--codex support) |
| `/reload-plugins` | Immediate reflection after skill/hook edits (no restart needed) |
| `/harness-review` | Review changes |
| `/validate` | Validate plugin |
| `/remember` | Record learning items |

## Handoffs

| Command | Purpose |
|---------|---------|
| `/handoff-to-cursor` | Completion report for Cursor operations |

**Skills (auto-launched in conversation)**:
- `handoff-to-impl` - "Hand off to implementer" → PM → Impl request
- `handoff-to-pm` - "Report completion to PM" → Impl → PM completion report

## Related Documentation

- [CLAUDE.md](../CLAUDE.md) - Project Development Guide
- [docs/CLAUDE-skill-catalog.md](./CLAUDE-skill-catalog.md) - Skill Catalog
- [docs/CLAUDE-feature-table.md](./CLAUDE-feature-table.md) - New Feature Usage Table
