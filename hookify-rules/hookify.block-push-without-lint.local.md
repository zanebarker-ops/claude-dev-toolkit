---
name: block-push-without-lint
enabled: true
priority: 100
event: bash
conditions:
  - pattern: 'git push.*origin (feature/|hotfix/)'
action: block
---

# ⛔ BLOCKED: Push to Feature Branch Without Lint Check

**You're trying to push to a feature branch without running lint/typecheck first.**

## Workflow Rule #2 (MANDATORY)

**"Zero lint/type errors - ALL errors fixed before PR (no exceptions)"**

Before pushing to a feature branch, you MUST run:

```bash
# Run lint check (works from any worktree - no pnpm install needed)
scripts/lint-worktree.sh eslint

# Run type check
scripts/lint-worktree.sh typecheck
```

**Both commands must pass with zero errors before pushing.**

## Why This Rule Exists

- **Vercel CI is expensive** - Don't waste CI cycles catching errors that should be caught locally
- **Faster feedback** - Catch errors in seconds locally vs minutes on CI
- **Rule #2 violation** - This is a mandatory workflow rule (see @docs/reference/standards/workflows.md:13-16)

## What To Do Now

1. Run lint and typecheck locally
2. Fix ALL errors
3. Re-run checks until they pass
4. THEN push

## Override (Use Sparingly)

If you've already run lint/typecheck and they passed, you can push directly:

```bash
# Skip this check by confirming you ran lint
git push origin feature/GH-###-description
```

The git pre-push hook will still validate lint on the actual push.

## Previous Incidents

- GH-1094: Pushed code with unused variable lint errors, caught by Vercel CI
- GH-588, GH-589: PRs merged without lint checks caused broken Vercel deployments

**Reference:** @docs/reference/standards/workflows.md Section 5b (Pre-PR Checks)
