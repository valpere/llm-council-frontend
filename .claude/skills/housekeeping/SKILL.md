---
name: housekeeping
description: "vmm-rada-web-ui recurring repo health check. Runs 7 checks (stale branches, console.log leaks, tracked .env, tracked backups, TODO/FIXME count, framework version drift, CI coverage delta) and outputs a pass/fail table. Usage: /housekeeping"
---

# Skill: /housekeeping
# vmm-rada-web-ui — Repo Health Check

---

## OVERVIEW

```
/housekeeping  →  7 checks  →  Markdown table: Check | Status | Detail
                            →  Summary: N passed, M failed
```

Read-only. Never modifies files, never commits, never opens a PR.
Run any time for a hygiene snapshot. Any FAIL = exit signal to fix before shipping.

---

## CHECKS

### Check 1 — Stale Local Branches

**Goal:** ≤ 10 local branches after pruning remote-tracking refs.

```bash
git remote prune origin 2>&1 | tail -3
LOCAL_COUNT=$(git branch | grep -v '^\*' | wc -l | tr -d ' ')
```

**Pass:** `LOCAL_COUNT <= 10`
**Fail:** "N local branches — prune merged ones"

Cleanup tip:
```bash
git branch --merged main | grep -v 'main\|^\*'
# delete with: git branch -d <branch>
```

---

### Check 2 — Debug Output in Source

**Goal:** Zero `console.log(` calls in production source (excluding test files).

```bash
FILES=$(grep -r --include="*.js" --include="*.jsx" \
  --exclude="*.test.*" --exclude="*.spec.*" \
  -l "console\.log(" src/ 2>/dev/null)
COUNT=$(echo "$FILES" | grep -c '.' 2>/dev/null || echo 0)
```

**Pass:** `COUNT == 0`
**Fail:** list offending files (up to 5, then "+ N more")

---

### Check 3 — Tracked .env File

**Goal:** `.env` must not be tracked by git (would leak secrets).

```bash
TRACKED=$(git ls-files .env 2>/dev/null)
```

**Pass:** empty result
**Fail:** "`.env` is tracked — add to .gitignore and run `git rm --cached .env`"

---

### Check 4 — Tracked Backup Files

**Goal:** `backup/` directory (if it exists) must not be tracked by git.

```bash
TRACKED=$(git ls-files backup/ 2>/dev/null)
```

