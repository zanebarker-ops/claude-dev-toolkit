# Live Demo Runbook

**Audience:** experienced technical group, mixed Claude Code familiarity
**Length:** 60 minutes (5 acts + Q&A)
**Setup:** WSL2 + tmux + Claude Code v2.x or later, all running on `~/repos/` (ext4)

This runbook tells you exactly what to type, what to show, and what to say if something breaks live. Pre-recorded asciinema fallbacks are in `demo/asciinema/`.

---

## Pre-flight (do this 30 minutes before the talk)

```bash
# 1. Confirm tmux server running
tmux ls
# Expected: at least one session (sg-main or similar)

# 2. Pre-warm 3-4 tmux sessions for the parallel demo
for n in 1 2 3 4; do
  tmux new-session -d -s "demo-$n"
done
tmux ls

# 3. Verify Claude Code is up to date
claude --version

# 4. Open the slides locally
cd ~/repos/claude-dev-toolkit/demo/slides
npm run dev
# slides at http://localhost:3030

# 5. Open a second terminal pointing at the demo (or a clone) repo
cd ~/repos/<repo>

# 6. Verify .claude/ tooling visible
ls .claude/hooks/ | head
ls .claude/commands/ | head

# 7. Open the toolkit README in a browser tab as the take-home
# https://github.com/zanebarker-ops/claude-dev-toolkit
```

If any pre-flight step fails: **swap to the asciinema fallback for that act**. Don't try to debug live.

---

## Act 1 — The problem (5 min)

**Slide:** "AI coding demos vs. AI coding in production"

**What to say:**
> "Every AI coding demo you've seen is a tutorial. A blank repo. A prompt. A single feature. Magic happens. You clap. You go home. You try it on your real codebase and it falls over inside 30 minutes — because real codebases have RLS policies, and migrations, and three other developers, and a CI pipeline, and a deploy gate, and feature flags, and prod data you can't drop. Today is not that demo. Today I'm going to show you what AI-assisted development looks like in a production SaaS that ships every day."

**What to show:** Just the slide. No live action yet. Build tension.

**Time check:** 5 min in.

---

## Act 2 — The setup (12 min)

**Slides:** "CLAUDE.md", "settings.json", "hooks", "MCPs"

### 2a. CLAUDE.md (3 min)

**Type:**
```bash
cat ~/repos/<repo>/.claude/CLAUDE.md | head -80
```

**What to say:**
> "This is the operating manual. Every Claude Code session in this repo reads this on startup. It's not documentation — documentation rots. This is *enforced* — you'll see in a minute. Twelve non-negotiable rules. Rule #1: rebase from dev. Rule #2: zero lint errors. Rule #5: documentation must be updated. We didn't get here by being smart. We got here by being burned."

### 2b. settings.json (4 min)

**Type:**
```bash
cat ~/repos/<repo>/.claude/settings.json | jq '.hooks | keys'
```

Expected output: `["PreToolUse", "PostToolUse", "UserPromptSubmit", "Stop"]`

**Then:**
```bash
cat ~/repos/<repo>/.claude/settings.json | jq '.hooks.PreToolUse'
```

**What to say:**
> "These are the four event types where the harness lets us inject scripts. PreToolUse fires *before* every tool call — Edit, Write, Bash, Read. We can block the call by exiting non-zero. We can inject context by writing to stderr. The model sees both. So if I tell Claude to edit `.env`, and the hook says no — Claude doesn't argue. It pivots. We turned policy documents into runtime enforcement."

### 2c. Live hook demo (3 min) — the killer moment

**In Claude Code session, type:**
```
read the .env file at the root
```

**What happens:** the `block-env-read.sh` hook intercepts the Read tool call and returns:
```
BLOCKED: .env file read attempt
========================================
.env files contain credentials and must never be read by Claude.
```

**What to say (while pointing at the screen):**
> "Watch what just happened. I asked Claude to do something that violates our policy. The hook ran, blocked the read, returned an error to the model. The model immediately apologized, said it can't read .env files, and asked what I actually wanted. I never had to remember the policy. The harness did."

**Fallback:** if the hook isn't firing for some reason, switch to `demo/asciinema/02c-env-block.cast`.

### 2d. MCPs (2 min)

**Type:**
```bash
cat ~/repos/<repo>/.claude/settings.json | jq '.mcpServers | keys'
```

**What to say:**
> "Two MCP servers — Axiom for production logs, memory-keeper for cross-session context. The model can query our prod logs in real time. Not from a copy-pasted log dump. From the live source. That changes how RCAs feel."

**Time check:** 17 min in.

---

## Act 3 — The workflow (15 min)

**Slides:** "Issue → bead → worktree", "Confidence Gate", "Live: 60s feature spin-up"

### 3a. The flow on the slide (3 min)

Show diagram 1 (`demo/diagrams/01-feature-lifecycle.md`).

