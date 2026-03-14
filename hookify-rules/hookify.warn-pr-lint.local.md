---
name: warn-pr-lint
enabled: true
event: bash
pattern: gh\s+pr\s+create
action: warn
---

**STOP! Did you run lint and type-check?**

Before creating a PR, you MUST run:

```bash
# Works from any worktree - no pnpm install needed
scripts/lint-worktree.sh eslint
scripts/lint-worktree.sh typecheck
```

**If either fails, fix the errors before creating the PR.**

Recent incidents (GH-588, GH-589) merged broken code because agents skipped this step.

See `.claude/workflows.md` Step 5b for the full pre-PR checklist.
