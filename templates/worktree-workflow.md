# Worktree-First Workflow

**EVERY request, feature, task, or bug fix MUST follow this workflow. NEVER work directly on `dev` or `main`.**

## ⛔ MANDATORY: Security Review Before Presenting Code

**ALL code MUST pass security review BEFORE presenting to user. This is non-negotiable.**

### Pre-Presentation Security Checklist

When using agents to generate code, the orchestrator MUST:

1. **Access Control Verification** - All database tables have RLS enabled with proper policies
   - [ ] User-scoped SELECT policies include role checks
   - [ ] Service role policies don't bypass account_id validation
   - [ ] No unrestricted `WITH CHECK (true)` on user-facing operations

2. **API Route Authentication** - All routes verify auth
   - [ ] Uses established auth helper (not manual session checks)
   - [ ] Admin/owner roles verified for privileged operations
   - [ ] Rate limiting on sensitive endpoints

3. **Input Validation** - All inputs sanitized
   - [ ] Zod/schema validation on request bodies
   - [ ] HTML sanitization for user-provided text
   - [ ] No SQL injection (parameterized queries only)

4. **Secrets Protection**
   - [ ] API keys only in server-side code
   - [ ] No secrets in client bundles
   - [ ] Webhook signatures verified

### Implementation

```
# Agent workflow MUST be:
1. Generate code
2. Run security review agent
3. Fix ALL security issues
4. Re-run security review
5. ONLY THEN present to user
```

**If security review fails: FIX IT. Never present insecure code.**

---

## Quick Start (Worktree-First)

**When you receive ANY task (feature, bug, enhancement, etc.), you immediately know work is involved. The FIRST thing you do is create a worktree.**

```bash
# Derive project name dynamically
PROJECT_NAME=$(basename $(git rev-parse --show-toplevel))

# 1. Check for existing work first
gh issue list --state open
git worktree list

# 2. CREATE WORKTREE FIRST (isolation before anything else)
git pull origin dev
git worktree add ../${PROJECT_NAME}-worktrees/GH-###-description -b feature/GH-###-description dev

# 3. Optional: Create persistent memory entry (if using Beads or similar)
# bd create "Brief task description" -p 0
# Returns: bd-XXXX - save this ID!

# 4. Create GitHub issue (linked to tracking system)
gh issue create --title "Title" --body "## Overview\n\n## Tracking\n- **Branch:** feature/GH-###-description"

# 5. If planning is needed, create plan INSIDE the worktree
#    Plans go at: ../${PROJECT_NAME}-worktrees/GH-###-description/.plans/
#    NEVER store plans in ~/.claude/plans/ or outside the worktree

# 6. CONFIDENCE GATE (mandatory - see section below)
#    Ask questions until 8/10 confident you can succeed
#    DO NOT write any code until gate is passed

# 7. Work in worktree (only after Confidence Gate passes)
cd ../${PROJECT_NAME}-worktrees/GH-###-description

# 8. Commit with references
git commit -m "Description (GH-###)"

# 9. MANDATORY: Run lint and typecheck BEFORE push
scripts/lint-worktree.sh eslint      # Changed files only (if using shared lint tools)
scripts/lint-worktree.sh typecheck   # Full project type check
# Or: npm run lint && npx tsc --noEmit
#    Both MUST pass with zero errors before pushing

# 10. Push and wait for CI/CD
git push -u origin feature/GH-###-description
# Wait for preview deployment to succeed

# 11. Create PR (only after CI/CD succeeds)
gh pr create --base dev --body "## Summary\n\n## Tracking\n- Closes #GH-###"

# 12. Cleanup after merge
git worktree remove ../${PROJECT_NAME}-worktrees/GH-###-description
git worktree prune
```

---

## 🚦 Confidence Gate (8/10 Rule)

**After setup and BEFORE writing any code, the orchestrator MUST pass the Confidence Gate.**

### Why

Starting work without sufficient understanding leads to wrong approaches, wasted effort, rework, and security gaps. Asking questions upfront is cheaper than rewriting code.

### The Rule

> **Do NOT begin implementation until you are at least 8/10 confident you can achieve success.**

"Success" means: correct solution, no security issues, passes lint/typecheck, matches user's intent, and doesn't break existing functionality.

### How It Works

1. **Orchestrator self-assesses** confidence across these dimensions:

