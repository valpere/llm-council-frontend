---
name: fix-review
description: Address Copilot review comments on the current open PR. Reads all unresolved comments, prioritises by Code Review Pyramid layer, implements fixes, pushes, and confirms the PR is clean. One round only — do not re-check after pushing. Invoke after Copilot has commented on a PR.
user-invocable: true
argument-hint: "[pr-number] — defaults to the PR for the current branch"
metadata:
  version: "1.1"
  author: frontend-claude
  last_updated: "2026-03-21"
---

# /fix-review

## Rules

- Process **one round** of Copilot comments only. Do not loop waiting for a second review.
- Ignore comments from Dependabot and other bots — only act on Copilot (github-advanced-security, copilot-pull-request-reviewer).
- If a comment requests something that conflicts with project decisions (CLAUDE.md, memory), note the conflict and skip rather than blindly applying.
- If the PR has no unresolved Copilot comments, report that and stop.

## Code Review Pyramid — Prioritisation

When multiple comments exist, address them in this order (highest impact first):

| Layer | Concern | Examples |
|-------|---------|---------|
| 1 (highest) | Architecture & design | Wrong abstraction, breaking state contract, SSE adapter boundary violation |
| 2 | Correctness | Bugs, null handling gaps, missing error branches, race conditions, security |
| 3 | Documentation | Complex logic without comment, misleading naming, undocumented non-obvious behaviour |
| 4 (skip) | Style | Formatting — automated by ESLint, do not hand-fix |

*(No Layer 4 Tests — project has no test suite.)*

For each Copilot comment, assign a ruling before deciding what to do:

| Ruling | Meaning | Action |
|--------|---------|--------|
| **CONFIRM** | Real issue, model was right | Fix it |
| **ESCALATE** | Real issue, more severe than flagged | Fix it, note severity upgrade |
| **DISMISS** | False positive or conflicts with project patterns (CLAUDE.md) | Skip, note reason |
| **DEFER** | Real but out of scope for this PR | Log only, do not fix |

Apply rulings before writing any code. DISMISS saves time; DEFER keeps scope clean.

## Steps

1. **Find the PR** — use the argument if given, otherwise detect from current branch:
   ```bash
   gh pr view --json number,title,headRefName
   ```

2. **Read all Copilot comments:**
   ```bash
   gh pr view <number> --json reviews,comments
   gh api repos/{owner}/{repo}/pulls/<number>/comments
   ```
   Filter to comments from `copilot-pull-request-reviewer` or `github-advanced-security`.

3. **Implement fixes** — read the relevant files, apply changes. Keep fixes minimal (⚡ scope unless the comment explicitly requests more). Do not refactor surrounding code.

4. **Lint:**
   ```bash
   npm run lint
   ```
   Fix any new lint errors introduced.

5. **Commit and push:**
   ```bash
   git add <changed files>
   git commit -m "fix-review: address Copilot comments"
   git push
   ```

6. **Report** — list each comment addressed and what was done. Note any comments skipped and why.

## What NOT to do

- Do not merge the PR — that is `/ship`'s job.
- Do not wait for a new Copilot review cycle.
- Do not open new issues or PRs.
