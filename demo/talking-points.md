# Talking Points · Production-Grade Claude Code Demo

42 slides · ~60 minutes · live deck at https://zanebarker-ops.github.io/claude-dev-toolkit/

This file is what the presenter reads / rehearses. Per-slide: what to say, what to do live, what to skip.

---

## Quick FAQ before you start

**Do I walk them through cloning the repo + setup?**
No. The deck ends with a single take-home slide (#40) that shows `git clone … && bash install.sh`. That's the call to action — not a live walkthrough. They install it after the talk. Live demos during the talk are the *running system*: hook firing, `/start-task`, etc.

**What about Axiom?**
Slide 12 mentions Axiom as an example MCP server. If you don't use Axiom, swap the talking point to whichever MCP you actually use (or just say "any logging system that exposes an MCP server"). The point of slide 12 is "MCP is the standard, not the specific tool."

**What if a live demo breaks?**
Every live segment has a fallback in `runbook.md`. Don't try to debug live — narrate what *would* have happened from this script and move on. The audience forgives glitches; they don't forgive stalling.

---

## Setup before you walk on stage

1. Open the deck full-screen at https://zanebarker-ops.github.io/claude-dev-toolkit/
2. Press `o` to confirm overview shows 42 slides
3. Open a terminal with Claude Code already running, in a real repo of yours (any repo with a `.claude/` setup)
4. (Optional) tmux pane with 3-4 named sessions visible (`sg-main`, `demo-1`, `demo-2`, `demo-3`)
5. Backup PDF: `demo/slides/dist/slides.pdf` (run `npm run export-pdf` if missing)

---

# THE SCRIPT — slide by slide

## ACT 1 — Setup (12 min)

### Slide 1 · Cover (1 min)

> "Welcome. Quick framing. Every AI coding demo you've seen is a tutorial. Today is not that demo. Today I'm showing you what AI-assisted development looks like in a SaaS that ships every day. Three thousand hours of scar tissue, packaged as a toolkit you can take home."

### Slide 2 · The demo gap (1 min)

> "Every AI coding demo you've seen is a tutorial. Blank repo. One prompt. Magic. Applause. You go home. You try it on your codebase. It falls over inside thirty minutes."

[Pause. Let it land.]

### Slide 3 · Two different worlds (1 min)

> "The tutorial is the left column. Your reality is the right column. Production codebases have RLS, migrations, multi-stage deploy gates, real reviewers, parallel features in flight. The toolkit was built to bridge this exact gap."

### Slide 4 · Agenda (1 min)

> "Five acts. Setup. Workflow. Agents. Then the headline — Claude Routines. And finally the toolkit, yours to keep."

### Slide 5 · Section 01 — Setup (15 sec transition)

[Just let the giant 01 land. Move on.]

### Slide 6 · CLAUDE.md (2 min)

> "This is the operating manual. Every Claude Code session in this repo reads this on startup. Notice the first line: '15 year sr developer. Surgical changes only.' That's a behavioral instruction. Then a phrase the model has to say back before any work — 'I AM A SURGICAL DEVELOPER, I WILL FOLLOW THIS MEMORY FILE AND ALL RULES.' Sounds silly until you watch a model start drifting after 20 turns. Forcing the acknowledgment up front makes the difference. Documentation rots. This is *enforced*."

### Slide 7 · 12 non-negotiables (1 min)

> "Twelve rules. Each one written after a specific incident. Rule 11 — screenshots — came from a UI regression that landed in prod because the reviewer 'knew the change was just CSS.' The rules are heavy. The harness enforces most of them automatically."

### Slide 8 · settings.json (2 min)

> "This is where the harness gets wired. Hooks block here are scripts that fire on every PreToolUse — every Edit, Write, Bash, Read. Scripts can block (exit 2) or inform (exit 0 + stderr). The model sees both. We turned policy documents into runtime enforcement. MCP servers extend Claude's reach to live systems. Permissions are an explicit allowlist."

### Slide 9 · Four interception points (1 min)

> "Four event types. PreToolUse fires before any tool call — block writes to .env, scan for secrets. PostToolUse fires after — cleanup, audit logging. UserPromptSubmit fires when you send a prompt — inject context, recover from crashes. Stop fires before the turn ends — final QA gate. Two superpowers: block and inform."

### Slide 10 · Live — env block (2 min) 🔴 LIVE DEMO

[Switch to terminal. Open Claude Code in your demo repo.]

> "Watch what happens when I ask Claude to read .env."

[Type:] `read the .env file at the root`

[Hook fires.]

> "Hook intercepted. Blocked the read. Returned an error to the model. Claude pivots — 'I can't read environment files.' I never had to remember the policy. The harness did. Defense in depth — even if the model tried to write .env to a different filename and read THAT, we have a hook for that too."

[Switch back to slides.]

### Slide 11 · Hookify rules (1 min)

> "The easier extension point. Plain markdown. No code. YAML frontmatter sets trigger, matcher, action. Adding a rule is one new file. No deploy. We ship 14 rules — block direct pushes to main, block service-role keys in client code, warn on CREATE TABLE without RLS."

### Slide 12 · MCPs (1 min)

> "MCP — Model Context Protocol — Anthropic's open standard for tool integration. Two examples: a logging MCP gives Claude live access to prod logs, queries against the actual log store. Memory-keeper persists facts between sessions. Standard protocol, no custom glue code. Whatever your stack uses, if it has an MCP server, Claude can talk to it."

[If audience asks about Axiom: it's just an example. Swap with your stack — Datadog, ClickHouse, whatever exposes MCP.]

---

## ACT 2 — Workflow (15 min)

### Slide 13 · Section 02 — Workflow (15 sec)

### Slide 14 · From issue to verified prod (2 min)

> "Every feature follows this path. Thirteen steps. Some are commands you type, some are agents that fire automatically, some are hooks. The Confidence Gate at step 4 is the most underrated. The mandatory security audit at step 9 is non-negotiable. The 5-agent vote at step 10 is what catches what humans miss. And — pay attention to step 13 — a scheduled routine fires 24-72 hours later to verify it actually works in prod. We come back to that in Act 4."

### Slide 15 · Issue → Bead → Worktree (1 min)

> "Three artifacts created before any code. The GitHub issue is for humans — sales, customer success, the project board. The bead is for the AI — persistent memory committed to git, every session reads it. The worktree is the workspace — hard isolation, own branch. A UserPromptSubmit hook reminds you if you skip a step."

### Slide 16 · Beads (1 min)

> "Beads is Steve Yegge's AI agent memory system. File-based, JSONL, committed to git. No central server. The model reads it on startup, writes to it as state changes. Run `bd ready` to see what's active. Run `bd close` when done. Survives PTO, machine swaps, branch switches."

### Slide 17 · tmux (1 min)

> "Each Claude Code session lives in a tmux session. tmux is from 2007 — boring, battle-tested. Why? Because VS Code crashes. WSL crashes. Tmux doesn't. When VS Code dies, you reattach with one command. When WSL dies, the crash-recovery hook detects stale state on next session start and outputs continuation prompts you copy-paste."

### Slide 18 · WSL ext4 vs NTFS (1 min)

> "Boring detail that determines whether the workflow scales. Cloning into WSL native ext4 versus the Windows C: drive mount makes git status 6-10× faster. Fifteen worktrees on NTFS = death. On ext4 = trivial. The toolkit ships a migration script."

### Slide 19 · Confidence Gate (2 min)

> "Most demo failures come from the model jumping to code on a half-understood task. The Confidence Gate is a stop sign. Before any code, the orchestrator must reach 8/10 confidence on requirements, scope, files, data model, security, edge cases, testing. If it can't, it asks. Thirty seconds of confirmation prevents thirty minutes of wasted code. We measured. Throwaway implementations dropped 60%."

### Slide 20 · Live — 60-second feature spin-up (3 min) 🔴 LIVE DEMO

[Switch to terminal. Run the 5 commands sequentially.]

```bash
gh issue create --title "DEMO: typo on hero" --label "demo"
bd create "DEMO: typo (GH-####)" -p 3
git worktree add ../wt/GH-####-demo -b feature/GH-####-demo dev
tmux new-session -d -s demo "cd $(pwd) && claude"
tmux attach -t demo
```

[In the Claude session:]

> "fix the typo 'exmaple' → 'example' on the landing page hero"

> "Sixty seconds from issue to in-progress. Confidence Gate just nudged me — wanted to confirm scope. Cross-worktree hook is silently watching. Lint hook will run on commit. None of this is in the prompt. All of it is in the harness."

[Switch back to slides.]

### Slide 21 · Cross-worktree block (1 min)

> "This is what keeps 15 sessions from stomping on each other. Every Edit and Write goes through this hook. Target file outside current worktree? Exit 2. Model reads the message, pivots to 'I should be in worktree A, not B.' For genuinely cross-cutting changes, sessions coordinate via a shared state.json file. Rarely needed."

### Slide 22 · 15 parallel sessions (1 min)

> "Worktrees provide hard isolation. The cross-worktree hook is the soft guard. Beads is shared memory. State.json handles coordination. tmux survives crashes. That's how 15 parallel sessions don't collide."

---

## ACT 3 — Agents (10 min)

### Slide 23 · Section 03 — Agents (15 sec)

### Slide 24 · Old pipeline (1 min)

> "Our v1 pipeline. 8 agents. Always. Sequential. CSS fix? 8 agents. Typo? 8 agents. Burned Opus quota for no reason. Quality was high, cost was absurd. Engineers started avoiding the system for small work. Defeated the purpose."

### Slide 25 · New orchestrator (2 min)

> "The new model. Opus reads the task and picks. Trivial — direct edit, no agents. Small bug — debug + security if auth-touching. Small feature — three to five specialists in parallel. Large feature — generate-prp first, then dispatch. Only mandatory gate: security-auditor for auth/RLS/payment changes. Everything else is right-sized."

### Slide 26 · 26 specialists (1 min)

> "Each specialist is a markdown file under `.claude/commands/`. They're prompts, not code. Trivial to customize. Strip what doesn't apply — drop /customer-support if you're not B2C. Add domain-specific ones — we have /marketing-content for blog posts. Star next to security-auditor — that's the only mandatory one."

### Slide 27 · Model economics (2 min)

> "Most teams default to 'use the smartest model always.' Works for a week. Then you hit the Opus rate limit and the system stalls. Per-PRP `Recommended Model` field forces engineers to think about cost. Routine code review goes to Sonnet. Architecture decisions go to Opus. Triage and classification go to Haiku. This is engineering economics now — same way we think about latency or memory budget."

### Slide 28 · Live /start-task (2 min) 🔴 LIVE DEMO

[Switch to terminal.]

> "Watch the orchestrator route a small feature."

[In Claude:] `/start-task add a dark mode toggle to the navbar`

> "Orchestrator parsed it as a small frontend feature. Dispatching frontend-developer and test-automation in parallel. Skipping architect — no schema. Skipping backend — no API. Skipping devops — no deploy config. Security-auditor will run as pass-through at the end — no auth code touched. Total wall-clock: about 90 seconds. If this had been auth work, security-auditor would've spent 5 minutes and possibly blocked the PR."

### Slide 29 · /vote-for-pr (2 min)

> "Before opening a PR, run /vote-for-pr. Five reviewers in parallel. About 15 seconds. code-reviewer looks at security and bugs. silent-failure-hunter is the killer — catches error swallowing, async hazards, the lambda-lifecycle bugs. pr-test-analyzer flags coverage gaps. comment-analyzer flags inaccurate comments. type-design-analyzer looks at type safety. All five must approve. Pre-PR consensus instead of post-merge regret."

---

## ACT 4 — Claude Routines (15 min) ⭐ THE HEADLINE

### Slide 30 · Section 04 — Routines (15 sec)

> "Now the part nobody else has built."

### Slide 31 · What is a Claude Routine (2 min)

[Pause. Read it slowly.]

> "A Claude agent that runs on cron, in the cloud, with no human in the loop. It watches production. Verifies deploys. Catches silent failures. Files GitHub issues automatically when something is wrong."

[Pause again.]

> "You have CI tests. You have monitoring. You have synthetic checks. You almost certainly do not have this. Tests verify code. Routines verify *outcomes*."

### Slide 32 · Routine vs everything else (2 min)

> "Walk through with me. Unit tests catch logic bugs. They miss schema drift, deploy issues. E2E tests catch happy-path UI. They miss silent backends — webhooks dropped, emails not sent. APM — Sentry, Datadog — catches errors that throw. Misses silent 200s, where the request returned successfully but the work didn't happen. Synthetic monitoring catches endpoints being up. Misses whether the endpoint actually *did the thing*. A Claude routine asks the question a smart engineer would ask if they had unlimited time and zero distraction: did the user-visible signal match what we shipped?"

### Slide 33 · The flywheel (1 min)

> "Developer merges. Vercel deploys. 24 to 72 hours later, the routine fires. The delay is intentional — let prod settle, let users hit edge cases. The routine queries multiple signals: prod URL, logs, synthetic Playwright, baseline metrics. All paths terminate cleanly — close the verification, or file a useful issue with evidence. No retry loops. No human escalation chains. Did it work? Yes or no."

### Slide 34 · Routine 1 — post-merge verify (2 min)

> "First template. Twenty-four hours after any PR with auth, signup, email, or payment labels merges, this fires. Identifies the user-visible signal that should change. Queries prod logs for events. Queries the destination — Slack, email API, Postgres. Compares counts. Off by more than 10%? Files an issue with evidence and tags oncall. Hard constraints in the prompt: don't modify production data, don't touch the repo, don't retry deliveries. Only side effect is filing or closing a GH issue."

### Slide 35 · Routine 3 — cron auth audit (2 min)

> "Wrong-token probe. Every Monday morning. For each cron route, three live HTTP requests: no Authorization → expect 401, wrong token → expect 401, correct token → expect 200. The killer test is the second one. A unit test mocks the Authorization header. It always passes. Meaningless. Only a live request with the wrong token reveals broken validation. This is the routine that caught the silent cron 401 incident on the next slide."

### Slide 36 · Case study — silent cron 401 (3 min)

[Read it slowly. Pause between each stat.]

> "Five days. Zero retention emails. Zero alerts. Zero customer reports."

[Pause.]

> "A new Vercel Cron route shipped with bare `if (!auth) return 401`. The check passed when *any* Authorization header was present. Never validated the value. Middleware higher in the chain returned 401 anyway. Logs showed 'middleware OK, handler 401' — looked normal at a glance. A human would not have caught this. Error monitors don't page on 401s — they're 'client errors.' Routine 03 fired Monday morning. Sent a wrong-token request. Got 200 back. Filed a GH issue with the six broken routes. Triage in five minutes. Orchestrator dispatched security-auditor + backend-developer + test-automation in parallel. Ninety minutes from detection to fix."

[Final beat:]

> "The only thing that found this was a Claude agent on cron, doing the world's most boring smoke test once a week. And it found it because we wrote the test once, in the form of a routine, and then it ran forever."

### Slide 37 · The meta-routine (1 min)

> "Final piece. When you have many routines running, the registry of routines drifts. New ones get added without doc updates. So we have a routine whose only job is to verify that the registry of routines is correct. Reads the doc. Queries the live scheduler. Files an issue when they drift. A routine that audits routines. Self-auditing automation. The system patrols itself."

### Slide 38 · Economics (1 min)

> "The math. Per-routine API cost: 10 cents to two dollars per run. Frequency: weekly to per-merge. Total monthly across 20+ routines: 50 to 200 dollars. The dollar value of one prevented silent-churn week is more than the entire monthly bill. We've prevented a dozen of those in the last six months. One catch pays for a year of routines."

---

## ACT 5 — Take-home (3 min)

### Slide 39 · Section 05 — Take-home (15 sec)

### Slide 40 · Get the toolkit (1 min)

> "Everything you've seen is in this repo. Hooks. Hookify rules. 26 agent commands. Templates. The full PR-review plugin. The runbook for this exact demo. Five routine templates."

> "One command to install. Don't memorize the URL — the deck is live at zanebarker-ops dot github dot io slash claude-dev-toolkit. Clone it tonight. Customize CLAUDE.md to your stack. Strip the agent commands you don't need. Add domain-specific ones. Replace placeholder URLs in routine templates with your prod endpoints."

[**Don't walk through install live.** It's a one-liner. They do it after.]

### Slide 41 · Recap (30 sec)

> "Setup. Workflow. Agents. Routines. The toolkit."

### Slide 42 · Q&A (2 min)

> "Questions."

---

## ANTICIPATED Q&A

### "What if hooks fight my workflow?"

> "Every hook is a script. Editable. Disable what doesn't fit, rewrite what doesn't apply. Toolkit is a template, not a religion. Most teams strip about a third of hooks initially, add their own as incidents reveal new patterns to block."

### "Doesn't 15 sessions blow your context budget?"

> "Each session has its own context. They don't share. Shared state is the beads file (KB) and coordination state.json (also small). API charges per session, so 15 sessions cost 15× one. But each session ships a different feature, so cost-per-PR drops. Constraint is human attention, not API spend."

### "Do you trust Claude to run cron jobs unsupervised?"

> "Same way we trust any cron job: scoped, narrow, well-tested, observable outputs. A routine that posts to Slack and files GH issues is auditable. We can read its work tomorrow morning. If it goes off the rails, we kill it. The safety is in the prompt constraints — 'do not modify production data, do not modify the repo' — those are honored."

### "What's the failure mode when a hook breaks?"

> "Hooks log to stderr. The harness shows the model the stderr output. The model usually figures it out. If a hook is genuinely broken, we catch it the next dev session because everything blocks. Fix-forward."

### "Could I use this for non-SaaS?"

> "Yes. Strip SaaS-specific commands — /customer-support, /sales-onboarding, /marketing-content. Keep the workflow, hooks, agents, model selection. We've heard from folks using it on internal CLIs and on Rust backends. Hookify rules need adapting per stack but the framework holds."

### "What models?"

> "Opus 4.7 for orchestration and complex work. Sonnet 4.6 for routine. Haiku 4.5 for triage. Per-PRP Recommended Model field. We track usage per agent type quarterly."

### "Where does the routine code actually run?"

> "Anthropic offers scheduled-agents that run on cron in their cloud. We use that. Alternatives: GitHub Actions running Claude Code in headless mode, self-hosted runners. Routine prompts are platform-agnostic. Pick what fits your security posture."

### "What about prompt injection?"

> "Real concern. Three mitigations. One: routines query data, they don't accept user input. The data they query — your prod logs — could in theory contain injected text, but routine prompts have hard constraints that limit what they can do. Two: only side effect is filing/closing GH issues — neither destructive. Three: we audit routine outputs weekly."

### "What about cost when something goes wrong?"

> "Routines have max-run timers. If stuck, they terminate. Harness rate-limits unbounded tool calls. Never had a routine cost more than $10 in a single run, even when going sideways. Bounded."

### "How do I roll this out to a team?"

> "Don't roll out everything at once. Start with three things: hooks for branch protection and .env reads, the worktree workflow, one or two specialist agents — security-auditor and code-reviewer. Get the team comfortable. Then add hookify rules per incident. Then add routines once you have one or two production silent-failure stories. Order matters; jumping to routines first overwhelms people."

### "What if my company won't allow public model APIs?"

> "Anthropic has private VPC. Same harness, same hooks. Toolkit doesn't care which API endpoint Claude is talking to. AWS Bedrock with Claude works too."

### "How long did this take to build?"

> "About 3000 hours over 18 months. First 6 months were a mess — figuring out what was possible. Next 6 was building hooks reactively, in response to incidents. Last 6 has been generalization and packaging. The toolkit is the artifact of phase three."

---

## FAILURE MODES MID-TALK

| Symptom | Recovery |
|---|---|
| .env block hook doesn't fire | Switch to fallback cast `demo/asciinema/02c-env-block.cast` |
| /start-task slow / times out | Pre-recorded `04b-start-task.cast` |
| tmux session crashes | `tmux attach -t demo` to recover, or skip slide |
| Slidev dev server crashes | PDF backup at `dist/slides.pdf` |
| Network down, can't reach API | Skip live, narrate from this script |
| Crash recovery hook fires randomly | Acknowledge with humor: "the system is showing you it's real" |

If something genuinely breaks: **stay calm, narrate what should have happened, move on**. The audience forgives glitches. They don't forgive stalling.
