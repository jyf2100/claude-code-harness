# Hardening Parity

Last Updated: 2026-03-25

This document is a common policy for organizing how Harness provides the same level of safety across **Claude Code** and **Codex CLI**.

Two key points:

- What is shared is the **policy** of "what to consider dangerous"
- Implementations are separated according to platform differences

Claude Code can be stopped immediately before and after execution via hooks.
Codex CLI doesn't have the same hooks, so it achieves similar effects through pre-execution instruction injection, post-execution quality gates, and pre-merge verification.

## Policy Matrix

| Policy | Example | Severity | Claude Code | Codex CLI |
|--------|---------|----------|-------------|-----------|
| No verification bypass | `git commit --no-verify`, `git commit --no-gpg-sign` | Deny | PreToolUse deny | Forbidden in instructions + quality gate fail |
| Protected branch destructive reset | `git reset --hard origin/main`, `git reset --hard main` | Deny | PreToolUse deny | Forbidden in instructions + quality gate fail |
| Direct push to protected branch | `git push origin main` | Warn | PreToolUse approve + warning | Forbidden in instructions, merge gate required |
| Force push | `git push --force`, `git push -f` | Deny | PreToolUse deny | Forbidden in instructions, merge gate required |
| Protected files editing | `package.json`, `Dockerfile`, `.github/workflows/*`, `schema.prisma` etc. | Warn | PreToolUse approve + warning | quality gate fail (stricter than Claude) |
| Pre-push secrets scan | hardcoded secret, DB URL, private IP, token-like string | Deny | deny or fail before push-equivalent Bash | quality gate fail |

## Protected Files Profile

Default protected files are limited to those that "have wide impact if broken but aren't touched in every normal implementation":

- `package.json`
- `Dockerfile`
- `docker-compose.yml`
- `.github/workflows/*.yml`
- `.github/workflows/*.yaml`
- `schema.prisma`
- `wrangler.toml`
- `index.html`

Design intent:

- **warn, not deny, as the default**
  Legitimate changes exist, so prioritize intent confirmation first
- **Clear sensitive/dangerous files like `.env` or private keys are denied via separate rules**
  This is the responsibility of existing protected path rules, not protected files
- **Codex CLI merge gate currently treats as fail**
  Since Codex cannot confirm via dialogue before execution, protected files are stopped more strictly in post-execution inspection

## Runtime Mapping

### Claude Code

Claude Code prioritizes runtime enforcement.

- **PreToolUse**
  Deny / ask / warn dangerous commands before execution
- **PostToolUse**
  Warn about post-write tampering and security patterns
- **PermissionRequest**
  Auto-approve safe read-only / test commands only

### Codex CLI

Since Codex CLI lacks runtime hooks, approximate enforcement is done through three layers:

1. **Pre-execution contract injection**
   Explicitly state prohibitions in instructions passed to `codex exec`, save the same contract in state artifact
2. **Post-execution quality gate**
   Inspect Worker outputs via diff / file / content basis
3. **Merge gate**
   Outputs that don't pass quality gate are not merged to main

## Known Asymmetry

This is important. They are not exactly the same.

| Item | Claude Code | Codex CLI |
|------|-------------|-----------|
| Pre-execution interruption | Possible | Not directly possible |
| Post-execution warning | Possible | Approximated via quality gate |
| Per-command deny | Strong | Depends on instructions + post-check |
| Pre-main integration blocking | Possible | Possible |
| protected files | warn-centered | fail-centered |
| direct push / force push | Runtime detectable | Runtime detection not possible, replaced by merge gate operation |

In summary:

- **Claude Code excels at stopping on the spot**
- **Codex CLI protects by not passing outputs through**

## Operator Guidance

- For safety-critical work, prioritize Claude Code path
- Use Codex CLI for implementation/review assistance, always pass through quality gate before main integration
- When working on protected files or release areas, understand that Codex side uses fail, not warning

## Validation Surface

At minimum, ensure these four points are in place and verifiable via `validate-plugin` series:

- Common policy document exists
- Claude Code guardrail has target rules
- Codex wrapper injects hardening contract
- Codex quality gate has parity checks