**Pass:** empty result (or `backup/` doesn't exist)
**Fail:** list the tracked backup files

---

### Check 5 — TODO/FIXME Count (informational)

**Goal:** Report count. No threshold — visibility only.

```bash
COUNT=$(grep -r --include="*.js" --include="*.jsx" \
  -E "//\s*(TODO|FIXME)" \
  --exclude-dir=node_modules --exclude-dir=.git \
  src/ 2>/dev/null | wc -l | tr -d ' ')
```

**Status:** Always `INFO`.
**Detail:** "N TODO/FIXME comments" — append " (consider a cleanup sprint)" if > 20.

This check never contributes to the failed count.

---

### Check 6 — Framework Version Drift in Docs

**Goal:** No docs/agent files reference an older major version of React or Vite than what `package.json` actually pins.

```bash
CURRENT_REACT=$(grep -oP '"react":\s*"\^?\K[0-9]+' package.json | head -1)
CURRENT_VITE=$(grep -oP '"vite":\s*"\^?\K[0-9]+' package.json | head -1)

grep -rn --include="*.md" -oE "React [0-9]+|Vite [0-9]+" .claude/ docs/ CLAUDE.md 2>/dev/null \
  | awk -F: -v react="$CURRENT_REACT" -v vite="$CURRENT_VITE" '
    { match($0, /(React|Vite) ([0-9]+)/, m);
      if (m[1] == "React" && m[2] != react) print;
      if (m[1] == "Vite" && m[2] != vite) print;
    }'
```

**Pass:** no stale version mentions
**Fail:** list files containing the stale version reference

---

### Check 7 — CI Coverage Delta

**Goal:** total line coverage on `main` must not go down.

Compares the `coverage-summary` artifact from the two most recent
successful `main` runs of `.github/workflows/ci.yml` (produced by its
`push`/`workflow_dispatch` triggers). Requires `gh` (authenticated) and
`jq`; degrades to SKIP without them.

```bash
STATUS=SKIP; DETAIL="coverage artifact not available"

if command -v gh >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  # `--branch main` (not `--event push`) so on-demand `workflow_dispatch`
  # seed-runs also count. Safe here: pull_request runs report the PR's
  # source branch as headBranch, and no PR ever originates from main.
  RUN_IDS=$(gh run list --workflow=ci.yml --branch main --status success \
    --limit 2 --json databaseId --jq '.[].databaseId' 2>/dev/null)

  if [ "$(printf '%s\n' "$RUN_IDS" | grep -c '.')" -eq 2 ]; then
    NEW_ID=$(printf '%s\n' "$RUN_IDS" | sed -n 1p)
    OLD_ID=$(printf '%s\n' "$RUN_IDS" | sed -n 2p)
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT   # guaranteed cleanup on any exit path

    if gh run download "$NEW_ID" -n coverage-summary -D "$TMP/new" 2>/dev/null &&
       gh run download "$OLD_ID" -n coverage-summary -D "$TMP/old" 2>/dev/null; then
      NEW_PCT=$(jq -r '.total.lines.pct' "$TMP/new/coverage-summary.json" 2>/dev/null)
      OLD_PCT=$(jq -r '.total.lines.pct' "$TMP/old/coverage-summary.json" 2>/dev/null)

      case "$NEW_PCT$OLD_PCT" in
        ''|*null*) : ;;   # unparseable summary -> stay SKIP
        *)
          DELTA=$(awk -v n="$NEW_PCT" -v o="$OLD_PCT" 'BEGIN{printf "%+.2f", n-o}')
          if awk -v n="$NEW_PCT" -v o="$OLD_PCT" 'BEGIN{exit !(n>=o)}'; then
            STATUS=PASS; DETAIL="${NEW_PCT}% lines (delta: ${DELTA} vs previous main)"
          else
            STATUS=FAIL; DETAIL="${NEW_PCT}% lines (delta: ${DELTA} — coverage regressed)"
          fi
          ;;
      esac
    else
      DETAIL="coverage artifact missing or expired on run $NEW_ID / $OLD_ID"
    fi

    rm -rf "$TMP"
  else
    DETAIL="fewer than 2 successful main runs with coverage"
  fi
else
  DETAIL="gh or jq unavailable"
fi
```

- `DELTA >= 0`: Pass — "N% lines (delta: +M vs previous main)"
- `DELTA < 0`: Fail — "N% lines (delta: -M — coverage regressed)"
- Unable to compare: SKIP — reason in Detail

**Scope note:** this is a *main-to-main historical* delta. It does not
evaluate whether the current working branch regresses coverage — that
would need a PR-vs-main gate in CI, which is separate work.

**Optional tolerance:** v8 percentages can wiggle by hundredths. To avoid
flapping FAILs, relax the comparison to `!(n >= o - 0.1)`.

---

## OUTPUT FORMAT

```
## /housekeeping — Repo Health Report

| Check | Status | Detail |
|-------|--------|--------|
| Stale local branches     | PASS | 4 local branches |
| Debug output in src      | PASS | — |
| Tracked .env              | PASS | — |
| Tracked backup files      | PASS | — |
| TODO/FIXME count           | INFO | 6 TODO/FIXME comments |
| Framework version drift    | PASS | — |
| CI coverage delta          | PASS | 71.42% lines (delta: +0.31 vs previous main) |

**6 passed, 0 failed** (1 informational)
```

Check 7 legitimately reports SKIP when fewer than two successful `main`
runs carry a live coverage artifact (e.g. right after this check was
wired up, or after 30-day artifact expiry during a quiet period) — SKIP
still never counts as a failure.

Status values:
- `PASS` — check succeeded
- `FAIL` — check failed (must be addressed)
- `INFO` — informational only, never counted as failed
- `SKIP` — could not run (missing tools, no artifacts, or fewer than 2
  comparable main runs)

Summary: `N passed, M failed` — with optional `(K informational, J skipped)`.

---

## RULES

1. **Read-only** — never modify files in the repository, commit, push, or
   open a PR. Check 7 downloads artifacts into a `mktemp -d` scratch
   directory outside the repo and removes it before returning; that is
   the only permitted write.
2. **Run from repo root** — all paths relative to repository root.
3. **INFO checks never count as failures** (TODO/FIXME is always INFO).
4. **SKIP is not failure** — a skipped or PLANNED check doesn't increment failed count.
5. **Graceful degradation** — if a tool is unavailable, mark check SKIP and continue.
6. **No auto-fix** — this skill reports; for fixes use the appropriate skill.
7. **Exit signal** — if any check is FAIL, end with: "Run /housekeeping again after fixing the issues above."
