# GitHub Harness Plugin Benchmark

Last Updated: 2026-03-06

This document is a dated snapshot comparing `claude-code-harness` against popular **Claude Code harness / workflow plugins** on GitHub from the perspective of **how standard operations change after adoption**.

- This is a **harness comparison**, not a **popularity contest**
- GitHub stars are only used as "reason for selecting comparison targets"
- First, list "what becomes standard after adoption", then explain the meaning of differences
- General AI coding agents (Aider, OpenHands, etc.) and curated lists are **excluded from this comparison table** because they are **not standalone harnesses**

## Compared Repositories

As of 2026-03-06, we targeted publicly available repos on GitHub that claim "multi-stage workflow / plugin / harness for Claude Code" with sufficient public information for comparison.

| Repo | GitHub stars | Included because |
|------|--------------|------------------|
| [obra/superpowers](https://github.com/obra/superpowers) | 71,993 | Most popular workflow / skills plugin. Cannot be excluded from comparison |
| [gotalab/cc-sdd](https://github.com/gotalab/cc-sdd) | 2,770 | Popular Claude Code harness emphasizing requirements-driven development flow |
| [Chachamaru127/claude-code-harness](https://github.com/Chachamaru127/claude-code-harness) | 232 | This repo |

## User-visible Comparison Table

Legend:

- `✅` Available as standard flow immediately after adoption
- `△` Possible with effort but not the main path
- `—` Not the main selling point

| What users care about | Claude Harness | Superpowers | cc-sdd |
|-----------------------|----------------|-------------|--------|
| Plans stay in repo, not lost in conversation | ✅ | ✅ | ✅ |
| Implementation proceeds in same flow after approval | ✅ | ✅ | △ |
| Review becomes standard process before completion | ✅ | ✅ | △ |
| Dangerous operations stopped by runtime guards | ✅ | △ | — |
| Verification can be re-run with same steps later | ✅ | △ | ✅ |
| After approval, can proceed end-to-end to completion | ✅ | △ | — |

## What These Differences Mean

### Claude Harness

- Strongest points are **standard flow solidification**, **runtime guards**, and **re-runnable verification**
- Plan → Work → Review exist as independent paths, with `/harness-work all` as a shortcut for batch execution
- Suited for those who want "proceed consistently every time with the same pattern" rather than "do something good each time"

### Superpowers

- Strongest points are **workflow breadth** and **clear onboarding story**
- Flow from planning, implementation, review to debugging is visible, and auto-triggers are strong
- However, mechanisms to stop dangerous operations with runtime rules or re-runnable evidence trails are not as front-and-center as standard flow compared to Harness

### cc-sdd

- Strongest point is **specification-driven discipline**
- `Requirements -> Design -> Tasks -> Implementation` flow is clear, with dry-run, validate-gap, and validate-design
- However, from the public side, independent review stages and batch execution paths are not as visible as standard flow compared to Harness

## README Presentation

In README or LP, this phrasing is natural:

> To expand your workflow repertoire, choose Superpowers.
> To strengthen requirements → design → tasks discipline, choose cc-sdd.
> To turn planning, implementation, review, and verification into resilient standard flows, choose Claude Harness.

## Assessment Notes

- `Plans stay in repo, not lost in conversation`
  - Harness: `Plans.md` / `/harness-plan`
  - Superpowers: brainstorming / writing-plans workflow
  - cc-sdd: requirements / design / tasks workflow
- `Implementation proceeds in same flow after approval`
  - Harness: `/harness-work --parallel`, Breezing, worker/reviewer flows become part of standard flow
  - Superpowers: parallel agent execution / subagent workflows are visible on public side
  - cc-sdd: Multiple subagents are confirmed in Claude agent variant, but not promoted as core feature in all usage patterns
- `Review becomes standard process before completion`
  - Harness: `/harness-review` and `/harness-work all`
  - Superpowers: code review workflow is explicit
  - cc-sdd: validate commands are explicit, but degree of presenting code review as independent stage is somewhat weaker
- `Dangerous operations stopped by runtime guards`
  - Harness: TypeScript guardrail engine + deny / warn rules
  - Superpowers: workflow discipline and hooks are visible, but compiled deny / warn runtime engine is not front-and-center
  - cc-sdd: Explicit runtime safety engine is hard to confirm in public README
- `Verification can be re-run with same steps later`
  - Harness: validate scripts + consistency checks + evidence pack
  - Superpowers: verify-oriented workflows exist but artifact pack is not front-and-center
  - cc-sdd: dry-run / validate-gap / validate-design exist
- `After approval, can proceed end-to-end to completion`
  - Harness: `/harness-work all`
  - Superpowers: auto-triggered workflow exists but published single command in same sense is not front-and-center
  - cc-sdd: spec-based command set exists but single path to wrap full loop after approval is not front-and-center

## Notes

- Stars change daily, so this table is a **dated snapshot**
- This comparison focuses on "user-visible harness feature differences" not "market popularity"
- There are axes where `Superpowers > Claude Harness`. Particularly ecosystem / adoption / workflow story strength is prominent
- There are axes where `cc-sdd > Claude Harness`. Particularly clarity of requirements-driven discipline is a strength
- When putting in README, writing **who it's suited for** is more natural than declaring winners/losers

## Evidence Used

### Local evidence

- [README.md](../README.md)
- [docs/claims-audit.md](claims-audit.md)
- [docs/distribution-scope.md](distribution-scope.md)
- [docs/evidence/work-all.md](evidence/work-all.md)

### Public GitHub sources

- [obra/superpowers](https://github.com/obra/superpowers)
- [gotalab/cc-sdd](https://github.com/gotalab/cc-sdd)
- [Chachamaru127/claude-code-harness](https://github.com/Chachamaru127/claude-code-harness)
