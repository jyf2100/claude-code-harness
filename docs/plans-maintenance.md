# Plans Maintenance

Last Updated: 2026-03-06

`Plans.md` is the master copy, but leaving it to grow indefinitely causes drift between "past completion expressions" and "current repo state".
This document describes minimal operational rules to reduce drift.

## Lightweight Rule

1. Before starting a new major improvement phase, treat only the most recent 1-2 phases as active zone
2. For older completed phases, archive to `docs/plans-history/` or similar if needed
3. For phrases that conflict with current tree like "deleted", "migration complete", add correction notes when state changes in subsequent phases
4. When changing README / docs / `.gitignore` / build scripts handling, fix `Plans.md` expressions in the same commit

## When to Archive

Consider archiving old completed phases when any of these apply:

- Main work targets in `Plans.md` require looking back 3+ phases
- Words like "Deleted", "Integrated" cause misunderstandings with current repo
- Loading cost of past history becomes noticeable during sync-status

## Recommended Shape

- `Plans.md`: Current active phase and recent completed phases only
- `docs/plans-history/`: Fixed snapshots of past phases
- `docs/distribution-scope.md`: Current truth about residue and distribution boundaries

## Phase 21 Decision

- This time, archiving was not implemented; prioritized **correcting misleading completion expressions** first
- Before the next major phase addition, archiving Phase 17 and earlier completion history to `docs/plans-history/` is recommended
