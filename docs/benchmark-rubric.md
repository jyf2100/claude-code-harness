# Benchmark Rubric

Last Updated: 2026-03-06

This document is a rerunnable rubric when comparing `claude-code-harness` with other tools.
Rather than README impressions, it scores static evidence and executed evidence separately.

## Evidence Classes

| Class | Example | When to use |
|-------|---------|-------------|
| Static evidence | README, repo tree, hooks definitions, tests, docs, package metadata | Comparing mechanism presence, design clarity, distribution paths |
| Executed evidence | test run, smoke run, benchmark logs, evidence pack, CI artifact | Comparing claim reproducibility, actual guardrail effectiveness |

## Scoring Axes

| Axis | Weight | What to inspect |
|------|--------|-----------------|
| Runtime enforcement | 25 | Hooks, guardrails, deny/warn behavior, lifecycle automation |
| Verification and test credibility | 25 | Unit/integration tests, consistency checks, evidence pack, CI coverage |
| Onboarding and operator clarity | 20 | install flow, docs completeness, claim consistency, quickstart quality |
| Scope discipline and maintainability | 15 | distribution boundary, compatibility story, residue management |
| Positioning and adoption proof | 15 | public narrative, stars/users, reproducible showcase, differentiation |

Total: 100 points

## Review Flow

1. Collect static evidence
2. List claims that need executed evidence
3. Separate claims that were executed vs. claims that remain unexecuted and pending
4. Score each axis, noting evidence class
5. Write strengths and weaknesses separately, like "strong design but unproven" or "strong market but thin runtime enforcement"

## Required Output Format

Comparison reports must include at minimum:

- Comparison date/time
- Target repos / versions / commit or default branch snapshot
- List of commands executed
- Static evidence vs. Executed evidence classification
- Per-axis scores
- Items that could not be reproduced

## Reusable Template

```md
# Benchmark Report

- Compared at:
- Repositories / versions:
- Commands executed:

## Static evidence

- Repo structure:
- Docs and claims:
- Guardrails / hooks / tests:

## Executed evidence

- Validation commands:
- Benchmark or smoke runs:
- Evidence artifacts:

## Scores

| Axis | Score | Evidence type | Notes |
|------|-------|---------------|-------|
| Runtime enforcement |  | Static / Executed |  |
| Verification and test credibility |  | Static / Executed |  |
| Onboarding and operator clarity |  | Static / Executed |  |
| Scope discipline and maintainability |  | Static / Executed |  |
| Positioning and adoption proof |  | Static / Executed |  |

## Unverified or blocked items

- None

## Harness-specific Notes

- Strong claims like `/harness-work all` are scored high only after execution evidence in `docs/evidence/work-all.md` is complete
- Residue like `commands/` or `mcp-server/` is not a deduction target, **only deducted when explanation is ambiguous**
- If README claims don't align with tests/CI/distribution boundaries, lower `Onboarding and operator clarity`
```
