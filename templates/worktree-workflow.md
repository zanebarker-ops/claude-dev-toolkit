# Worktree-First Workflow

**EVERY request, feature, task, or bug fix MUST follow this workflow. NEVER work directly on `dev` or `main`.**

## MANDATORY: Security Review Before Presenting Code

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

## Quick Start

**When you receive ANY task, the FIRST thing you do is create an isolated workspace.**

```bash
# Derive project name dynamically
PROJECT=$(basename $(git rev-parse --show-toplevel))

# 1. Check for existing work first
gh issue list --state open

# 2. CREATE ISOLATED WORKSPACE FIRST
git pull origin dev
# git worktree add ../$PROJECT-wt/GH-NNN-desc -b feature/GH-NNN-desc dev

# 3. Create GitHub issue
gh issue create --title "Title" --body "## Overview"

# 4. If planning is needed, create plan INSIDE the workspace

# 5. CONFIDENCE GATE (mandatory - see section below)
#    Ask questions until 8/10 confident you can succeed

# 6. Work in workspace (only after Confidence Gate passes)

# 7. Commit with references
git commit -m "Description (GH-NNN)"

# 8. MANDATORY: Rebase from dev BEFORE push/PR
git fetch origin
git rebase origin/dev

# 9. MANDATORY: Run lint and typecheck AFTER rebase
scripts/lint-changed.sh

# 10. Push and wait for CI/CD
git push -u origin feature/GH-NNN-desc

# 11. Create PR (only after CI/CD succeeds)
gh pr create --base dev --body "## Summary"

# 12. Cleanup after merge
```

---

## Confidence Gate (8/10 Rule)

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
| Scope | "The config also references this in config.ts - should I update that too?" | "Anything else?" |
| Data model | "The events table has no severity column yet - should I add one?" | "Is the database ready?" |
| Security | "This endpoint returns user data - should it require owner role?" | "Is security important?" |
| Edge cases | "What should happen if the account has no active subscription?" | "What about errors?" |

### Skipping the Gate

The gate can ONLY be skipped for:
- **Typo fixes** (single word/character changes)
- **Comment-only changes** (no functional impact)
- **Exact reproduction** of user-provided code (user gave you the exact code to write)

Everything else - features, bug fixes, refactors, migrations, config changes - goes through the gate.

---

## Shared Lint Tools (Optional)

If your project uses shared lint tools (recommended for monorepos):

```bash
scripts/lint-changed.sh                 # Changed files only (default)
scripts/lint-changed.sh --all           # Lint all files
scripts/lint-changed.sh --fix           # Auto-fix
```

Otherwise use standard npm/pnpm commands:
```bash
npm run lint
npx tsc --noEmit
```

## Directory Structure

```
~/repos/your-project/                   # Main repo (ALWAYS on dev branch!)
~/repos/your-project-wt/                # Isolated workspaces
  GH-123-feature-name/                 # One per issue
  GH-456-another-feature/
```

## Rules for Multiple Claude Code Sessions

1. **One session = one workspace** - Never share between sessions
2. **One workspace = one issue** - Maps to exactly one GitHub issue
3. **Workspace first** - Always create the workspace FIRST, then GitHub issue
4. **Link everything** - Commits include (GH-NNN), issues include branch name
5. **Never switch branches** - Create a new workspace instead
6. **Commit frequently** - Avoid conflicts between parallel sessions
7. **Detect your context** - Run pwd and git branch at session start

## Cleanup

```bash
# After PR is merged, remove the workspace and prune
```

---

# Multi-Agent Coordination

**When multiple Claude Code sessions work in parallel, they MUST coordinate to avoid conflicts.**

## Why This Matters

Without coordination:
- Two agents edit the same file and create merge conflicts
- Agent A's changes break Agent B's work
- Wasted time resolving conflicts after the fact

## Session Start Protocol (MANDATORY)

At the start of every session, run:

```bash
pwd                        # Confirm you're in the right workspace
git branch --show-current  # Confirm your branch
git status                 # Check for uncommitted changes
```

If using the coordination system (`.claude/coordination/state.json`):
1. Read state.json to see what other agents are doing
2. Register your session with workspace name and planned files
3. Check for file lock conflicts before editing

## File Locking (Coordination System)

Before editing a shared file:
1. Check if file is in fileLocks in state.json
2. If locked by another session, WARN and coordinate first
3. If not locked, add a soft lock before editing
4. Release the lock after committing

After editing:
1. Log the change to recentChanges in state.json
2. Release the file lock

## Conflict Prevention Rules

1. **File ownership** - If you're working on a file, note it in your issue/PR description
2. **Early commits** - Commit and push early so other agents can see your changes
3. **Rebase before PR** - Always rebase from dev before creating PR
4. **Communicate** - If another agent is touching the same files, coordinate

## Conflict Resolution

If you discover a conflict:
1. **Don't force-push** - This destroys other agents' work
2. **Rebase first** - git pull --rebase origin dev
3. **Resolve surgically** - Fix only the conflict, don't refactor
4. **Re-run tests** - Verify nothing broke after resolution