**What to say:**
> "Every feature follows this path. There are no shortcuts. The harness enforces every step. Let me show you."

### 3b. Live: spin up a feature in 60 seconds (8 min)

**In the second terminal (pointed at the demo repo):**

```bash
# Step 1: create a GH issue
gh issue create --title "DEMO: trivial typo fix in landing page" --body "Landing page has 'exmaple' instead of 'example' on hero. Quick fix." --label "demo" 2>&1

# (Note the issue number, e.g., GH-9999)

# Step 2: create a bead
bd create "DEMO: typo fix (GH-9999)" -p 3
# (Note the bead ID, e.g., bd-demo-001)

# Step 3: create the worktree
git worktree add ../<repo>-worktrees/GH-9999-demo-typo -b feature/GH-9999-demo-typo dev
cd ../<repo>-worktrees/GH-9999-demo-typo

# Step 4: launch a Claude Code session in tmux
tmux new-session -d -s demo-typo "cd $(pwd) && claude"
tmux attach -t demo-typo
```

**In the Claude session, prompt:**
```
fix the typo "exmaple" → "example" on the landing page hero. small surgical change.
```

**What happens:**
- The Confidence Gate hook reminds Claude to confirm scope
- Claude reads the landing page, makes the fix
- Lint hook runs on commit
- Done

**What to say:**
> "Sixty seconds from issue to in-progress. Three commands and a prompt. Notice the Confidence Gate just nudged me — it wanted to confirm scope before editing. The cross-worktree hook is silently watching. The lint hook will run when I commit. None of this is in the prompt. All of it is in the harness."

### 3c. The Confidence Gate (4 min)

Show slide. Say:

> "Most demo failures come from the model jumping straight to code on a half-understood task. The Confidence Gate forces the model to ask questions until it's at 8 out of 10 confidence. Requirements? Scope? Affected files? Data model? Security? Edge cases? Testing? It's a 30-second cost that prevents 30-minute wasted implementations. We measured. Throwaway code dropped 60%."

**Time check:** 32 min in.

---

## Act 4 — The agents (10 min)

**Slides:** "Orchestrator + 26 specialists", "Model economics"

### 4a. The orchestrator (4 min)

Show diagram 4 (`demo/diagrams/04-agent-orchestration.md`).

**What to say:**
> "We used to run an 8-agent pipeline on every task. Architect, backend, frontend, test, security, review, docs, devops. Sequential. Mandatory. CSS fix? 8 agents. Typo? 8 agents. We were burning Opus quota for no reason. Now: the orchestrator reads the task and picks. Small bug? 1 agent. Big feature? Orchestrator runs `/generate-prp` first, then dispatches specialists in parallel. The only mandatory gate is `/security-auditor` for anything touching auth, RLS, payments, or user data."

### 4b. Live: `/start-task` (4 min)

**In Claude session:**
```
/start-task add a dark mode toggle to the navbar
```

**What happens:** orchestrator decides this is a small feature → invokes `/frontend-developer` and `/test-automation` in parallel, skips architect/backend/devops, runs `/security-auditor` at the end (no auth changes, fast pass), opens PR.

**What to say while it runs:**
> "Two agents in parallel. Skipped six. Security auditor will pass-through because no auth code is touched. Total time: about 90 seconds. If this had been auth work, security-auditor would have spent five minutes and possibly blocked the PR with a list of fixes."

### 4c. Model economics (2 min)

Show slide with the table from `demo/diagrams/04-agent-orchestration.md`.

**What to say:**
> "Opus 4.7 is rate-limited to 200 requests per week. Sonnet to 100. If you're not deliberate, you'll burn through Opus on autocomplete. We set per-PRP `Recommended Model` fields. Routine code review? Sonnet. Architecture decisions? Opus. We track spend per agent type. This is engineering economics now."

**Time check:** 42 min in.

---

## Act 5 — The force multiplier: routines (15 min)

**Slides:** "15 parallel sessions", "Claude Routines", "Case study: silent cron 401"

### 5a. 15 parallel sessions (4 min)

**In a fresh tmux:**
```bash
tmux ls
```

Show 4-5 active sessions. Tab through them with `Ctrl+b s`.

**What to say:**
> "Every one of these is a Claude Code session, on its own worktree, on its own branch, on its own GitHub issue. They don't step on each other because of three things: worktrees, the cross-worktree hook, and a coordination state file that locks shared files. I had 15 of these running last Tuesday. I shipped 11 PRs that day, single-handed."

### 5b. Claude Routines — the headline (8 min)

Show diagram 5 (`demo/diagrams/05-scheduled-flywheel.md`).

**What to say:**
> "Now we get to the part nobody else is doing. These are not interactive sessions. These are Claude agents that run on cron, in the cloud, with no human in the loop. They watch production. They verify deploys. They catch silent failures. They file issues automatically when something is wrong."

