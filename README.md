# Claude Dev Toolkit

A comprehensive development toolkit for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that enforces quality, security, and workflow discipline across any project. Includes hooks, linting, 26 AI agent prompts, crash-proof sessions, and CI gates.

Born from 3000+ hours of real-world development on a production SaaS platform — every hook and rule exists because something went wrong without it.

> **Heads up — this toolkit is heavy.** It is tuned for a multi-year, multi-developer SaaS codebase with RLS, migrations, deploy gates, and many parallel worktrees. If your project is smaller — a side project, an internal tool, a non-SaaS app, or anything that doesn't need 26 specialized agents — the full toolkit is overkill. Skip to [Lighter setups for non-SaaS projects](#lighter-setups-for-non-saas-projects) for alternatives (Claude Desktop, the Claude Code VS Code extension, and Claude Cowork) that cover almost every other use case at a fraction of the token cost.

---

## Demo

A complete **60-minute presentation** built with this toolkit is publicly deployed at:

**[zanebarker-ops.github.io/claude-dev-toolkit](https://zanebarker-ops.github.io/claude-dev-toolkit/)**

The slide source lives in a private companion repo and is auto-deployed to GitHub Pages on every push.

The arc:

1. **Setup** — CLAUDE.md, hooks, hookify, MCPs *(12 min)*
2. **Workflow** — issue → bead → worktree → confidence gate → PR *(15 min)*
3. **Agents** — orchestrator + 26 specialists, model economics *(10 min)*
4. **Claude Routines** — cron agents that verify outcomes, not code *(15 min, the headline)*
5. **Take-home** — `git clone && bash install.sh` *(3 min)*

## Table of Contents

- [Demo](#demo)
- [Lighter setups for non-SaaS projects](#lighter-setups-for-non-saas-projects)
- [What's Included](#whats-included)
- [Platform support & what's actually active](#platform-support--whats-actually-active)
- [Prerequisites](#prerequisites)
  - [GitHub Account Setup (start here if new to GitHub)](#github-account-setup-start-here-if-new-to-github)
  - [WSL2 Setup (Windows)](#wsl2-setup-windows)
  - [WSL + tmux + Windows Terminal Multi-Session Runbook](#wsl--tmux--windows-terminal-multi-session-runbook)
  - [VS Code + GitHub Setup](#vs-code--github-setup)
  - [Required Tools (Linux / WSL)](#required-tools-linux--wsl)
  - [Required Tools (macOS)](#required-tools-macos) — see also [macOS + tmux + iTerm2 runbook](docs/macos-tmux-terminal-setup.md)
  - [Optional Tools](#optional-tools)
- [Installation](#installation)
- [Hooks Reference](#hooks-reference)
- [Hookify Rules Reference](#hookify-rules-reference)
- [Threat-Level Guardrails (Optional Companion)](#threat-level-guardrails-optional-companion)
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

## Lighter setups for non-SaaS projects

The toolkit in this repo exists because production SaaS at scale needs the full Confidence Gate, multi-agent review, and CI-enforced workflow discipline. **Most projects do not.** If you are not running RLS migrations against prod or coordinating 15 parallel features, one of the following lighter Claude configurations will get you 80%+ of the value with a small fraction of the setup time and token spend.

| Setup | Best for | Install | What you get |
|---|---|---|---|
| **Claude Desktop** | Casual coding, scripts, notebooks, anything you'd prompt-and-paste today | [claude.ai/download](https://claude.ai/download) (macOS / Windows) | Native chat app with project memory, file uploads, and MCP server support. No CLI to install. |
| **Claude Code — VS Code extension** | Side projects, internal tools, single-developer repos | Install **Claude Code** from the [VS Code marketplace](https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code) and sign in with your Anthropic account | Inline edits, diff review, and slash commands directly in the editor. No tmux, no hooks, no worktrees required. |
| **Claude Cowork** | Multi-step *knowledge work* — research, docs, spreadsheets — not just code | Open Claude Desktop on macOS / Windows → click the **Cowork** tab (requires a paid plan: Pro, Max, Team, or Enterprise — see the [setup guide](https://support.claude.com/en/articles/13345190-get-started-with-claude-cowork)) | Agentic, multi-step task execution inside the desktop app — file organization, spreadsheets with formulas, multi-source research synthesis. |

### Pick one in 30 seconds

- **"I just want Claude to help me code in a small repo."** → Install the **Claude Code VS Code extension**.
- **"I want to chat with Claude about files and have it edit them, no terminal."** → **Claude Desktop**.
- **"I need Claude to do non-code work — research, documents, spreadsheets — on its own."** → **Claude Cowork** (inside Claude Desktop).
- **"I'm running a production SaaS with parallel features, migrations, and a deploy gate."** → You are in the right place. Keep reading.

### Recommended extensions and MCP servers (for the lighter setups)

If you go with the **VS Code extension** or **Claude Desktop**, the following extras cover most of what the heavy toolkit gives you, without the operational overhead.

**VS Code extensions worth installing alongside Claude Code:**

- `GitLens` — inline blame and history; replaces several of the heavy toolkit's git workflow hooks.
- `GitHub Pull Requests` — review and create PRs from the editor; covers what `gh pr` automation does in this toolkit.
- `Error Lens` — surfaces compile/lint errors inline so Claude sees them in context.
- `ESLint` / `Prettier` (or your stack's equivalent — `ruff` for Python, `rustfmt` for Rust, etc.) — the lint layer this toolkit's `oxlint` runner duplicates at CI time.
- `Markdown All in One` — useful if you use `CLAUDE.md` (you should, see below).

**MCP servers worth attaching to Claude Desktop or the VS Code extension:**

- [`filesystem`](https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem) — read/write files in a sandboxed directory.
- [`git`](https://github.com/modelcontextprotocol/servers/tree/main/src/git) — diff, log, blame, and commit from inside Claude.
- [`github`](https://github.com/modelcontextprotocol/servers/tree/main/src/github) — issues, PRs, and CI status without leaving the chat.
- `memory-keeper` — persistent project memory across sessions. This repo's [`bootstrap.sh`](bootstrap.sh) installs it at the user level; you can install it standalone too if you only want the memory layer.

**Always do this, even on small projects:** drop a short `CLAUDE.md` at the project root listing the stack, the test command, and one or two "do not do this" rules. Even without any hooks or agents, that one file resolves a surprising share of issues. See [`templates/`](templates/) for a starting point you can trim down.

### When to graduate to the full toolkit

Consider the full toolkit when you start hitting any of these:

- More than ~3 features in flight at once and merges are starting to collide.
- A production deploy you cannot easily roll back (migrations, RLS, paying users).
- You're running Claude for hours per day and want hard rails against accidental destructive edits.
- You need consistent multi-agent PR review on every change.

Until then — stay lighter. The heavy toolkit's costs (3.5–4B tokens/month at full burn) only pay off when the alternative is a production incident.

---

## What's Included

| Category | Count | Description |
|----------|-------|-------------|
| **Hooks** | 18 | Event-driven scripts that enforce workflow rules |
| **Hookify Rules** | 15 | Markdown-based rules for blocking/warning on patterns |
| **Agent Commands** | 26 | Specialized AI agent prompts (`/start-task`, `/security-auditor`, etc.) |
| **PR Review Toolkit** | 6 agents | Automated multi-agent code review before PRs |
| **Scripts** | 5 (installed) | Lint runner, deploy checker, session manager, ext4 migration, **doctor** (health check) |
| **Templates** | 9 | CLAUDE.md, worktree workflow, model selection, agents, PRP, hookify docs, coordination system |
| **Config** | 2 | `.oxlintrc.json`, `settings.json` template |
| **Multi-Vendor Review** | 18 files | Codex-based binding review loop (hooks + scripts + lib + verify tests) |

> The **Hookify Rules** count above is "shipped", not "active" — those rules need
> a loader this repo does not include. See
> [Platform support & what's actually active](#platform-support--whats-actually-active).

---

## Platform support & what's actually active

> **Read this before installing.** The toolkit's enforcement is built from **bash
> hooks** plus optional CLI tools. What is actually *active* depends on your OS,
> your shell, and which tools you have installed. `install.sh` never installs
> system tools, and any hook whose tool is missing **fails open** (skips silently)
> unless noted below. This section is here so you don't assume a protection is on
> when it isn't.

### By platform

| Platform | Do the hooks fire? | Notes |
|---|---|---|
| **macOS / Linux** | ✅ Yes, natively | The intended environment. Bash hooks run reliably; just install the optional CLI tools below for full coverage. |
| **Windows + WSL2** | ✅ Yes | Run the toolkit *inside* WSL. This is the supported path on Windows. |
| **Windows (native)** | ⚠️ Not guaranteed | Hooks are `.sh` files; whether Claude Code's Windows hook runner executes them through Git Bash varies by version/config. `install.sh` itself needs Git Bash or WSL to run, and `tmux` (crash-proof sessions) has no native Windows build. **Treat enforcement as off until you verify it** — or just use WSL2. |

### By feature (assuming the hook fires on your platform)

| Feature | Hook / script | Requires | If the requirement is missing |
|---|---|---|---|
| Worktree gating & containment | `check-worktree`, `check-cross-worktree`, `enforce-worktree-path` | bash, git | Hook can't run → **no gating** |
| Lint gate before commit | `pre-commit-lint` | **oxlint** + `scripts/lint-changed.sh` | **Fails open** — commit proceeds unchecked |
| Secret scan before commit | `gitleaks-scan` | **gitleaks** + python3 | **Fails open** — no secret scanning |
| `.env` read block | `block-env-read` | bash | Hook can't run → no block |
| CI gate / PR-to-`main` nudge | `check-ci-before-pr`, `warn-pr-to-main` | bash, python3 | Hook can't run → no gate/nudge |
| Crash recovery | `wsl-crash-recovery` | **jq** | Degraded or no recovery prompts |
| Crash-proof sessions | `scripts/claude-session.sh` | **tmux** | Unavailable |
| Codex review loop (opt-in) | `orchestration/` | jq + Codex CLI | Loop disabled |
| Docker-per-worktree (opt-in) | `docker/` | docker + bash | Unavailable |
| Threat-level guardrails (opt-in) | external companion | python3 | See its README |

### Two silent gotchas worth knowing up front

1. **Hookify rules are not active by default.** The 15 `hookify.*.local.md` rules are
   declarative markdown that needs a **loader this repo does not ship**, and
   `settings.json` never references them. Their two important protections
   (no-direct-`main`, worktree containment) are **duplicated by shell hooks**, so
   you're covered there — but the other ~13 (RLS / console.log / migration
   warnings, etc.) do nothing until you supply a loader. See
   [Hookify Rules Reference](#hookify-rules-reference).
2. **Installing over an existing `settings.json` wires nothing.** `install.sh` will
   not overwrite an existing `.claude/settings.json` — it copies the hook *files*
   but registers **zero** hooks. You must merge the template's `hooks` block
   yourself, or no enforcement runs. The installer warns loudly when this happens.

**Check your own machine in one command.** After installing, run the bundled
health check — it reports, on whatever machine it runs, which enforcement is
ACTIVE vs OFF (fail-open tools, hook wiring, platform caveats) and changes
nothing:

```bash
./scripts/doctor.sh
```

`install.sh` also prints a prerequisite report at the end stating the consequence
of each missing tool.

---

## Concepts: Skill · Agent · MCP · Workflow

Before diving in, read **[`docs/primitives.md`](docs/primitives.md)** — a 400-line explainer covering the four building blocks of Claude Code (what each one is, where it lives, how the agent gets it) and the **soft-vs-hard enforcement model** (when to use CLAUDE.md prose vs hooks vs a hybrid).

If you're new to Claude Code or have ever wondered *"why didn't the agent do the thing I told it to?"* — that's the doc.

---

## Prerequisites

### GitHub Account Setup (start here if new to GitHub)

This toolkit's core workflow — `/start-task`, the worktree lifecycle, the CI deploy gate — is built on top of GitHub. Every task begins with `gh issue create`, every change goes through a pull request, and every hook assumes `git` and `gh` are wired up and working.

**If you have only signed up at [github.com](https://github.com) and nothing else, do everything in this section before moving on.** The rest of the prerequisites assume the steps below are complete.

#### What GitHub is, in 30 seconds

- **Repository (repo)** — a folder of code that GitHub stores and version-controls. You will have one per project.
- **Issue** — a numbered ticket on a repo (e.g. `GH-123`). The toolkit uses issues as the unit of work: one issue, one branch, one worktree, one pull request.
- **Pull request (PR)** — a proposal to merge one branch into another. The toolkit's CI/deploy gate runs on every PR.
- **`git`** — the command-line tool that tracks your local changes. **GitHub is not git** — GitHub is the remote service that hosts the repo `git` pushes to.
- **`gh`** — the official GitHub command-line tool. Lets you create issues, open PRs, and view CI status without leaving the terminal. The toolkit calls `gh` constantly.

#### Step 1 — Create or sign in to your GitHub account

1. Go to [github.com](https://github.com) and sign in. If you don't have an account, click **Sign up** and follow the prompts (free tier is fine).
2. Verify your email address (check your inbox). Several of the steps below silently fail if your email isn't verified.
3. Pick a username you're willing to live with — it shows up in every URL and every commit. You can change it later but it breaks every existing link.

#### Step 2 — Create your first repository (via the GitHub website)

You can do this from the CLI later, but for your very first repo it's easier in the browser.

1. Click the **+** icon in the top-right of github.com → **New repository**.
2. **Repository name** — pick something short and lowercase, e.g. `my-first-project`.
3. **Description** — optional, one line.
4. **Public or Private** — Private is fine for learning. You can flip this later.
5. **Initialize this repository with:** check **Add a README file**. Leave `.gitignore` and license blank for now.
6. Click **Create repository**.

You should now be looking at `https://github.com/<your-username>/my-first-project` with a single `README.md` file in it. **Bookmark this URL** — you'll need it in Step 5.

#### Step 3 — Confirm Issues are enabled on the repo

The toolkit's `/start-task` command will run `gh issue create` against this repo. If issues are disabled, the workflow fails at step one.

1. On your repo page, click **Settings** (top-right tab).
2. Scroll to the **Features** section.
3. Make sure **Issues** is **checked**. (It is on by default for new repos — this is just a sanity check.)

#### Step 4 — Install the GitHub CLI (`gh`)

You need `gh` installed on the same machine where you'll run Claude Code. The full install commands for WSL/Linux and macOS are below in [Required Tools (Linux / WSL)](#required-tools-linux--wsl) and [Required Tools (macOS)](#required-tools-macos). Do that install now, then come back here.

Quick check that it worked:

```bash
gh --version
# Should print something like: gh version 2.x.x
```

#### Step 5 — Authenticate `gh` to your GitHub account

```bash
gh auth login
```

You'll be asked a series of questions. Here are the answers for the common case (working against github.com over HTTPS, using a browser to log in — easiest path for a beginner):

| Prompt | Answer |
|---|---|
| What account do you want to log into? | **GitHub.com** |
| What is your preferred protocol for Git operations? | **HTTPS** |
| Authenticate Git with your GitHub credentials? | **Yes** |
| How would you like to authenticate GitHub CLI? | **Login with a web browser** |

It will print a one-time code (e.g. `ABCD-1234`) and open your browser. Paste the code, click **Authorize**, and return to the terminal. You should see `✓ Logged in as <your-username>`.

> **Why HTTPS and not SSH?** SSH (set up later in [VS Code + GitHub Setup](#vs-code--github-setup)) is the long-term recommendation for pushing code, but `gh auth login` over HTTPS is the lowest-friction first step. Once SSH keys are in place, you can switch with `gh auth refresh -h github.com -s admin:public_key`.

#### Step 6 — Configure your git identity

Every commit is signed with a name and email. Set these once, globally:

```bash
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

Use the **same email address** you registered with GitHub — otherwise commits won't be associated with your GitHub profile (you'll see grey "unknown author" avatars on github.com).

#### Step 7 — Verify the full chain works

Run all four of these. If any fail, fix that step before continuing — every downstream toolkit feature assumes they pass.

```bash
# 1. gh is authenticated
gh auth status
# Expect: "Logged in to github.com as <your-username>"

# 2. You can read your own repos
gh repo list --limit 5
# Expect: a list including my-first-project

# 3. You can create an issue (test against the repo you just made)
gh issue create \
  --repo <your-username>/my-first-project \
  --title "Test issue from gh CLI" \
  --body "If you can read this, gh is wired up correctly."
# Expect: a URL like https://github.com/<your-username>/my-first-project/issues/1

# 4. You can clone over HTTPS
cd ~ && mkdir -p repos && cd repos
git clone https://github.com/<your-username>/my-first-project.git
cd my-first-project && ls
# Expect: README.md
```

Close the test issue afterwards (`gh issue close 1 --repo <your-username>/my-first-project`) — it has served its purpose.

#### What you can skip for now

- **SSH keys** — not strictly required to start. The toolkit works fine over HTTPS. Set these up later via [VS Code + GitHub Setup](#vs-code--github-setup) when you're comfortable.
- **Organizations / teams** — only needed if you're collaborating with others under a shared GitHub org.
- **GitHub Actions / CI config** — the toolkit ships its own CI templates; you don't need to author workflows by hand to get started.
- **Branch protection rules** — recommended later for `main`, but the toolkit's confidence gate already enforces most of what branch protection covers.

You're done with the GitHub side. Continue with the platform-specific setup below.

---

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

### WSL + tmux + Windows Terminal Multi-Session Runbook

Once WSL is up, follow the **end-to-end runbook** in [`docs/wsl-tmux-terminal-setup.md`](docs/wsl-tmux-terminal-setup.md) to finish the workstation setup:

1. Install tmux inside Ubuntu with sane defaults (50k scrollback, mouse on, base-index 1).
2. Drop a portable launcher at `~/scripts/wsl-session.sh` — a generic `tmux new-session -A -s "$NAME"` wrapper that attaches to a named session if it exists, otherwise creates it.
3. Replace Windows Terminal's `settings.json` with a config that exposes **15 named profiles** (`Session - Main`, `Session 2` … `Session 15`), each invoking the launcher with its own session name via `wsl.exe -d Ubuntu -- bash -lc "$HOME/scripts/wsl-session.sh <name>"`.

#### Why this is its own runbook

The runbook is **portable across machines** — no hardcoded usernames, repo paths, or per-machine GUIDs that need editing. The pre-generated GUIDs in the doc are unique within a single `settings.json` (which is all Windows Terminal requires); you can paste the file onto any Windows box and it works.

#### How the two layers work together

This toolkit gives you **two complementary tmux layers**:

| Layer | Script | Scope | Purpose |
|---|---|---|---|
| **Outer** (terminal-tab layer) | `~/scripts/wsl-session.sh` (from runbook) | Per-machine, project-agnostic | Each Windows Terminal tab opens a *named, sticky* tmux session. Closing the tab does not kill the work. |
| **Inner** (Claude-session layer) | [`scripts/claude-session.sh`](scripts/claude-session.sh) (in this repo) | Per-project / per-worktree | Inside any tab, launch a tmux session that runs Claude Code for a specific repo/worktree. Survives VS Code crashes. |

A typical workstation layout:

```
Windows Terminal (15 tabs, each backed by tmux via wsl-session.sh)
├─ Session - Main      → cd ~/repos/your-app          → ./scripts/claude-session.sh
├─ Session 2           → cd ~/repos/your-app-worktrees/GH-123-feature → ./scripts/claude-session.sh GH-123-feature
├─ Session 3           → cd ~/repos/your-app-worktrees/GH-456-bugfix  → ./scripts/claude-session.sh GH-456-bugfix
├─ Session 4           → tail -f /var/log/dev-server.log  (long-running process)
├─ Session 5–10        → other worktrees, MCP servers, dashboards
└─ Session 11–15       → ad-hoc throwaway work
```

Both layers detach with `Ctrl-b d`. Both attach with `tmux attach -t <name>`. Re-opening a closed tab simply re-attaches to the existing tmux session — your scrollback, processes, and Claude session are all intact.

> **Skip if on macOS / native Linux.** The runbook is Windows-specific. On macOS, just use `scripts/claude-session.sh` directly inside iTerm2 / Terminal — no outer layer needed because closing a tab there does not pose the same fragility.

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

Replace `your-org/your-project` below with your own GitHub org/user and repo name.

```bash
# Clone into WSL filesystem (native ext4 — always do this)
cd ~
mkdir -p repos && cd repos
git clone git@github.com:your-org/your-project.git  # <-- replace with your repo
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

### Required Tools (Linux / WSL)

Install these in WSL or any Debian/Ubuntu Linux:

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

### Required Tools (macOS)

Same toolchain as Linux/WSL — uses [Homebrew](https://brew.sh) for installs. The full workflow (worktrees, beads, MCP, parallel tmux sessions) works identically on macOS.

```bash
# Homebrew (skip if already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Node.js (via nvm — recommended for managing multiple versions)
brew install nvm
mkdir -p ~/.nvm
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc
echo '[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"' >> ~/.zshrc
source ~/.zshrc
nvm install --lts
nvm use --lts

# Claude Code CLI
npm install -g @anthropic-ai/claude-code
claude auth login   # follow prompts to authenticate

# oxlint (fast linter)
npm install -g oxlint

# GitHub CLI
brew install gh
gh auth login

# tmux (crash-proof sessions — keeps your Claude sessions alive across IDE/terminal crashes)
brew install tmux

# Git (usually pre-installed; install latest via brew if needed)
brew install git

# gitleaks (secret scanning, used by hooks/gitleaks-scan.sh)
brew install gitleaks

# jq (used by some hooks for JSON parsing)
brew install jq
```

#### macOS-specific notes

- **Filesystem performance**: macOS native filesystem (APFS) is fast. There's no equivalent of the WSL `ext4` vs `/mnt/c/` issue. Clone repos wherever you like.
- **Worktrees**: work identically. Convention is still `<project>-worktrees/` as a sibling to your main repo. The toolkit's `enforce-worktree-path.sh` hook honors this.
- **MCP servers**: install via `npm`/`npx` like on Linux. No platform-specific gotchas.
- **15-session tmux setup**: end-to-end macOS runbook at [`docs/macos-tmux-terminal-setup.md`](docs/macos-tmux-terminal-setup.md) — covers tmux, iTerm2 Dynamic Profiles, and the 15-named-session pattern using the toolkit's `scripts/claude-session.sh`.
- **Beads (`bd`)**: install per the project's instructions (typically `cargo install` or a release binary). No platform-specific build issues.
- **Apple Silicon (M-series)**: all tools above run native ARM. No Rosetta needed.

```bash
# Verify everything is wired
node --version          # → v20+ or v22+
claude --version        # → 2.x.x
oxlint --version
gh --version
tmux -V
git --version
gitleaks version
jq --version
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

> **Two installers, separate concerns:**
> - `install.sh` → Claude Code hooks/commands/templates into `.claude/` (per project)
> - `install-git-hooks.sh` → Optional git hooks (e.g. `pre-push-review-reminder`) into `.git/hooks/` (per clone). Run after `install.sh` if you want them.

### Quick paths

```bash
# Clone the toolkit
git clone https://github.com/zanebarker-ops/claude-dev-toolkit.git
cd claude-dev-toolkit

# (1) Brand-new machine — install everything + drop into a project in one go
./bootstrap.sh /path/to/your-project

# (2) Brand-new machine — just set up the host (run claude auth login after)
./bootstrap.sh

# (3) Already have tmux/Node/Claude installed — just install the toolkit into a project
./install.sh /path/to/your-project

# (4) Verify what's already on the box (no install)
./bootstrap.sh --check
```

After `bootstrap.sh` finishes:
1. Run `claude auth login` to authenticate the Claude Code CLI.
2. (WSL only) Copy the Windows Terminal `settings.json` from [`docs/wsl-tmux-terminal-setup.md`](docs/wsl-tmux-terminal-setup.md) Step 7 into `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` to expose the 15 named session profiles.
3. Inside any tmux session, press `prefix + I` (default: `Ctrl-b I`) to fetch all the plugins (`bootstrap.sh` tries to do this automatically, but if it didn't work this is the manual fallback).

### MCP servers configured by `bootstrap.sh`

`bootstrap.sh` also wires up the [`memory-keeper`](https://www.npmjs.com/package/memory-keeper) MCP server at the **user level** (in `~/.claude.json`), so it's available to Claude Code across every project on the box.

```json
{
  "mcpServers": {
    "memory-keeper": {
      "command": "npx",
      "args": ["-y", "memory-keeper"]
    }
  }
}
```

What it does: persists facts between Claude conversations (e.g. "engineer X is on PTO this week", "this repo's lint runner lives at scripts/lint-worktree.sh"). Cross-session memory.

The merge into `~/.claude.json` is **idempotent** — re-running `bootstrap.sh` won't duplicate the entry, and won't touch any other MCP servers you've added manually. The actual `memory-keeper` package is lazy-installed by Claude Code via `npx` the first time you use it; you don't need to `npm install` it yourself.

To add other MCP servers later, edit `~/.claude.json` directly. Common patterns:

```json
{
  "mcpServers": {
    "memory-keeper": { "command": "npx", "args": ["-y", "memory-keeper"] },
    "my-other-mcp":  { "command": "npx", "args": ["-y", "@some-org/some-mcp"] }
  }
}
```

### Manual install path

```bash
# Clone the toolkit
git clone git@github.com:zanebarker-ops/claude-dev-toolkit.git ~/claude-dev-toolkit

# Install into your project
~/claude-dev-toolkit/install.sh /path/to/your-project
```

The installer:
1. Copies all 18 hooks to `.claude/hooks/` (sets executable bit)
2. Copies 23 agent commands to `.claude/commands/`
3. Creates `.claude/settings.json` with hook registrations (won't overwrite existing)
4. Copies `.oxlintrc.json` to project root (won't overwrite existing)
5. Copies 4 scripts to `scripts/` (lint, deploy, session manager)
6. Copies 15 hookify rules to `.claude/` (won't overwrite existing)
7. Copies reference templates to `.claude/templates/`
8. Installs PR review toolkit to `.claude/plugins/`
9. Generates a starter `CLAUDE.md` (won't overwrite existing)

**After installing:**
1. Edit `CLAUDE.md` with your project details
2. Review `.claude/settings.json` hook configuration
3. Replace `[YOUR_PRODUCT]` in `.claude/commands/*.md` with your product name
4. Set `LINT_BASE_BRANCH` env var if your base branch isn't `main`

---

## Hooks Reference

> Hooks are the **hard-enforcement** primitive — they intercept tool calls and can block, modify, or augment them. See [`docs/primitives.md`](docs/primitives.md) for how hooks fit alongside skills, agents, and MCPs.

Hooks are shell scripts that run automatically before/after Claude Code tool calls. They enforce workflow rules without you having to remember them.

> **Full reference:** [`hooks/README.md`](hooks/README.md) — explains the 4 event types, the block-vs-inform model, per-hook details, customization, debugging.

### PreToolUse Hooks (run BEFORE a tool executes)

| Hook | Trigger | What It Does |
|------|---------|-------------|
| `check-worktree.sh` | Edit, Write, Bash | Blocks operations in main repo on `main` — forces worktree usage |
| `check-cross-worktree.sh` | Edit, Write | Blocks editing files outside the current worktree |
| `enforce-worktree-path.sh` | Bash | Ensures Bash commands target the correct worktree |
| `pre-commit-lint.sh` | Bash (git commit) | Runs lint before allowing git commit |
| `check-ci-before-pr.sh` | Bash (gh pr create) | Blocks PR creation unless CI/CD deployment verified |
| `gitleaks-scan.sh` | Bash (git commit) | Scans staged files for secrets/credentials via gitleaks |
| `warn-pr-to-main.sh` | Bash (gh pr create) | Warns when creating a PR directly to main/master |
| `block-env-read.sh` | Read | Blocks reading .env files to prevent credential exposure |
| `security-check.sh` | **opt-in** (Bash, git commit) | Pre-commit checks: RLS on migrations, no secret keys in client code, auth on API routes. **Not registered by default** — checks are tech-stack-specific (Supabase RLS, Next.js API routes). Register manually in `.claude/settings.json` after customizing the script for your project. |
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
| `pre-push-review-reminder` | **git hook** (not Claude Code) | Reminds to run review skills on `git push` — installed via `install-git-hooks.sh` (see Installation) |

### How Hooks Work

Hooks are registered in `.claude/settings.json`. Each hook:
- Receives tool call context via stdin (JSON)
- **Exit 0** = allow the operation
- **Exit 2** = block the operation (stderr is shown to Claude as feedback)
- Runs with a timeout (default 3-5 seconds)

---

## Hookify Rules Reference

Hookify rules are lightweight markdown files that define pattern-matching rules. They complement hooks with simpler, declarative checks.

> ⚠️ **Not active by default.** Hookify rules are *declarative descriptions* — they
> only fire if you wire a **loader** into `settings.json` that reads and applies
> them. **This repo does not ship that loader**, and the installed `settings.json`
> does not reference one. So the rules below are **documentation of intent, not
> live enforcement**, until you supply a loader (or port a rule to a shell hook).
> The two that matter — `block-direct-main` and `block-cross-worktree` — are
> already enforced independently by the **shell** hooks (`check-worktree.sh`,
> `check-cross-worktree.sh`), so those protections are live regardless. The rest
> are inert until wired. See [`hookify-rules/README.md`](hookify-rules/README.md).

> **Full reference:** [`hookify-rules/README.md`](hookify-rules/README.md) — full YAML schema, per-rule details, loader wiring, customization.

### Block Rules (P0 — Critical) — *require a loader; see the warning above*

| Rule | File | What It Catches |
|------|------|----------------|
| Branch Protection | `hookify.block-direct-main.local.md` | Direct commits/pushes to `main` |
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

## Threat-Level Guardrails (Optional Companion)

This toolkit's enforcement is **workflow-shaped** — it keeps you on `main`, inside
worktrees, linted, and reviewed. It does **not** stop Claude from running a
*destructive command* (e.g. `cd /tmp && rm -rf x`). That's a different threat
model, and it's exactly what [**claude-code-guardrails**](https://github.com/uaziz1/claude-code-guardrails)
(MIT, © 2026 Umair Aziz) covers. The two layer cleanly:

| Layer | This toolkit | claude-code-guardrails |
|---|---|---|
| Focus | Workflow (branches, worktrees, lint, PR gating) | Threats (dangerous commands, secret exfil, credential writes) |
| Catches | Wrong-branch commits, cross-worktree edits, unlinted pushes | `rm -rf`/destructive git in **chains/wrappers/subshells**, `bash -c`/`curl\|sh`, reads of `~/.ssh` `~/.aws` `.env`, credential content in edits |
| Mechanism | Bash hooks + (inert) hookify rules | Python hooks: `bash-guard.py`, `edit-write-guard.py`, `audit.py`, `session-start.py` |
| Audit log | none | PostToolUse JSONL in `~/.claude/session-logs/` |

### Why hooks, not its permissions block

`claude-session.sh` launches Claude with `--dangerously-skip-permissions`, which
**bypasses the `permissions` allow/deny/ask system entirely**. Guardrails' *hooks*
still fire (hooks are independent of permission mode) — so under this toolkit's
default workflow the value comes from the four hooks, **not** from guardrails'
`permissions` block. Do **not** copy guardrails' `permissions` block or its
`disableBypassPermissionsMode: "disable"` into your settings: the former is inert
under skip-permissions, and the latter **breaks `claude-session.sh`**. (If you run
*without* skip-permissions, the permission lists do apply — your call.)

### Install (alongside, not vendored)

```bash
# 1. Install guardrails' Python hooks into ~/.claude/hooks/
git clone https://github.com/uaziz1/claude-code-guardrails.git
cd claude-code-guardrails && ./install.sh && ./tests/run.sh   # 126 self-tests

# 2. Merge the hook entries from this repo's overlay into your project's
#    .claude/settings.json (append to the matching PreToolUse/PostToolUse arrays):
#      config/settings.guardrails.json
```

The overlay ([`config/settings.guardrails.json`](config/settings.guardrails.json))
contains **only** the four hook registrations, ready to merge — multiple hooks per
matcher run in sequence, so they coexist with this toolkit's own hooks. Requires
`python3` (already assumed by `gitleaks-scan.sh` / crash recovery).

> This fits the toolkit's [soft-vs-hard enforcement model](docs/primitives.md):
> guardrails is a **hard** security layer that complements the **hard** workflow
> layer here. It's referenced as an external companion, not bundled — so it stays
> on its own release cadence.

---

## Agent Commands Reference

> Agent commands (a.k.a. skills) are reusable prompt templates. The full conceptual breakdown — skills vs subagents vs MCPs vs workflows — is in [`docs/primitives.md`](docs/primitives.md).

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

## Multi-Vendor Review Loop (Claude + Codex)

A binding-review layer that adds OpenAI **Codex** as an independent **cross-vendor** reviewer of your Claude Code work. Claude runs your existing workflow end-to-end (plan, implement, your review skills); Codex performs **one final binding review** on the complete PR before merge.

> **Why this matters:** Same-vendor review has blind spots. When Claude's review skills (`bug-finder`, `code-reviewer`, `security-auditor` — same model, same training, same priors) approve a PR, they tend to miss the same classes of bug. A different vendor with different priors catches those gaps. A single Codex review (~65s, $0 on Pro plan) is enough to surface real bugs that same-vendor reviews missed.

### How the loop works

```
Claude implements + runs its own review skills
              ↓
       "PR ready" signal
              ↓
Codex independent binding review (single gate)
              ↓
   APPROVE → merge   |   REDO → back to Claude with feedback
```

### Components shipped here

| Path | Purpose |
|------|---------|
| `orchestration/hooks/*` | 4 Claude Code hooks: budget cap, tier cap, ledger debit, sb-commit recorder |
| `orchestration/lib/state-helper.sh` | flock-guarded atomic state.json writer |
| `orchestration/lib/codex-pricing.json` | gpt-5.5 token rates (verify before binding mode) |
| `orchestration/scripts/codex-review-prompt.sh` | THE gate — emits `SKIP` / `REDO` / `PROMPT` verdict |
| `orchestration/scripts/dynamic-round-cap.sh` | Recommends review-round cap from diff size |
| `orchestration/verify/*` | 7 test scripts (race tests, regression tests, end-to-end acceptance) |

### Kill switch

Everything is governed by `CDT_USE_CODEX_REVIEW` (per-developer env var, no repo change needed to flip):

| Value | Behavior |
|---|---|
| `off` | Pre-flight emits `SKIP` immediately; existing flow untouched. |
| `shadow` (default) | Pre-flight runs and Codex is called, but verdict is logged + **non-binding**. |
| `binding-main` | Codex's `REDO` blocks merge for `main`-targeting PRs. |
| `binding-all` | Codex's `REDO` blocks merge for all PRs. |

**Recommended rollout:** `shadow` for 5–10 PRs to calibrate noise → `binding-main` → `binding-all`.

### Quick start

```bash
# 1. Install Codex CLI (Pro plan covers usage; OPENAI_API_KEY fallback)
npm i -g @openai/codex
codex login --device-auth                 # WSL-friendly device-flow auth

# 2. Copy orchestration/ into your project (skip if bootstrap.sh already did)
cp -r orchestration /path/to/your-project/
echo '.orchestration/' >> /path/to/your-project/.gitignore

# 3. Verify the install — 7 scripts, all should PASS in <2 seconds total
cd /path/to/your-project
for t in orchestration/scripts/hello-world.sh          orchestration/verify/test-*.sh; do
  bash "$t" >/dev/null 2>&1 && echo "PASS  $t" || echo "FAIL  $t"
done

# 4. Wire the hooks into .claude/settings.json (see docs for the JSON skeleton)
# 5. Set policy env vars in your shell rc (CDT_REQUIRED_REVIEWERS, etc.)
# 6. Restart your Claude Code session so the new hooks load
```

### Full docs

See [`docs/multi-agent-orchestration.md`](docs/multi-agent-orchestration.md) for:
- Full architecture + design rationale
- Complete env-var reference
- Hook wiring (JSON skeleton)
- Usage walkthrough (`SKIP` / `REDO` / `PROMPT` dispatch)
- Troubleshooting + FAQ
- Cost model

---

## Linting (oxlint)

[oxlint](https://oxc-project.github.io/docs/guide/usage/linter.html) is a blazing-fast JavaScript/TypeScript linter (~1 second for 700+ files). It replaces ESLint for speed-critical workflows.

### Usage

```bash
# Lint only files changed vs base branch (default: main)
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
| `LINT_BASE_BRANCH` | `main` | Branch to diff against for changed files |
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
gh pr create --base main
```

### Compatibility

Works with any CI/CD platform that reports via the GitHub Deployments API:
- **GitHub Actions** (with `actions/deploy-pages` or custom deployment steps)
- **PaaS providers** with native GitHub integration (automatic)
- **Container/serverless platforms** that publish deployment statuses (if configured to report deployments)

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

You have two options here, depending on how many sessions you want sticky in the terminal dropdown:

**Option A — Single one-click profile** (simplest, good for one project):

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

**Option B — 15-profile multi-session layout** (recommended if you run multiple worktrees in parallel):

Follow the full runbook at [`docs/wsl-tmux-terminal-setup.md`](docs/wsl-tmux-terminal-setup.md). It replaces `settings.json` with a config that exposes 15 named, tmux-backed tabs (`Session - Main`, `Session 2` … `Session 15`) via a single `~/scripts/wsl-session.sh` launcher. Each tab is an independent tmux session that survives tab-close — perfect for parking a worktree, dev server, or MCP process per tab. See [WSL + tmux + Windows Terminal Multi-Session Runbook](#wsl--tmux--windows-terminal-multi-session-runbook) above for how this layer interacts with `claude-session.sh`.

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

> **Stronger isolation (optional):** run each worktree inside its own Docker
> container with Claude Code *inside* the container, so a session can't touch the
> host, the main repo, or sibling worktrees. See
> [`docs/docker-worktree-architecture.md`](docs/docker-worktree-architecture.md)
> and the [`docker/`](docker/) wrapper scripts.

### Full Lifecycle

```bash
# 1. Create GitHub issue
gh issue create --title "Add dark mode" --body "..." --label "enhancement"
# Returns: GH-123

# 2. Create worktree (isolated workspace)
git pull origin main
git worktree add ../your-project-worktrees/GH-123-dark-mode -b feature/GH-123-dark-mode main

# 3. (Optional) Create bead for persistent tracking
bd create "Add dark mode (GH-123)" -p 2

# 4. Work in worktree
cd ../your-project-worktrees/GH-123-dark-mode

# 5. CONFIDENCE GATE — ask questions until 8/10 confident (see below)

# 6. Implement, commit frequently
git add -A && git commit -m "feat: add dark mode toggle (GH-123)"

# 7. Rebase from main BEFORE pushing
git fetch origin && git rebase origin/main

# 8. Lint + typecheck
scripts/lint-changed.sh

# 9. Push and verify deployment
git push -u origin feature/GH-123-dark-mode
scripts/check-deploy.sh

# 10. Create PR (after deployment succeeds)
gh pr create --base main --title "feat: add dark mode" --body "Closes #123"

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

The toolkit assumes a single long-lived branch named `main`. If yours is named
differently (e.g. `master` or `trunk`):

```bash
# For linting
export LINT_BASE_BRANCH=master

# Or add to your .bashrc / .zshrc
echo 'export LINT_BASE_BRANCH=master' >> ~/.bashrc
```

A few hooks hardcode `main` as the protected branch — search and replace if your
base branch has a different name:
```bash
cd .claude/hooks/
grep -l "main" *.sh
# Edit each file to use your base branch name
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
git rebase origin/main
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
