# Cross-Project Patterns

Patterns proven in 2+ areas. Promoted automatically by /self-learn retro.

---

## GitHub CLI query fallback *(promoted 2026-08-23 — 2 wins: 2026-08-06 ×2)*

When `gh pr list --author <bot>` (or a similar CLI filter) returns
unexpectedly empty, verify with an alternative query — e.g.
`/issues?author=<bot>` via `gh api` — before concluding nothing exists.
Reusable in: any task querying GitHub PR/issue status where CLI filter
results may be incomplete or silently miss items.

## Cross-reference duplicated docs when fixing stale content *(promoted 2026-08-23 — 2 wins: 2026-07-31 ×2)*

When fixing a stale value in one doc/config file, check for the same
content duplicated elsewhere (grep or `graphify query`) in the same pass
— don't assume single-source-of-truth is enforced. Reusable in:
documentation refactoring, environment-variable or config updates where
duplication isn't structurally prevented.

## Manual fallback when a subagent/gatekeeper fails on transient infra *(promoted 2026-08-23 — 2 wins: 2026-08-06 ×2)*

When an automated subagent or quality gate (e.g. Tech Lead review) fails
due to a transient infra/model error, perform that role manually — read
the relevant files, apply the same checks — rather than retrying
indefinitely or blocking the task. Reusable in: any multi-agent workflow
with automated approvals or delegated gatekeeping that might hit
transient API/infra downtime.

---
