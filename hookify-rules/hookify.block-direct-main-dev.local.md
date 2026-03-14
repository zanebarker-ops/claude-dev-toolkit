---
name: block-direct-main-dev
enabled: true
event: bash
pattern: git\s+(push|commit).*\s+(main|dev)\b|git\s+checkout\s+(main)\b
action: block
---

🛑 **Direct commit/push to protected branch detected!**

Per CLAUDE.md branch protection rules:
- **NEVER commit directly to `main` or `dev`**
- **NEVER checkout `main`** - the main repo should always be on `dev`

**Required workflow:**
1. Create a feature branch: `git worktree add ../safegamer-ai-worktrees/GH-###-description -b feature/GH-###-description dev`
2. Work in the worktree
3. Create a PR to merge into `dev`

See `.claude/workflows.md` for the complete workflow.
