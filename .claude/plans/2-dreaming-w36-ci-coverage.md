---
title: "Wire up test coverage collection in CI"
type: task
priority: p2-medium
status: draft
debt: quick-fix
effort: s
component:
  - dx
  - config
labels:
  - task
  - p2-medium
  - dx
  - ci
blocked_by: null
github_issue: null
created: 2026-09-08
updated: 2026-09-08
---

## Summary

`.claude/skills/housekeeping/SKILL.md` Check 7 ("CI Coverage Delta") has
been marked `PLANNED` — not yet functional — since the skill's initial
install. Every weekly `/housekeeping` run and every dreaming pass since
2026-W30 (now 2026-W36, 5+ consecutive weeks) has re-flagged the same gap:
neither `vite.config.js`'s `test` block nor `package.json`'s `test` script
enables Vitest's `--coverage` flag, so there's no coverage artifact for
Check 7 to diff between runs. This has become a chronic dormant item per
the 2026-W36 dreaming report (§7) — user explicitly chose to schedule it
as a `/ship` task rather than move it to `OUT-OF-SCOPE`.

## Acceptance Criteria

- [ ] `@vitest/coverage-v8` added as a devDependency, version matching the
      installed `vitest ^4.1.11` (Vitest requires the coverage provider
      package to match its own major version).
- [ ] `vite.config.js`'s `test` block gains a `coverage` sub-object
      (provider: `v8`, reporter including at least `text` and `json-summary`
      or `lcov` — pick whichever format `.github/workflows/ci.yml`'s future
      artifact-upload step can consume most simply).
- [ ] A new `npm run test:coverage` script in `package.json` (or extending
      `make test`) that runs `vitest run --coverage`.
- [ ] `.github/workflows/ci.yml`'s `validate` job runs the coverage variant
      (replacing or supplementing the existing `npm test` step) and uploads
      the coverage artifact (`actions/upload-artifact@v4` or similar) so a
      later run can retrieve the previous run's coverage for comparison.
- [ ] `.claude/skills/housekeeping/SKILL.md` Check 7 updated: remove the
      `PLANNED` — not yet functional preamble, implement the actual
      `gh run list` + artifact-download + delta-comparison logic described
      in the skill's own "Once coverage collection exists" section.
- [ ] Coverage thresholds are **not** enforced in this PR (no `test.coverage.thresholds`
      failing the build) — this ships collection + visibility only; enforcing
      a minimum % is a separate, later decision once a baseline exists.

## Implementation

### Files to change

- `package.json` — add `@vitest/coverage-v8` devDependency; add/modify a
  `test:coverage` script (or fold `--coverage` into the existing `test`
  script — see Approach below for the trade-off).
- `vite.config.js` — add `test.coverage` config block.
- `.github/workflows/ci.yml` — add coverage collection + artifact upload
  to the `validate` job.
- `.claude/skills/housekeeping/SKILL.md` — implement Check 7's actual
  delta-comparison logic (currently just a comment describing intent).
- `Makefile` — optionally add a `test-coverage` target mirroring the new
  npm script, for consistency with existing `make test`/`make ci` aliases.

### Files to read (context only)

- `.github/workflows/ci.yml` — current `validate` job structure (checkout →
  setup-node → npm ci → lint → test → build); coverage step should slot in
  without restructuring the existing steps.
- `src/test-setup.js` — confirms no existing coverage-adjacent setup to
  conflict with.

### Approach

Two design decisions with real trade-offs:

1. **Does `npm test` (the script CI already calls) gain `--coverage` directly,
   or does a new `npm run test:coverage` script exist alongside the plain
   one?** Options: (a) modify `npm test` itself to always collect coverage
   — simplest, one code path, but slightly slows every local `npm test` run
   and produces a `coverage/` directory locally unless gitignored; (b) add a
   separate `test:coverage` script, used only by CI's workflow step — keeps
   local `npm test` fast, but means two slightly-diverging test invocations
   to keep in sync. Given `make test`/`npm test` is the everyday local-dev
   command (per `CLAUDE.md`'s Commands section) and coverage collection has
   measurable overhead, **(b) is likely the right call** — CI opts into
   `test:coverage` explicitly, local dev stays on the fast path.
2. **Which coverage reporter format for the artifact?** `v8`'s provider
   supports `text` (console), `json`/`json-summary` (machine-readable delta
   comparison — what Check 7 needs), `lcov` (external tools), `html`
   (browsable report). At minimum `json-summary` is required for Check 7's
   comparison logic to parse a single "total line %" number; `text` is
   worth keeping for CI log visibility. Recommend: `['text', 'json-summary']`
   as the reporter list — skip `html`/`lcov` unless a future need (e.g.
   Codecov integration) arises.

### Risks / Unknowns

- **Very likely fine:** this is purely additive tooling — no runtime `src/`
  code changes, no behavior change to the app itself.
- **Likely fine:** `@vitest/coverage-v8` version alignment with `vitest
  ^4.1.11` — Vitest's own docs pin the coverage package to the same major;
  a mismatched version fails fast at `vitest run --coverage` time with a
  clear error, not a silent wrong-result.
- **Unlikely but possible:** the `coverage/` output directory needs a
  `.gitignore` entry if not already covered by a broader `node_modules`-style
  pattern — verify during implementation, not assumed here.
- **Deferred, not a risk for this PR:** enforcing a coverage percentage
  threshold that fails CI is explicitly out of scope (see Acceptance
  Criteria) — that's a follow-up decision once there's a real baseline
  number to set a sane threshold against.

## Not in Scope

- Enforcing a minimum coverage percentage / failing CI on regression — this
  PR only wires up collection and Check 7's delta *reporting*, not a gate.
- Retroactively adding tests to raise current coverage — separate work.
- Codecov/Coveralls or any third-party coverage-hosting integration.
- Coverage for the Go backend (`vmm-rada`, separate repo) — frontend-only.

## Commit Message

```
chore(ci): wire up test coverage collection ⚡
```

## After Implementing

- [ ] `npm run lint` passes
- [ ] `make ci` (or equivalent) passes locally with coverage collection
- [ ] Manual smoke test: `npm run test:coverage` produces a `coverage/`
      directory with a `coverage-summary.json` (or equivalent) containing
      a parseable total line %
- [ ] `/ship` to create PR and merge
- [ ] Verify the next `/housekeeping` run's Check 7 actually reports a
      real percentage instead of SKIP/PLANNED
- [ ] Move plan status to `done`, fill `github_issue` if created
