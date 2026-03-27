# Phase 21 Release Checklist

Last Updated: 2026-03-06

This checklist is for release decisions involving `trust repair`, `evidence pack`, and `positioning refresh` changes.

## Surfaces

- [ ] `VERSION` and `.claude-plugin/plugin.json` are consistent
- [ ] README / README_ja use latest release badge
- [ ] No broken links in README / README_ja
- [ ] `docs/distribution-scope.md` and `Plans.md` descriptions are consistent
- [ ] `docs/claims-audit.md` classifications don't contradict this release's wording

## Evidence

- [ ] `./tests/validate-plugin.sh`
- [ ] `./tests/validate-plugin-v3.sh`
- [ ] `./scripts/ci/check-consistency.sh`
- [ ] `cd core && npm test`
- [ ] `./scripts/evidence/run-work-all-smoke.sh`
- [ ] If needed: `./scripts/evidence/run-work-all-success.sh --full`
- [ ] To demonstrate live Claude completion: `./scripts/evidence/run-work-all-success.sh --full --strict-live`
- [ ] If needed: `./scripts/evidence/run-work-all-failure.sh --full`

## Artifact Review

- [ ] `docs/evidence/work-all.md` description matches generated artifacts
- [ ] Reviewed latest artifacts in `out/evidence/work-all/`
- [ ] Note in release notes which of success / failure remains unverified

## Release Decision

- [ ] Determined whether this change requires release metadata update
- [ ] Obtained explicit approval for GitHub Release / tag creation
- [ ] Organized announcement text without mixing `trust repair`, `evidence pack`, `positioning refresh`

## Current Recommendation (2026-03-06)

- Release is possible if only evidence tooling with replay fallback is being released
- However, for strong claims about "live Claude running happy path to completion", obtain `--strict-live` artifacts first
