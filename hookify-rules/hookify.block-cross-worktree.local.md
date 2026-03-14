---
name: block-cross-worktree
enabled: true
priority: 0
event: [edit, write]
action: block
conditions:
  hook: .claude/hooks/check-cross-worktree.sh
---

# 🚫 BLOCKED: File modification outside current worktree

You attempted to modify a file that exists outside your current worktree.

**Why this is blocked:**
- Each Claude session runs in its own isolated worktree
- Modifying files in other worktrees causes conflicts between parallel sessions
- This protects against accidental cross-worktree modifications

**Current worktree:** {detected from git}
**Target file:** {file path from tool call}

**What to do:**
1. Only modify files within your current worktree directory
2. If you need to modify a file in another worktree, switch to that worktree's session
3. Use the file lock coordination system if multiple sessions need to coordinate

**Related:**
- Multi-Agent Coordination: `.claude/hookify-rules.md` (Multi-Agent Coordination Rules section)
- Worktree Workflow: `docs/reference/standards/workflows.md`