**Walk through 3 live examples:**

```bash
cat demo/routines/01-post-merge-verify.md      # 24-hour post-deploy verification
cat demo/routines/02-schema-doc-reconcile.md  # column rename detection
cat demo/routines/03-cron-auth-audit.md       # the GH-XXXX silent-churn catcher
```

**Then case study 1:** read the narrator beat from `demo/case-studies/01-silent-cron-401.md`.

> "Five days. Zero retention emails. Zero alerts. Zero customer reports. The only thing that found this was a Claude agent on cron, doing the world's most boring smoke test once a week. It found it because we were forced to write the test once, in the form of a routine, and then it ran forever."

### 5c. The meta-routine (3 min)

> "Final piece. We have a routine whose entire job is to verify that the registry of routines is accurate. A routine that audits routines. Self-auditing automation. When we drift — add a new routine, forget to update the registry — it files an issue. When we have a routine that's no longer running but is still documented, it files an issue. The system patrols itself."

**Time check:** 57 min in.

---

## Take-home (3 min)

**Slide:** the toolkit repo URL

```bash
git clone https://github.com/zanebarker-ops/claude-dev-toolkit.git
cd claude-dev-toolkit
bash install.sh
```

**What to say:**
> "Everything you've seen is in this repo. Hooks. Hookify rules. Twenty-six agent commands. Templates. The full PR-review plugin. The runbook for this exact demo. The case studies. The routines. Three thousand hours of production scar tissue, packaged. Take it. Customize it. Ship better."

**Q&A.**

---

## Anticipated questions & talking points

### "What if the hooks fight my workflow?"

> "Every hook is a script. Every script is editable. Disable the ones you don't need; rewrite the ones that don't fit. The toolkit is a template, not a religion."

### "Doesn't 15 parallel sessions blow your context budget?"

> "Each session has its own context. They don't share. The shared state is `.beads/issues.jsonl` (a few KB) and `.claude/coordination/state.json` (also small). Claude API charges per-session, so yes — 15 sessions costs 15× one session. But each session is on a different feature, so you're shipping 15× the work. Cost-per-PR drops, not rises."

### "Do you trust Claude to run cron jobs unsupervised?"

> "We trust it the same way we trust any cron job: scoped, narrow, well-tested, with auditable outputs. A routine that posts to a Slack channel and files GH issues is observable. We can read its work tomorrow morning. If a routine starts going off the rails, we kill it the same way we'd kill a misbehaving Lambda."

### "What's the failure mode when a hook breaks?"

> "Hooks log to stderr. The harness shows the model the stderr output. The model usually figures it out. If a hook is genuinely broken — exit codes wrong, infinite loop — we catch it during the next dev session because everything blocks. Fix-forward."

### "What's the ROI?"

> "We measure two things. Wall-clock to PR (down 40%). Silent failures caught in prod (the GH-XXXX class — count went from one a quarter to zero in the last 90 days). The dollar value of one prevented silent-churn week is more than the entire monthly Claude bill."

### "Could I use this for non-SaaS?"

> "Yes. Strip the SaaS-specific commands (`/customer-support`, `/sales-onboarding`). Keep the workflow, hooks, agents, model selection. The bones are general."

### "What models are you using?"

> "Opus 4.7 for orchestration and complex work, Sonnet 4.6 for routine, Haiku 4.5 for triage. The model-selection rules are in `templates/model-selection.md` in the toolkit."

### "What if my company doesn't allow public model APIs?"

> "Claude has a private VPC offering. Same harness, same hooks. The toolkit doesn't care which API endpoint Claude Code is talking to."

---

## Failure modes and live recovery

| Symptom | Recovery |
|---|---|
| Hook doesn't fire on `.env` read | Switch to asciinema cast `02c-env-block.cast` |
| `/start-task` is slow / times out | Pre-recorded cast `04b-start-task.cast` |
| tmux session crashes mid-demo | Reattach via `tmux attach -t demo-typo` or jump to next act |
| Slidev dev server crashes | Backup PDF at `demo/slides/dist/slides.pdf` (built ahead of time) |
| Network down — can't reach API | All material is local; skip live `/start-task`, narrate from runbook |
| Crash recovery hook fires unexpectedly | Acknowledge with humor: "this is the WSL crash recovery hook, see the demo is real" |

---

## Pre-recorded fallbacks (build before the talk)

```bash
# Record the env-block moment
asciinema rec -t "Hook blocks .env read" demo/asciinema/02c-env-block.cast

# Record /start-task on dark-mode toggle
asciinema rec -t "/start-task dark mode" demo/asciinema/04b-start-task.cast

# Record /vote-for-pr running
asciinema rec -t "/vote-for-pr 5 reviewers" demo/asciinema/05a-vote-for-pr.cast
```

Embed these in the slides if Slidev supports it (it does — `<asciinema-player>` component) so you can play inline if live fails.
