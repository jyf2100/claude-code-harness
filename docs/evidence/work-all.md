# `/harness-work all` Evidence Pack

Last Updated: 2026-03-06

This evidence pack is a minimal set for verifying `/harness-work all` claims by "what remains after execution".

## What is included

| Scenario | Goal | Expected result |
|----------|------|-----------------|
| success | Complete a small TODO repo via `work all` | Tests go green, additional commits remain |
| failure | Throw an impossible task and verify quality gate | Tests stay failed, no additional commits created |

## Fixtures

- `tests/fixtures/work-all-success/`
- `tests/fixtures/work-all-failure/`

Both are built so `npm test` fails at baseline.

## Smoke vs Full

| Mode | Command | What it does |
|------|---------|--------------|
| CI smoke | `./scripts/evidence/run-work-all-smoke.sh` | Verify fixture integrity and baseline failure, leave Claude execution command preview |
| Local full | `./scripts/evidence/run-work-all-success.sh --full` | Run success scenario with Claude CLI, complete artifact via replay overlay when rate limited |
| Local full (strict) | `./scripts/evidence/run-work-all-success.sh --full --strict-live` | Prove success with live Claude execution only, without replay |
| Local full | `./scripts/evidence/run-work-all-failure.sh --full` | Run failure scenario with Claude CLI, verify no commit increase |

Artifacts are saved to `out/evidence/work-all/` by default.

## Prerequisites for full runs

- `claude --version` works (required for strict live)
- Authenticated in Claude Code
- Run from this repo's root

Full mode uses these commands internally:

```bash
claude --plugin-dir /path/to/claude-code-harness \
  --dangerously-skip-permissions \
  --output-format json \
  --no-session-persistence \
  -p "$(cat PROMPT.md)"
```

## Saved artifacts

- `baseline-test.log`
- `claude-stdout.json`
- `claude-stderr.log`
- `elapsed-seconds.txt`
- `git-status.txt`
- `git-diff-stat.txt`
- `git-diff.patch`
- `git-log.txt`
- `commit-count.txt`
- `result.txt`
- `execution-mode.txt`
- `fallback-reason.txt`
- `rate-limit-detected.txt`
- `replay.log` (when rate limit fallback occurs)

## Interpretation

- For success: if `post_test_status=0` and `final_commits > baseline_commits`, this is evidence of "completed to commit in minimum scenario"
- For failure: if `post_test_status!=0` and `final_commits == baseline_commits`, this is at minimum evidence of "didn't hide failure and commit"
- If test tampering occurs in failure fixture, it remains in diff artifact, making quality gate behavior easy to review

## Live vs Replay

- If `execution_mode=live`, this is an artifact where Claude CLI completed the success scenario as-is
- If `execution_mode=replay-after-rate-limit`, this indicates Claude execution stopped due to rate limit and happy path artifact was created by applying replay overlay bundled with fixture
- To claim "proven with live Claude run" in public text, obtain separate `--strict-live` success artifact
