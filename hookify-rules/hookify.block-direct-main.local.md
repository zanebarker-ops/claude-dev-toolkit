---
name: block-direct-main
enabled: true
event: bash
pattern: git\s+(push|commit).*\s+main\b
action: block
---

🛑 **Direct commit/push to the protected `main` branch detected!**

Per CLAUDE.md branch protection rules:
- **NEVER commit or push directly to `main`** — `main` is the only long-lived
  branch and is protected. All work happens in worktrees and lands via PR.

**Required workflow:**
1. Create a feature branch: `git worktree add ../<repo>-worktrees/GH-###-description -b feature/GH-###-description main`
2. Work in the worktree
3. Create a PR to merge into `main`

See `.claude/workflows.md` for the complete workflow.
