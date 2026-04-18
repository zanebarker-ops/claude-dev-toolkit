# Claude Dev Toolkit

A comprehensive development toolkit for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that enforces quality, security, and workflow discipline across any project. Includes hooks, linting, 23 AI agent prompts, crash-proof sessions, and CI gates.

Born from 3000+ hours of real-world development on a production SaaS platform — every hook and rule exists because something went wrong without it.

---

## Table of Contents

- [What's Included](#whats-included)
- [Prerequisites](#prerequisites)
  - [WSL2 Setup (Windows)](#wsl2-setup-windows)
  - [VS Code + GitHub Setup](#vs-code--github-setup)
  - [Required Tools](#required-tools)
  - [Optional Tools](#optional-tools)
- [Installation](#installation)
- [Hooks Reference](#hooks-reference)
- [Hookify Rules Reference](#hookify-rules-reference)
- [Agent Commands Reference](#agent-commands-reference)
- [PR Review Toolkit](#pr-review-toolkit)
- [Linting (oxlint)](#linting-oxlint)
- [CI/CD Deploy Gate](#cicd-deploy-gate)
- [Crash-Proof Sessions (tmux)](#crash-proof-sessions-tmux)
  - [Why tmux?](#why-tmux)
  - [Setup](#session-setup)
  - [Multiple Parallel Sessions](#multiple-parallel-sessions)
  - [tmux Cheat Sheet](#tmux-cheat-sheet)
  - [Windows Terminal Profile](#windows-terminal-profile)
  - [Crash Recovery](#crash-recovery)
- [Migrating Existing Repos to ext4](#migrating-existing-repos-to-ext4)
- [Worktree-First Workflow](#worktree-first-workflow)
  - [Why Worktrees](#why-worktrees)
  - [Full Lifecycle](#full-lifecycle)
  - [Confidence Gate (8/10 Rule)](#confidence-gate-810-rule)
- [Templates Reference](#templates-reference)
- [Customization Guide](#customization-guide)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)

---

## What's Included

| Category | Count | Description |
|----------|-------|-------------|
| **Hooks** | 18 | Event-driven scripts that enforce workflow rules |
| **Hookify Rules** | 13 | Markdown-based rules for blocking/warning on patterns |
| **Agent Commands** | 26 | Specialized AI agent prompts (`/start-task`, `/security-auditor`, etc.) |
| **PR Review Toolkit** | 6 agents | Automated multi-agent code review before PRs |
| **Scripts** | 4 | Lint runner, deploy checker, session manager, ext4 migration |
| **Templates** | 9 | CLAUDE.md, worktree workflow, model selection, agents, PRP, hookify docs, coordination system |
| **Config** | 2 | `.oxlintrc.json`, `settings.json` template |

---

## Prerequisites

### WSL2 Setup (Windows)

Claude Code runs in Linux. On Windows, you need WSL2:

```powershell
# 1. Open PowerShell as Administrator
wsl --install

# 2. Restart your computer when prompted

# 3. After restart, Ubuntu will launch and ask you to create a user
#    Choose a username and password (this is your Linux user)

# 4. Update packages
sudo apt update && sudo apt upgrade -y
```

**Verify WSL2 is running:**
```powershell
wsl --list --verbose
# Should show your distro with VERSION 2
```

### Why WSL ext4? (Clone Into `~/repos/`, Not `/mnt/c/`)

Every file on `/mnt/c/` (your Windows C:\ drive) crosses the **9P protocol bridge** — a translation layer between WSL's Linux kernel and Windows NTFS. This bridge adds overhead to every single file operation: reads, writes, stats, directory listings.

For development tooling that does thousands of file operations per command (`git status`, `npm install`, lint, build), the penalty is brutal:

| Operation | `/mnt/c/` (NTFS via 9P) | `~/repos/` (native ext4) | Speedup |
|-----------|--------------------------|--------------------------|---------|
| `git status` | 3-5 seconds | < 0.5 seconds | **6-10x** |
| `git log -100` | 2-3 seconds | < 0.2 seconds | **10-15x** |
| `gh` CLI | Intermittent EINVAL errors | Reliable | **N/A** |
| Lint (700+ files) | 5-10 seconds | < 1 second | **5-10x** |
| `npm install` | Minutes | Seconds | **3-5x** |

**Worktrees multiply the problem.** Each worktree is a full working copy. If your main repo takes 4s for `git status` on NTFS, three worktrees means 12s of I/O just for status checks. On ext4, the same three worktrees take < 1.5s total.

**The fix is simple:** clone repos into `~/repos/` (WSL's native ext4 filesystem), not `/mnt/c/repos/`. Everything else — VS Code, Windows Explorer, your browser — still works:

- **VS Code:** Install the [WSL extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl), then `code ~/repos/your-project` from WSL terminal
- **Windows Explorer:** Browse files at `\\wsl$\Ubuntu\home\<username>\repos\`
- **Claude Code, git, gh, node, etc.:** All run natively in WSL at full speed

**Rule of thumb:** If you're on Windows, all repos and worktrees should live on `~/repos/`. The only reason to use `/mnt/c/` is if a Windows-native tool (not VS Code) needs direct filesystem access — which is rare.

If you already have repos on `/mnt/c/`, use the migration script to move them:

```bash
scripts/migrate-to-ext4.sh /mnt/c/repos/your-project ~/repos/your-project
```

See [Migrating Existing Repos to ext4](#migrating-existing-repos-to-ext4) for full details.

### VS Code + GitHub Setup

#### Install VS Code with WSL Extension

1. Install [VS Code](https://code.visualstudio.com/) on Windows
2. Install the **WSL** extension (by Microsoft) from the Extensions marketplace
3. Open VS Code, press `Ctrl+Shift+P`, type "WSL: Connect to WSL"

#### Configure Git in WSL

```bash
# Set your identity
git config --global user.name "Your Name"
git config --global user.email "your@email.com"

# Set default branch name
git config --global init.defaultBranch main

# Set pull strategy
git config --global pull.rebase true
```

#### Generate SSH Key and Add to GitHub

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your@email.com"
# Press Enter for default location, set a passphrase (recommended)

# Start SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key
cat ~/.ssh/id_ed25519.pub
# Copy the output
```

Then add it to GitHub:
1. Go to [GitHub SSH Keys](https://github.com/settings/keys)
2. Click "New SSH key"
3. Paste the public key and save

#### Clone Your Repo

```bash
# Clone into WSL filesystem (native ext4 — always do this)
cd ~
mkdir -p repos && cd repos
git clone git@github.com:your-org/your-project.git
```

> **Important:** Always clone into `~/repos/`, never `/mnt/c/`. See [Why WSL ext4?](#why-wsl-ext4-clone-into-repos-not-mntc) above.

#### Open Repo in VS Code from WSL

```bash
cd ~/repos/your-project
code .
# This opens VS Code connected to WSL with full Linux tool access
```

#### VS Code Recommended Settings

Add to your VS Code `settings.json` to reduce crashes and improve performance:

```json
{
  "files.watcherExclude": {
    "**/node_modules/**": true,
    "**/.git/**": true,
    "**/.next/**": true,
    "**/dist/**": true
  },
  "search.exclude": {
    "**/node_modules": true,
    "**/.archive": true
  },
  "terminal.integrated.defaultProfile.linux": "bash"
}
```

#### VS Code Recommended Extensions

Keep only essentials for stability:
- **WSL** (Microsoft) — required
- **ESLint** or **oxlint** — linting
- **Prettier** — formatting
- **Tailwind CSS IntelliSense** — if using Tailwind
- **GitLens** — git blame/history

**Avoid** heavy extensions that cause instability (aggressive file watchers, memory-heavy language servers).

### Required Tools

Install these in WSL:

```bash
# Node.js (via nvm — recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc
nvm install --lts
nvm use --lts

# Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Authenticate Claude Code
claude auth login
# Follow the prompts to authenticate with your Anthropic account

# oxlint (fast linter)
npm install -g oxlint

# GitHub CLI
sudo apt install gh
gh auth login
# Follow prompts to authenticate with GitHub

# tmux (crash-proof sessions)
sudo apt install tmux

# Git (usually pre-installed)
sudo apt install git
```

### Optional Tools

```bash
# Beads (bd) — persistent task tracking for Claude sessions
# See: https://github.com/your-org/beads (or your beads install source)

# 1Password CLI — secrets management
# See: https://developer.1password.com/docs/cli/get-started

# Zeroshot — multi-agent coordination
npm install -g @covibes/zeroshot
```

---

## Installation

```bash
# Clone the toolkit
git clone git@github.com:zanebarker-ops/claude-dev-toolkit.git ~/claude-dev-toolkit

# Install into your project
~/claude-dev-toolkit/install.sh /path/to/your-project
```

The installer:
1. Copies 14 hooks to `.claude/hooks/`
2. Copies 23 agent commands to `.claude/commands/`
3. Creates `.claude/settings.json` with hook registrations (won't overwrite existing)
4. Copies `.oxlintrc.json` to project root (won't overwrite existing)
5. Copies 3 scripts to `scripts/` (lint, deploy, session manager)
6. Copies 11 hookify rules to `.claude/` (won't overwrite existing)
7. Copies reference templates to `.claude/templates/`
8. Installs PR review toolkit to `.claude/plugins/`
9. Generates a starter `CLAUDE.md` (won't overwrite existing)

**After installing:**
1. Edit `CLAUDE.md` with your project details
2. Review `.claude/settings.json` hook configuration
3. Replace `[YOUR_PRODUCT]` in `.claude/commands/*.md` with your product name
4. Set `LINT_BASE_BRANCH` env var if your base branch isn't `dev`

---

## Hooks Reference

Hooks are shell scripts that run automatically before/after Claude Code tool calls. They enforce workflow rules without you having to remember them.

### PreToolUse Hooks (run BEFORE a tool executes)

| Hook | Trigger | What It Does |
|------|---------|-------------|
| `check-worktree.sh` | Edit, Write, Bash | Blocks operations in main repo on main/dev — forces worktree usage |
| `check-cross-worktree.sh` | Edit, Write | Blocks editing files outside the current worktree |
| `enforce-worktree-path.sh` | Bash | Ensures Bash commands target the correct worktree |
| `pre-commit-lint.sh` | Bash (git commit) | Runs lint before allowing git commit |
| `check-ci-before-pr.sh` | Bash (gh pr create) | Blocks PR creation unless CI/CD deployment verified |
| `gitleaks-scan.sh` | Bash (git commit) | Scans staged files for secrets/credentials via gitleaks |
| `warn-pr-to-main.sh` | Bash (gh pr create) | Warns when creating a PR directly to main/master |
| `block-env-read.sh` | Read | Blocks reading .env files to prevent credential exposure |
| `security-check.sh` | Edit, Write | Flags dangerous patterns (secrets, SQL injection, etc.) |
| `database-context-injector.sh` | Edit, Write | Adds database schema context when editing SQL files |

### PostToolUse Hooks (run AFTER a tool executes)

| Hook | Trigger | What It Does |
|------|---------|-------------|
| `post-worktree-cleanup.sh` | Bash (git worktree remove) | Cleans up after worktree removal |
| `database-update-reminder.sh` | Edit, Write | Reminds to update docs after database changes |

### UserPromptSubmit Hooks (run when user sends a message)

| Hook | Trigger | What It Does |
|------|---------|-------------|
| `wsl-crash-recovery.sh` | First message | Detects crashed sessions and outputs continuation prompts |
| `task-setup-workflow.sh` | New task detected | Reminds to create GH issue + worktree before starting work |
| `remind-success-prompt.sh` | Always | Reminds about success criteria |
| `qa-review-prompt.sh` | Always | Reminds about QA review before PR |
| `agent-review-reminder.sh` | Always | Reminds to run review agents before PR |
| `pre-push-review-reminder` | Bash (git push) | Reminds to run code review before pushing |

### How Hooks Work

Hooks are registered in `.claude/settings.json`. Each hook:
- Receives tool call context via stdin (JSON)
- **Exit 0** = allow the operation
- **Exit 2** = block the operation (stderr is shown to Claude as feedback)
- Runs with a timeout (default 3-5 seconds)

---

## Hookify Rules Reference

Hookify rules are lightweight markdown files that define pattern-matching rules. They complement hooks with simpler, declarative checks.

### Block Rules (P0 — Critical)

| Rule | File | What It Catches |
|------|------|----------------|
| Branch Protection | `hookify.block-direct-main-dev.local.md` | Direct commits/pushes to main/dev |
| Env Protection | `hookify.block-env-modification.local.md` | Modifications to `.env` files |
| Hook Bypass | `hookify.block-hook-bypass.local.md` | `--no-verify`, `core.hooksPath` bypass attempts |
| Push Without Lint | `hookify.block-push-without-lint.local.md` | `git push` without running lint first |
| Cross-Worktree | `hookify.block-cross-worktree.local.md` | Editing files outside current worktree |
| Credentials in Client | `hookify.block-credentials-in-client.local.md` | Service keys, secrets in client-side code |

### Warn Rules (P1 — Important)

| Rule | File | What It Catches |
|------|------|----------------|
| Console.log | `hookify.warn-console-log.local.md` | Debug statements in production code |
| ESLint Disable | `hookify.warn-eslint-disable.local.md` | `eslint-disable` comments |
| RLS Missing | `hookify.warn-rls-missing.local.md` | `CREATE TABLE` without Row Level Security |
| Security Definer | `hookify.warn-security-definer.local.md` | `SECURITY DEFINER` in SQL functions |
| View Security | `hookify.warn-view-missing-security-invoker.local.md` | `CREATE VIEW` without `security_invoker=on` |
| PR Lint | `hookify.warn-pr-lint.local.md` | PR creation without running lint |
| Migration Duplicates | `hookify.warn-migration-duplicate-fields.local.md` | Duplicate field patterns in migrations |
| Migration Docs | `hookify.warn-migration-undocumented.local.md` | Undocumented database migrations |
| Orphaned Tables | `hookify.warn-migration-orphaned-tables.local.md` | CREATE TABLE duplicating existing concepts |

---

## Agent Commands Reference

Agent commands are specialized AI prompts invoked via `/command-name` in Claude Code. Each agent has deep domain knowledge for its area.

### Development Agents

| Command | When to Use |
|---------|-------------|
| `/start-task` | **Entry point** — orchestrates full lifecycle (GH issue, worktree, confidence gate, agents) |
| `/backend-developer` | API routes, server actions, database operations, integrations |
| `/frontend-developer` | React components, pages, state management, responsive design |
| `/frontend-design` | High-quality UI design, landing pages, visual components |
| `/software-architect` | Database schema design, API contracts, system architecture |
| `/tdd` | Test-driven development (RED-GREEN-REFACTOR cycle) |
| `/test-automation` | Unit, integration, E2E test suites |
| `/ux-hcd-designer` | UX/HCD expert — research, personas, heuristics, accessibility |
| `/mobile-audit` | Mobile responsiveness and touch-target audit |

### Quality Agents

| Command | When to Use |
|---------|-------------|
| `/code-reviewer` | Thorough code review (quality, standards, security) |
| `/bug-finder` | Find edge cases, logic errors, async issues |
| `/debug` | Systematic 4-phase debugging (observe, hypothesize, test, fix) |
| `/quick-review` | Fast single-pass review (80% of `/vote-for-pr` in 20% of time) |
| `/vote-for-pr` | Full 5-agent consensus voting before PR creation |
| `/security-auditor` | Security review (auth, RLS, input validation, secrets) |

### Operations Agents

| Command | When to Use |
|---------|-------------|
| `/devops-infrastructure` | Deployments, CI/CD, monitoring, environment management |
| `/project-manager` | Task breakdown, delegation, phase management |
| `/data-analyst` | Revenue analytics, user metrics, product analytics |

### Business Agents

| Command | When to Use |
|---------|-------------|
| `/customer-support` | Help customers with questions and troubleshooting |
| `/sales-onboarding` | Guide prospects through purchase and onboarding |
| `/marketing-content` | Blog posts, social media, email campaigns |
| `/knowledge-base` | Product information, technical architecture, processes |
| `/documentation-writer` | API docs, user guides, developer guides |

### Workflow Agents

| Command | When to Use |
|---------|-------------|
| `/generate-prp` | Create a Product Requirements Plan for a feature |
| `/execute-prp` | Execute an existing PRP document |
| `/generate-agent-team` | Generate a complete multi-agent system for any SaaS |

### Customizing Agent Prompts

Each command file in `.claude/commands/` has `[YOUR_PRODUCT]` placeholders. Replace them with your product name and details:

```bash
# Quick replace across all commands
cd .claude/commands/
sed -i 's/\[YOUR_PRODUCT\]/MyApp/g' *.md
```

---

## PR Review Toolkit

A plugin with 6 specialized review agents that run before PR creation.

### Agents

| Agent | Focus |
|-------|-------|
| `code-reviewer` | CLAUDE.md compliance, security, bugs |
| `code-simplifier` | Complexity reduction, dead code |
| `silent-failure-hunter` | Error handling, unhandled promises |
| `pr-test-analyzer` | Test coverage gaps |
| `comment-analyzer` | Comment accuracy, stale comments |
| `type-design-analyzer` | Type safety, invariants |

### Usage

```
/pr-review-toolkit:review-pr              # Full review
/pr-review-toolkit:review-pr security     # Security focus
```

---

## Linting (oxlint)

[oxlint](https://oxc-project.github.io/docs/guide/usage/linter.html) is a blazing-fast JavaScript/TypeScript linter (~1 second for 700+ files). It replaces ESLint for speed-critical workflows.

### Usage

```bash
# Lint only files changed vs base branch (default: dev)
scripts/lint-changed.sh

# Lint all files
scripts/lint-changed.sh --all

# Auto-fix issues
scripts/lint-changed.sh --fix

# Both
scripts/lint-changed.sh --all --fix
```

### Configuration

The `.oxlintrc.json` file controls which rules are active:

```json
{
  "rules": {
    "no-unused-vars": "warn",
    "no-debugger": "error",
    "eqeqeq": "warn",
    "prefer-const": "warn",
    "require-await": "warn"
    // ... see file for full list
  }
}
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LINT_BASE_BRANCH` | `dev` | Branch to diff against for changed files |
| `LINT_SRC_DIR` | `src` | Source directory to lint |
| `LINT_EXTENSIONS` | `ts,tsx,js,jsx` | File extensions to include |

### Customizing

- **Add rules:** Edit `.oxlintrc.json`, see [oxlint rules](https://oxc-project.github.io/docs/guide/usage/linter/rules.html)
- **Change severity:** `"off"`, `"warn"`, or `"error"` per rule
- **Ignore patterns:** Add to the `ignorePatterns` array
- **Different src directory:** Set `LINT_SRC_DIR=lib` or similar

---

## CI/CD Deploy Gate

The deploy gate prevents creating PRs before the CI/CD preview deployment succeeds.

### How It Works

1. You push your branch
2. Run `scripts/check-deploy.sh` — it polls the GitHub Deployments API
3. When deployment succeeds, it writes a marker file: `/tmp/<project>-ci-verified-<SHA>`
4. The `check-ci-before-pr.sh` hook checks for this marker before allowing `gh pr create`

### Usage

```bash
# Push your branch
git push -u origin feature/GH-123-my-feature

# Check deployment status (polls up to 5 minutes)
scripts/check-deploy.sh

# Or check a specific commit
scripts/check-deploy.sh abc123def456...

# Now create PR (hook will allow it)
gh pr create --base dev
```

### Compatibility

Works with any CI/CD that reports via GitHub Deployments API:
- **Vercel** (automatic)
- **Netlify** (automatic)
- **GitHub Actions** (with `actions/deploy-pages` or custom deployment steps)
- **Railway**, **Render**, etc. (if configured to report deployments)

---

## Crash-Proof Sessions (tmux)

### Why tmux?

When VS Code crashes, all terminal sessions die — including your Claude Code session. With tmux, your session runs independently:

```
VS Code Crashes -> VS Code terminal dies -> tmux survives -> Claude session intact
```

### Session Setup

```bash
# Start/attach to default session
./scripts/claude-session.sh

# Start session for a worktree
./scripts/claude-session.sh GH-123-feature

# Just check prerequisites
./scripts/claude-session.sh --check
```

The session manager:
- Auto-detects your project name and worktree directory
- Checks all prerequisites (tmux, git, claude, gh)
- Shows git branch, worktree list, and beads status
- Launches Claude Code automatically
- Signs into 1Password if available

### Multiple Parallel Sessions

Run multiple Claude Code sessions, one per worktree:

```bash
# Terminal 1: Main development
./scripts/claude-session.sh main

# Terminal 2: Feature work
./scripts/claude-session.sh GH-123-new-feature

# Terminal 3: Bug fix
./scripts/claude-session.sh GH-456-critical-bug

# List all sessions
./scripts/claude-session.sh --list

# Kill a session
./scripts/claude-session.sh --kill GH-456-critical-bug
```

Each session is fully isolated and survives independently.

### tmux Cheat Sheet

| Action | Keys |
|--------|------|
| **Detach** (session keeps running) | `Ctrl+b d` |
| **Scroll** up/down | `Ctrl+b [` then arrow keys, `q` to exit |
| **New window** | `Ctrl+b c` |
| **Next/previous window** | `Ctrl+b n` / `Ctrl+b p` |
| **Split vertically** | `Ctrl+b %` |
| **Split horizontally** | `Ctrl+b "` |
| **Switch panes** | `Ctrl+b arrow-key` |
| **Kill pane** | `Ctrl+b x` |
| **List sessions** (from any terminal) | `tmux list-sessions` |
| **Attach to session** | `tmux attach -t session-name` |
| **Kill session** | `tmux kill-session -t session-name` |

### Windows Terminal Profile

Add a one-click launch profile to Windows Terminal:

1. Open Windows Terminal Settings (`Ctrl+,`)
2. Click "Add a new profile" -> "New empty profile"
3. Configure:

| Setting | Value |
|---------|-------|
| Name | Claude Session |
| Command line | `wsl.exe -d Ubuntu -- bash -c '/path/to/your-project/scripts/claude-session.sh'` |
| Starting directory | `\\wsl$\Ubuntu\home\<username>` |
| Icon | Any icon you like |

4. Save. Now launch Claude sessions from the Windows Terminal dropdown.

### Crash Recovery

#### VS Code Crashes (tmux survives)

1. Open any terminal (Windows Terminal, PowerShell, etc.)
2. Run: `tmux list-sessions` to see what's running
3. Reattach: `./scripts/claude-session.sh` or `tmux attach -t session-name`
4. Continue right where you left off

#### Full WSL Crash (everything dies)

If WSL itself crashes (computer restart, `wsl --shutdown`, etc.):

1. Start a new Claude Code session
2. Check your beads: `bd ready` (if using Beads)
3. Check git state: `git status`, `git log --oneline -5`, `git stash list`
4. Resume work from the last commit

**Tip:** The `wsl-crash-recovery` hook (in the templates) can auto-detect crashes and generate a continuation prompt. See `templates/worktree-workflow.md` for setup.

---

## Migrating Existing Repos to ext4

If you already have repos on `/mnt/c/` and want to move them to `~/repos/` for the performance benefits described in [Why WSL ext4?](#why-wsl-ext4-clone-into-repos-not-mntc), use the included migration script.

### Quick Migration (Single Repo)

```bash
# Migrate one repo (copies first, originals kept as backup)
scripts/migrate-to-ext4.sh /mnt/c/repos/your-project ~/repos/your-project
```

The script will:
1. Check ext4 has enough disk space
2. Copy the repo (excluding `node_modules`, `.next`, `.turbo`, `dist`)
3. Verify the copy (branch, remote, git integrity)
4. Prune stale worktree registrations (they point to old `/mnt/c/` paths)
5. Show a before/after speed comparison
6. Print next steps (reinstall dependencies, update VS Code, etc.)

### Bulk Migration (All Repos)

```bash
# Migrate everything under a directory
scripts/migrate-to-ext4.sh --all /mnt/c/repos/github ~/repos
```

### Post-Migration Checklist

After migrating, you need to:

1. **Reinstall `node_modules`** — excluded from copy to save space/time
   ```bash
   cd ~/repos/your-project
   npm install   # or pnpm install, yarn install
   ```

2. **Update VS Code** — open from the new path
   ```bash
   code ~/repos/your-project
   # Remove old path from VS Code recent workspaces
   ```

3. **Recreate worktrees** — old registrations pointed to `/mnt/c/`
   ```bash
   cd ~/repos/your-project
   git worktree prune
   mkdir -p ~/repos/your-project-worktrees
   ```

4. **Update Claude Code project settings** — if you have memory/settings under the old path
   ```bash
   OLD="$HOME/.claude/projects/-mnt-c-repos-github-your-project"
   NEW="$HOME/.claude/projects/-home-$(whoami)-repos-your-project"
   if [ -d "$OLD" ]; then
     mkdir -p "$NEW"
     cp -a "$OLD"/* "$NEW"/
     echo "Migrated Claude project settings"
   fi
   ```

5. **Verify everything works**
   ```bash
   cd ~/repos/your-project
   git status && git fetch --all
   gh issue list --limit 3        # Verify gh CLI works
   ```

6. **Clean up old copy** (after 1-2 weeks of stable operation)
   ```bash
   rm -rf /mnt/c/repos/github/your-project
   ```

### Windows Terminal Profile (Optional)

If you use Windows Terminal, create a profile that launches directly into your WSL repos:

| Setting | Value |
|---------|-------|
| Name | Dev (WSL) |
| Command line | `wsl.exe -d Ubuntu -- bash -c 'cd ~/repos && exec bash'` |
| Starting directory | `\\wsl$\Ubuntu\home\<username>\repos` |


---

## Worktree-First Workflow

### Why Worktrees

Git worktrees give you **isolated copies** of your repo — one per feature/bug. Benefits:

- **No branch switching** — each worktree is always on its branch
- **Parallel work** — multiple Claude sessions on different features simultaneously
- **Clean separation** — changes in one feature can't accidentally affect another
- **No stale state** — every worktree starts fresh from the base branch

### Full Lifecycle

```bash
# 1. Create GitHub issue
gh issue create --title "Add dark mode" --body "..." --label "enhancement"
# Returns: GH-123

# 2. Create worktree (isolated workspace)
git pull origin dev
git worktree add ../your-project-worktrees/GH-123-dark-mode -b feature/GH-123-dark-mode dev

# 3. (Optional) Create bead for persistent tracking
bd create "Add dark mode (GH-123)" -p 2

# 4. Work in worktree
cd ../your-project-worktrees/GH-123-dark-mode

# 5. CONFIDENCE GATE — ask questions until 8/10 confident (see below)

# 6. Implement, commit frequently
git add -A && git commit -m "feat: add dark mode toggle (GH-123)"

# 7. Rebase from dev BEFORE pushing
git fetch origin && git rebase origin/dev

# 8. Lint + typecheck
scripts/lint-changed.sh

# 9. Push and verify deployment
git push -u origin feature/GH-123-dark-mode
scripts/check-deploy.sh

# 10. Create PR (after deployment succeeds)
gh pr create --base dev --title "feat: add dark mode" --body "Closes #123"

# 11. After merge, cleanup
git worktree remove ../your-project-worktrees/GH-123-dark-mode
git worktree prune
```

### Confidence Gate (8/10 Rule)

**Before writing any code, reach 8/10 confidence you can succeed.**

The orchestrator evaluates:

| Dimension | Question |
|-----------|----------|
| Requirements | Do I know exactly what the user wants? |
| Scope | Which files need to change? Hidden dependencies? |
| Codebase | Have I read the relevant existing code? |
| Data model | Do I know the schema and relationships? |
| Security | Auth/authorization requirements clear? |
| Edge cases | Error states, empty states, boundaries considered? |
| Testing | How will this be verified? |
| Risk | Could this break something else? |

If confidence < 8/10, **ask the user clarifying questions** before proceeding.

**Skip the gate only for:** typo fixes, comment-only changes, exact user-provided code.

---

## Templates Reference

Templates are installed to `.claude/templates/` for reference:

| Template | Description |
|----------|-------------|
| `CLAUDE.md.template` | Starter project instructions for Claude Code |
| `worktree-workflow.md` | Complete worktree-first methodology, confidence gate, multi-agent coordination |
| `hookify-rules.md` | Full hookify rules documentation and authoring guide |
| `model-selection.md` | Cost optimization guide for Claude model selection |
| `agents.md` | Agent orchestration strategy and when-to-use guide |
| `feature-prp-template.md` | Product Requirements Plan template for features |
| `scaffold-project.md` | Generic full-stack monorepo folder structure prompt for new projects |

> **Quick start:** Run `bash scripts/scaffold-project.sh ~/repos/my-new-app` to create the full folder structure instantly, or paste the prompt from `templates/scaffold-project.md` into Claude Code.

---

## Customization Guide

### Changing the Base Branch

If your base branch is `main` instead of `dev`:

```bash
# For linting
export LINT_BASE_BRANCH=main

# Or add to your .bashrc / .zshrc
echo 'export LINT_BASE_BRANCH=main' >> ~/.bashrc
```

Several hooks also reference `dev` — search and replace:
```bash
cd .claude/hooks/
grep -l "dev" *.sh
# Edit each file to use your base branch
```

### Adding Project-Specific Hooks

Create new hooks in `.claude/hooks/` and register them in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/my-custom-hook.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

### Adding/Removing Lint Rules

Edit `.oxlintrc.json`:

```json
{
  "rules": {
    "no-unused-vars": "off",        // Disable
    "no-console": "error",          // Make stricter
    "new-rule-name": "warn"         // Add new
  }
}
```

### Non-JavaScript/TypeScript Projects

For Python, Go, Rust, etc.:
- The **hooks** work with any language (they check git, not code)
- The **hookify rules** are language-agnostic patterns
- The **agent commands** are framework-agnostic (adapt the tech stack sections)
- Replace **oxlint** with your language's linter (ruff for Python, golangci-lint for Go, etc.)
- Update `scripts/lint-changed.sh` with your linter command

---

## Troubleshooting

### "tmux: command not found"

```bash
sudo apt update && sudo apt install tmux
```

### "claude: command not found" in tmux

The Claude CLI may not be in PATH within tmux:

```bash
which claude
# Add to ~/.bashrc if needed:
echo 'export PATH="$PATH:/path/to/claude"' >> ~/.bashrc
```

### Hook blocked my command

Hooks block operations for safety. Read the error message — it tells you exactly what to do:

- **"Working directly in main repo"** — Create a worktree first
- **"Cross-worktree modification"** — Switch to the correct worktree session
- **"CI/CD deployment not verified"** — Run `scripts/check-deploy.sh` first
- **"Push without lint"** — Run `scripts/lint-changed.sh` first

### Lint tools missing

```bash
# Install oxlint
npm install -g oxlint

# Verify
oxlint --version
```

### Worktree conflicts after rebase

```bash
cd ../your-project-worktrees/GH-123-feature
git fetch origin
git rebase origin/dev
# Resolve conflicts if any, then:
git rebase --continue
```

### Permission denied on scripts

```bash
chmod +x scripts/*.sh
chmod +x .claude/hooks/*.sh
```

---

## Uninstall

To remove the toolkit from a project:

```bash
# Remove hooks and commands
rm -rf .claude/hooks/ .claude/commands/ .claude/plugins/pr-review-toolkit/

# Remove hookify rules
rm -f .claude/hookify.*.local.md

# Remove settings (or manually remove hook entries)
rm .claude/settings.json

# Remove scripts
rm scripts/lint-changed.sh scripts/check-deploy.sh scripts/claude-session.sh

# Remove config
rm .oxlintrc.json

# Remove templates
rm -rf .claude/templates/
```

---

## License

MIT

---

## Contributing

This toolkit is designed to be forked and customized. If you improve a hook or add a useful agent command, consider contributing it back.