| Dimension | Question to Evaluate |
|-----------|---------------------|
| **Requirements** | Do I know exactly what the user wants? Are acceptance criteria clear? |
| **Scope** | Do I know which files need to change? Are there hidden dependencies? |
| **Codebase knowledge** | Have I read the relevant existing code? Do I understand the patterns in use? |
| **Data model** | Do I know the database schema, access policies, and relationships involved? |
| **Security implications** | Do I understand the auth/authorization requirements? |
| **Edge cases** | Have I considered error states, empty states, and boundary conditions? |
| **Testing strategy** | Do I know how this will be verified? |
| **Risk assessment** | Could this break something else? What's the blast radius? |

2. **If confidence < 8/10**, MUST ask the user clarifying questions. Questions should be specific and actionable, not vague.

3. **Repeat** until confidence reaches 8/10. There is no limit on rounds of questions.

### What Good Questions Look Like

| Dimension | Good Question | Bad Question |
|-----------|--------------|--------------|
| Requirements | "Should the notification go to all account members, or just the owner?" | "What do you want?" |
| Scope | "The config also references this in `config.ts` — should I update that too?" | "Anything else?" |
| Data model | "The `events` table has no `severity` column yet — should I add one?" | "Is the database ready?" |
| Security | "This endpoint returns user data — should it require owner role?" | "Is security important?" |
| Edge cases | "What should happen if the account has no active subscription?" | "What about errors?" |

### Skipping the Gate

The gate can ONLY be skipped for:
- **Typo fixes** (single word/character changes)
- **Comment-only changes** (no functional impact)
- **Exact reproduction** of user-provided code (user gave you the exact code to write)

Everything else — features, bug fixes, refactors, migrations, config changes — goes through the gate.

---

## Shared Lint Tools (Optional)

If your project uses shared lint tools (recommended for monorepos with worktrees):

```bash
# From any worktree - lint changed files only (default):
scripts/lint-worktree.sh eslint
scripts/lint-worktree.sh typecheck

# Lint all files:
scripts/lint-worktree.sh eslint --all

# Auto-fix:
scripts/lint-worktree.sh eslint --fix

# If tools are missing:
bash .lint/install.sh
scripts/verify-lint-setup.sh
```

Otherwise use standard npm/pnpm commands:
```bash
npm run lint
npx tsc --noEmit
```

## Directory Structure

```
/path/to/your-project/              # Main repo (ALWAYS on dev branch!)
/path/to/your-project-worktrees/    # Worktrees directory
├── GH-123-feature-name/            # One worktree per issue
├── GH-456-another-feature/
```

## Rules for Multiple Claude Code Sessions

1. **One session = one worktree** - Never share worktrees between sessions
2. **One worktree = one issue** - Each worktree maps to exactly one GitHub issue
3. **Worktree first** - Always create the worktree FIRST, then GitHub issue
4. **Link everything** - Commits include `(GH-###)`, issues include branch name
5. **Never switch branches** - Create a new worktree instead
6. **Commit frequently** - Avoid conflicts between parallel sessions
7. **Detect your context** - Run `pwd` and `git branch --show-current` at session start

## Cleanup

```bash
# After PR is merged
PROJECT_NAME=$(basename $(git rev-parse --show-toplevel))
git worktree remove ../${PROJECT_NAME}-worktrees/GH-###-description
git worktree prune
```

---

# Multi-Agent Coordination

**When multiple Claude Code sessions work in parallel, they MUST coordinate to avoid conflicts.**

## Why This Matters

Without coordination:
- Two agents edit the same file → merge conflicts
- Agent A's changes break Agent B's work
- Wasted time resolving conflicts after the fact

## Session Start Protocol (MANDATORY)

At the start of every session, run:

```bash
pwd                        # Confirm you're in the right worktree
git branch --show-current  # Confirm your branch
git worktree list          # See all active worktrees
git status                 # Check for uncommitted changes
```

## Conflict Prevention Rules

1. **File ownership** - If you're working on a file, note it in your issue/PR description
2. **Early commits** - Commit and push early so other agents can see your changes
3. **Rebase before PR** - Always rebase from dev before creating PR to catch conflicts early
4. **Communicate** - If you discover another agent is touching the same files, coordinate

## Conflict Resolution

If you discover a conflict:
1. **Don't force-push** - This destroys other agents' work
2. **Rebase first** - `git pull --rebase origin dev`
3. **Resolve surgically** - Fix only the conflict, don't refactor
4. **Re-run tests** - Verify nothing broke after resolution
