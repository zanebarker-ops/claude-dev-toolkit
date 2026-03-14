---
name: block-hook-bypass
enabled: true
priority: 100
event: bash
conditions:
  - pattern: 'git.*-c core\.hooksPath='
  - pattern: 'git.* --no-verify'
  - pattern: 'HUSKY=0 git'
action: block
---

# ⛔ BLOCKED: Bypassing Git Hooks

**You're trying to bypass git hooks. This violates workflow security.**

## What You're Doing

You used one of these patterns to skip git hooks:
- `git -c core.hooksPath=/dev/null` - Disables all hooks
- `git --no-verify` - Skips pre-commit/pre-push hooks
- `HUSKY=0 git` - Disables Husky hooks

## Why This Is Blocked

Git hooks enforce critical safety checks:
- **Pre-commit hooks:** Lint checks, type checks, security audits
- **Pre-push hooks:** Validate lint passes before pushing
- **Commit-msg hooks:** Ensure proper commit message format

**Bypassing these checks is a workflow violation (Rule #8: Never bypass process).**

## When It's Acceptable to Bypass (RARE)

You should ONLY bypass hooks in these specific scenarios:
1. **Emergency hotfix** - Production is down, need immediate fix
2. **Hook is broken** - The hook itself has a bug preventing valid commits
3. **Non-code commit** - Committing docs/config with no src/ changes

## What To Do Instead

### If lint/typecheck is failing:
```bash
# FIX the errors, don't bypass them
cd jetship-saas-boilerplate/apps/web
npx pnpm run lint
npx pnpm run type-check
```

### If you need to commit work-in-progress:
```bash
# Use WIP commits on your feature branch
git commit -m "WIP: partial implementation (will fix lint before PR)"
```

### If the hook is legitimately broken:
```bash
# Report the issue first
gh issue create --title "Git hook blocking valid commits" --label "infrastructure"

# Then use bypass with justification in commit message
git commit --no-verify -m "fix: description

Bypassing hooks due to GH-### (hook is broken).
Will fix hook in separate PR."
```

## Previous Incidents

- GH-1094: Used `git -c core.hooksPath=/dev/null` to bypass lint errors instead of fixing them
- This led to pushing code with unused variables that Vercel CI caught

## Override (Emergency Only)

If this is truly an emergency, you can proceed with the bypass, but you MUST:
1. Document why in the commit message
2. Create a follow-up issue to fix the underlying problem
3. Get the bypass approved by team lead

**Reference:** @docs/reference/standards/workflows.md Section 8 (Never Bypass Process)
