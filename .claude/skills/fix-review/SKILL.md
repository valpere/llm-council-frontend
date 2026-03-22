---
name: fix-review
description: Address Copilot review comments on the current open PR, or review and merge a Dependabot PR. For Dependabot: checks semver bump level, changelog, and breaking changes before merging. No Copilot wait required.
user-invocable: true
argument-hint: "[pr-number] — defaults to the PR for the current branch"
metadata:
  version: "1.2"
  author: frontend-claude
  last_updated: "2026-03-22"
---

# /fix-review

## Entry: detect PR type

```bash
gh pr view <number> --json author,title,headRefName,body
```

- If `author.login == "dependabot[bot]"` → follow **Dependabot flow** below.
- Otherwise → follow **Copilot review flow** below.

---

## Dependabot flow

No Copilot wait needed — merge decision is based on the bump level alone.

### 1. Read the PR

```bash
gh pr view <number> --json title,body,headRefName
```

Extract: package name, old version, new version.

### 2. Classify the bump

| Bump | Action |
|------|--------|
| **patch** (x.y.Z) | Merge immediately — no review needed |
| **minor** (x.Y.z) | Scan changelog/release notes for deprecations or behaviour changes; merge if clean |
| **major** (X.y.z) | Read migration guide, write a plan file, invoke `/backlog` to create a tracking issue, close the PR without merging |

### 3. Check for breakage (minor and major)

- Read the package's CHANGELOG or GitHub release notes (use WebFetch if needed).
- Grep the codebase for any API surfaces flagged as removed/changed:
  ```bash
  grep -r "<symbol>" src/
  ```
- If breaking usage is found for **minor**: report to the user, do not merge.
- For **major**: always proceed to step 3a regardless of whether breaking usage is found.

### 3a. Major bump — write plan, create issue, close PR

1. **Write a plan file** to `.claude/plans/1-migrate-<package>-v<N>.md`:

```markdown
---
title: "Migrate <package> from v<old> to v<new>"
type: chore
priority: p1-high
status: ready
debt: balanced
effort: m
component:
  - dx
labels:
  - chore
  - p1-high
  - dx
  - deps
blocked_by: null
github_issue: null
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---
```

   Plan body (implementation details only — no Summary/AC, those go in the issue):
   - Files to change (from grep results)
   - Breaking API changes found in the migration guide
   - Step-by-step migration approach
   - Risks and unknowns

2. **Invoke `/backlog`** — it will deduplicate, create the GitHub issue, and delete the plan file.
   Record the issue number it returns.

3. **Comment on the Dependabot PR** referencing the issue:
   ```bash
   gh pr comment <number> --body "Major version bump — migration tracked in #<issue>. Closing this PR; Dependabot will reopen when ready to merge."
   ```

4. **Close the Dependabot PR** without merging:
   ```bash
   gh pr close <number>
   ```

5. **Report** — package, old → new, issue number created, PR closed.
   Stop here. Do not merge. The migration issue is now in the backlog.

### 4. Merge (patch / clean minor only)

```bash
gh pr merge <number> --merge
```

Use `--merge` (not squash) to preserve Dependabot's commit for auditability.

### 5. Return to main

```bash
git checkout main && git pull
```

### 6. Report

Package, old → new version, bump level, any findings, merge commit or reason blocked.

---

## Copilot review flow

### Rules

- Process **one round** of Copilot comments only. Do not loop waiting for a second review.
- If a comment conflicts with project decisions (CLAUDE.md, memory), note the conflict and skip rather than blindly applying.
- If the PR has no unresolved Copilot comments, report that and stop.

### Code Review Pyramid — Prioritisation

When multiple comments exist, address them in this order (highest impact first):

| Layer | Concern | Examples |
|-------|---------|---------|
| 1 (highest) | Architecture & design | Wrong abstraction, breaking state contract, SSE adapter boundary violation |
| 2 | Correctness | Bugs, null handling gaps, missing error branches, race conditions, security |
| 3 | Documentation | Complex logic without comment, misleading naming, undocumented non-obvious behaviour |
| 4 (skip) | Style | Formatting — automated by ESLint, do not hand-fix |

*(No Layer 4 Tests — project has no test suite.)*

For each comment, assign a ruling before deciding what to do:

| Ruling | Meaning | Action |
|--------|---------|--------|
| **CONFIRM** | Real issue, model was right | Fix it |
| **ESCALATE** | Real issue, more severe than flagged | Fix it, note severity upgrade |
| **DISMISS** | False positive or conflicts with project patterns (CLAUDE.md) | Skip, note reason |
| **DEFER** | Real but out of scope for this PR | Log only, do not fix |

### Steps

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

- Do not merge the PR — that is `/ship`'s job (except Dependabot patches/minor above).
- Do not wait for a new Copilot review cycle.
- Do not open new issues or PRs.
