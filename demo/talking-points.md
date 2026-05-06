# Talking Points

Companion to `demo/slides/slides.md`. Speaker notes are inline in the slides themselves; this file is the **expanded narrator script**, the **anticipated Q&A**, and the **transitions** between acts.

If you read this top-to-bottom, you have the full talk.

---

## How to use this document

- Read it once before the talk to internalize the arc
- Skim each section before its act
- Use the Q&A appendix during cold question time
- Don't memorize the prose — rehearse the *beats* and improvise

---

## Act 1 — The setup

**Time: 12 min. Slides 1–10.**

### Opening (slides 1–4)

> "Welcome. Quick framing before we dive in.
>
> Every AI coding demo you've seen is a tutorial. A blank repo, a prompt, magic happens, applause. You go home, try it on your real codebase, and it falls over inside thirty minutes.
>
> Today is not that demo.
>
> Today I'm showing you what AI-assisted development looks like when it's running a SaaS that ships every day. We have RLS policies. We have migrations that can break prod silently. We have fifteen features in flight at once. We have a deploy gate, a dev environment, and a small team that has to coordinate without stepping on each other's work.
>
> Three thousand hours of production scar tissue, packaged as a toolkit you can take home today."

### CLAUDE.md (slide 5)

> "Every Claude Code session in this repo reads this on startup. It's not documentation — documentation rots. This is *enforced*. You'll see how in a minute.
>
> The first three lines say: 'You are a 15 year senior developer. You only make surgical changes. You will not rewrite entire features.' Notice that's a behavioral instruction, not a technical one. Then there's a phrase the model has to say back before any work: 'I AM A SURGICAL DEVELOPER. I WILL FOLLOW THIS MEMORY FILE AND ALL RULES.' That sounds silly until you watch a model start breaking your style after twenty turns. Forcing the acknowledgment up front makes the difference."

### 12 non-negotiable rules (slide 6)

> "Twelve rules. Every one of them was written after a specific incident. Rule eleven — before-and-after screenshots — came from a UI regression that landed in prod because the reviewer 'knew the change was just CSS'. Rule twelve — RCA for major fixes — came from realizing we kept having the same incident pattern twice.
>
> The rules are heavy. The harness enforces most of them automatically. Engineers don't have to remember rule eleven; the workflow blocks PR creation if the screenshot folder is empty."

### settings.json (slides 7–8)

> "This is where the harness gets wired. Four event types: PreToolUse, PostToolUse, UserPromptSubmit, Stop. Each one can run scripts. Each script can do two things: block the call, or inform the model.
>
> Block means exit two with a message. The harness shows the message to the model as a tool error. Claude reads it and pivots. It doesn't argue.
>
> Inform means exit zero with a message on stderr. The tool call goes through, but the model gets context. We use this for soft warnings — 'you just edited a migration, remember to update the schema doc' — that kind of thing."

### Live: .env block (slide 9)

[**Switch to terminal. Open a Claude Code session in the demo repo.**]

> "Watch this. I'll ask Claude to read the .env file."

[**Type:**] `read the .env file at the root`

[**Hook fires. Output blocks the read.**]

> "There. Hook ran. Blocked the read. Returned an error to the model. Claude immediately apologized — 'I can't read environment files because they contain credentials' — and asked what I actually wanted. I never had to remember the policy. The harness did.
>
> If you're wondering whether the model can route around this — it can't. The hook intercepts the tool call before the model sees a result. The only way for Claude to read .env would be to write it to a different filename first, and we have a hook that blocks that too. Defense in depth."

### Hookify rules (slide 11)

> "Hookify is the easier extension point. Plain markdown files. No code to write. Each rule is a YAML frontmatter block defining the trigger, the matcher pattern, and the action.
>
> We ship fourteen rules. Block direct pushes to main. Block edits to .env files. Block service-role keys in client code. Warn on CREATE TABLE without RLS. Warn on console.log in src/. Each rule is one file. Adding a rule is a PR with one new file. No deploy."

### MCPs (slide 12)

> "MCP is Model Context Protocol — Anthropic's open standard for tool integration. Any system that exposes an MCP server can be queried by Claude in real time.
>
> We use two. Axiom for production logs — Claude can write APL queries against our log store and get live data, not copy-pasted dumps. Memory-keeper for cross-session context — facts that persist between Claude conversations, like 'engineer X is on PTO this week.'
>
> The economics matter. Before MCP, integrating Claude with a logging system meant building a custom plugin and shipping a release. With MCP, the integration is a config line."

### Transition into Act 2

> "OK — that's the setup. Operating manual, hooks, hookify, MCPs. Now let's talk about how a single feature moves through this system."

---

## Act 2 — The workflow

**Time: 15 min. Slides 12–22.**

### The lifecycle (slide 13)

> "Every feature follows this path. There are no shortcuts. The harness enforces every step.
>
> Issue. Bead. Worktree. Confidence gate. Code in worktree, hooks fire on every tool call. Lint. Push. Vercel preview. Screenshots. Security auditor. Vote-for-PR — five reviewer agents. PR open. Human review. Merge. Bead closed.
>
> And then — pay attention to the last box — a scheduled cloud routine fires twenty-four to seventy-two hours later to verify the fix actually shipped. We'll come back to that in Act four."

### Issue → bead → worktree (slide 14)

> "Three artifacts created before any code touches disk. They serve different purposes.
>
> The GitHub issue is for humans. It lives on the project board. Sales might reference it. Customer success might reference it. It's the human-facing tracker.
>
> The bead is for the AI. It's a JSON file in `.beads/issues.jsonl`, committed to git. Every Claude session in any worktree on this repo reads it. When you're working on five features in parallel, the bead is how each session knows what the others are doing.
>
> The worktree is the workspace. Hard isolation. Its own branch, its own working tree, its own `.git/` index. Fifteen worktrees, fifteen branches, zero collisions.
>
> A UserPromptSubmit hook fires on every new task and reminds you to create all three. If you skip a step, you get a nudge."

### Beads (slide 15)

> "Beads is Steve Yegge's AI agent memory system. We didn't invent it. We adopted it because it solves a specific problem — persistent state across sessions and machines.
>
> File-based, JSONL, committed to git. No central server. No auth. The model reads it on startup, writes to it as state changes, and the changes propagate through the same git workflow as your code.
>
> Run `bd ready` to see what's active. Run `bd create` to add work. Run `bd close` when you're done. Every Claude Code session does this automatically."

### tmux (slide 16)

> "Each Claude Code session runs inside a tmux session. tmux is a terminal multiplexer that's existed since 2007 — boring, battle-tested.
>
> Why? Because VS Code crashes. WSL crashes. The only thing that doesn't crash is tmux. Sessions live in the tmux server, independent of any IDE.
>
> When VS Code dies, you reopen it, run `tmux attach -t <session>`, and you're right back where you were. Mid-prompt. Mid-tool-call. Whatever the state was."

### WSL ext4 (slide 17)

> "Boring detail that determines whether the workflow scales.
>
> WSL2 mounts your Windows C: drive at `/mnt/c/` via a 9P protocol bridge. Every file operation crosses that bridge. For one or two operations, fine. For fifteen worktrees doing thousands of operations per command, it's death.
>
> Solution: clone repos into WSL's native ext4 filesystem at `~/repos/`, not `/mnt/c/`. We measured the difference. Git status went from four seconds to half a second. Lint went from ten seconds to under one. With fifteen worktrees, the math is brutal — sixty seconds versus two seconds.
>
> The toolkit ships a migration script that handles the move."

### Confidence Gate (slide 18)

> "The most underrated step in the workflow.
>
> Most demo failures come from the model jumping to code on a half-understood task. The user says 'fix the bug' and the model picks the wrong bug, or fixes it the wrong way, and you waste twenty minutes before realizing the model misread the requirements.
>
> The Confidence Gate is a stop sign. Before any code, the orchestrator must reach eight out of ten confidence on requirements, scope, affected files, data model, security implications, edge cases, and testing strategy. If it can't, it asks clarifying questions until it can.
>
> Thirty seconds of confirmation. Prevents thirty minutes of wasted code. We measured. Throwaway implementations dropped sixty percent."

### Live: 60-second feature spin-up (slide 19)

[**Switch to terminal. Run the runbook commands.**]

> "I'll spin up a feature, end-to-end, while we talk."

[**Run:**]
```bash
gh issue create --title "DEMO: typo on landing hero" --body "..." --label "demo"
bd create "DEMO: typo fix (GH-####)" -p 3
git worktree add ../<repo>-worktrees/GH-####-demo-typo -b feature/GH-####-demo-typo dev
cd ../<repo>-worktrees/GH-####-demo-typo
tmux new-session -d -s demo-typo "cd $(pwd) && claude"
tmux attach -t demo-typo
```

[**In the Claude session:**] `fix the typo "exmaple" → "example" on the landing page hero`

> "Sixty seconds from issue to in-progress. Notice the Confidence Gate just nudged me — it wanted to confirm scope before editing. The cross-worktree hook is silently watching. The lint hook will run when I commit. None of this is in the prompt. All of it is in the harness."

### Cross-worktree isolation (slide 21)

> "This is what keeps fifteen sessions from stomping on each other.
>
> Every Edit and Write tool call goes through `check-cross-worktree.sh`. The hook checks: is the target file inside the current worktree? If yes, allow. If no, exit two with a clear message. The model reads the message and pivots — usually with 'I should be working in worktree A, not B.'
>
> For genuinely cross-cutting changes — say, a shared schema file that two features need to update — sessions coordinate via `coordination/state.json`. Soft locks with thirty-minute idle timeouts. We rarely need it."

### Transition into Act 3

> "OK. Setup is wired. Workflow is enforced. Now let's talk about the agents themselves."

---

## Act 3 — The agents

**Time: 10 min. Slides 23–28.**

### Old pipeline vs new (slides 23–24)

> "We started with an eight-agent pipeline. Architect, backend, frontend, test, security, review, docs, devops. Sequential. Mandatory. Every task ran all eight.
>
> CSS fix? Eight agents. Typo? Eight agents. We were burning Opus quota for no reason. Quality was high. But cost-per-trivial-fix was absurd. Engineers started avoiding the system for small work, which defeated the purpose.
>
> The new model: Opus reads the task and picks. Trivial? No agents — direct edit. Small bug? One or two agents. Small feature? Three to five in parallel. Big feature? Plan first with /generate-prp, then dispatch specialists according to the plan.
>
> The only mandatory gate is /security-auditor for anything touching auth, RLS, payments, or user data. Everything else is right-sized."

### 26 specialists (slide 25)

> "Each one is a markdown file under `.claude/commands/`. They're prompts, not code. Trivial to customize. Trivial to add new ones.
>
> Some are domain-specific — /customer-support, /sales-onboarding. Strip these in the toolkit if they don't apply to your business. Add domain-specific ones for your business — for us that meant /marketing-content for blog posts and /data-analyst for SQL.
>
> The security auditor has a star next to it because it's the only mandatory one."

### Model selection (slide 26)

> "Most teams default to 'use the smartest model always.' That works for a week. Then you hit the Opus rate limit and the system grinds to a halt.
>
> Per-PRP `Recommended Model:` field forces engineers to think about cost. Routine code review goes to Sonnet. Architecture decisions go to Opus. Triage and classification go to Haiku.
>
> This is engineering economics now. The same way we think about p99 latency or memory budget."

### Live: /start-task (slide 27)

[**Switch to terminal.**]

> "Watch the orchestrator route a small feature."

[**In Claude session:**] `/start-task add a dark mode toggle to the navbar`

> "Watch what's happening. Orchestrator parsed 'add a dark mode toggle' as a small frontend feature. It's invoking /frontend-developer and /test-automation in parallel. Skipping architect because no schema change. Skipping backend because no API change. Skipping devops because no deploy config change. Security auditor will run at the end as a pass-through — no auth code touched, fast.
>
> Total wall-clock: about ninety seconds. If this had been auth work, security-auditor would have spent five minutes and possibly blocked the PR with a list of fixes."

### /vote-for-pr (slide 28)

> "Before opening any PR, run /vote-for-pr. Five reviewer agents in parallel.
>
> code-reviewer looks at security, bugs, conventions.
>
> silent-failure-hunter is the killer. It catches error swallowing, async hazards, the lambda-lifecycle bugs we'll see in Act four.
>
> pr-test-analyzer flags missing test coverage.
>
> comment-analyzer flags inaccurate or unnecessary comments.
>
> type-design-analyzer looks at type safety and API shape.
>
> All five must approve, or the PR doesn't open. Total wall-clock: about fifteen seconds.
>
> /quick-review is the lighter alternative for routine PRs — single agent, faster, eighty percent of the value at twenty percent of the cost."

### Transition into Act 4

> "OK — agents covered. Now we're getting to the part nobody else is doing."

---

## Act 4 — Claude Routines

**Time: 15 min. Slides 29–37.**

### What is a Claude Routine (slide 30)

> "Pause for a moment. Let this land.
>
> A Claude Routine is an agent that runs on cron, in the cloud, with no human in the loop. It watches production. It verifies deploys. It catches silent failures. It files GitHub issues automatically when something is wrong.
>
> You have CI tests. You have monitoring. You have synthetic checks. You almost certainly do not have this.
>
> Tests verify code. Routines verify outcomes."

### Routine vs test vs APM (slide 31)

> "Walk through with me.
>
> Unit tests catch logic bugs inside a function. They miss schema drift, deploy issues, environment mismatches.
>
> E2E tests catch happy-path UI regressions. They miss silent backends — webhooks dropped, emails not sent, alerts swallowed.
>
> APM — Sentry, Datadog — catches errors that throw or log. They miss silent two hundreds, where the request returned successfully but the work didn't actually happen.
>
> Synthetic monitoring catches endpoints being up. It misses whether the endpoint did the thing it was supposed to do.
>
> A Claude routine asks the question a smart engineer would ask if they had unlimited time and zero distraction: after we shipped this, did the user-visible signal actually fire, end-to-end, the way we intended?"

### The flywheel (slide 32)

> "Developer merges PR. Vercel deploys to prod. Twenty-four to seventy-two hours later, the routine fires.
>
> The delay is intentional. We let prod settle. We let users hit the edge cases that synthetic tests don't simulate.
>
> The routine queries multiple signals: the production URL, prod logs via Axiom MCP, synthetic Playwright runs, metric comparisons against pre-merge baseline.
>
> All paths terminate cleanly. Either close the verification ticket — pass — or file a useful GitHub issue with evidence and tag oncall.
>
> No retry loops. No human escalation chains. Just: did it work, yes or no?"

### Routine examples (slides 33–34)

> "We have around twenty routines in production. Five of the templates are in `demo/routines/` in the toolkit.
>
> Routine one — post-merge outcome verification. After any PR with auth, signup, email, or payment labels, fire twenty-four hours later. Check if the user-visible signal — Slack messages, sent emails, payment alerts — matches the count of underlying events. Off by more than ten percent? Regression. File issue.
>
> Routine three — cron auth audit. Every Monday morning, hit every cron route with three different auth headers: missing, wrong, correct. Verify the responses are 401, 401, 200. This is the routine that caught our silent cron 401 incident."

### Case study: silent cron 401 (slide 35)

> "Story time.
>
> A new Vercel Cron route — trial-drip retention emails on day one, three, seven, eleven, fourteen — was shipped with a broken auth pattern. Bare `if (!auth) return 401`. The check passed when *any* Authorization header was present. It never validated the value.
>
> Five days. Zero retention emails. Zero alerts. Zero customer reports. The cron returned 401 on every firing because middleware higher in the chain was returning 401 on missing user session, which Vercel Cron requests don't have.
>
> A human would not have caught this. Error monitors don't page on 401s — they're 'client errors.' Vercel logs showed 'middleware OK, handler 401' which looks normal. Nobody was reading cron logs daily.
>
> Routine three caught it on Monday morning. Sent a wrong-token request to /api/cron/trial-drip. Got 200 back. Filed a GH issue: 'silent churn — trial-drip auth not validating, here are five other routes with the same pattern.'
>
> Triage in five minutes. Orchestrator dispatched security-auditor, backend-developer, test-automation in parallel. PR open in thirty minutes. Merged sixty minutes later. Total time from detection to fix: ninety minutes.
>
> The narrator beat: the only thing that found this was a Claude agent on cron, doing the world's most boring smoke test once a week. And it found it because we were forced to write the test once, in the form of a routine, and then it ran forever."

### Case study: welcome email (slide 36)

> "Second story.
>
> A migration renamed `families.welcome_email_sent` to `families.onboarding_state` — JSONB blob with multiple flags. Migration ran clean. Dashboard queries updated. Tests passed.
>
> What nobody noticed: the welcome-email cron still queried the old column name. Postgres returned 'column does not exist' as an error. Supabase wrapped the error in a 200 response with `data: null`. The handler did `if (data && data.length > 0)` and skipped the loop body. Cron returned 200 every firing. Two months. Zero welcome emails delivered to new families.
>
> The metric we look at — families.created_at — went up. The metric we should have looked at — welcome_emails_sent — wasn't being tracked.
>
> Schema-doc reconcile routine fires within an hour of every migration merge. Compares migration DDL against codebase grep results. Files an issue per orphan reference.
>
> The fix isn't more discipline. The fix is more automation. Discipline doesn't scale. A routine does."

### The meta-routine (slide 37)

> "Final piece.
>
> When you have many routines running, the registry of routines drifts. New ones get added without doc updates. Old ones get disabled but stay in the doc.
>
> So we have a routine whose only job is to verify that the registry of routines is correct. Reads the doc. Queries the live scheduler. Files a GitHub issue when they drift.
>
> A routine that audits routines. Self-auditing automation. The system patrols itself."

### Economics (slide 38)

> "The math.
>
> Per-routine API cost: ten cents to two dollars per run, mostly Sonnet.
>
> Frequency: weekly to per-merge.
>
> Total monthly across twenty-plus routines: fifty to two hundred dollars.
>
> The dollar value of one prevented silent-churn week is more than the entire monthly Claude bill. We've prevented at least a dozen of those in the last six months.
>
> One catch pays for a year of routines."

### Transition into take-home

> "OK — that's the headline. Routines are the part of this setup that nobody else has built yet. If you take one thing from this talk, take this idea: build routines that watch your outcomes, not your code."

---

## Take-home

**Time: 3 min. Slides 39–41.**

### Get the toolkit (slide 40)

> "Everything you've seen is in this repo. Hooks. Hookify rules. Twenty-six agent commands. Templates. The full PR-review plugin. The runbook for this exact demo. The case studies. The routine templates.
>
> One command to install. The script copies hooks into your `.claude/` directory, drops in the templates, and shows you what to customize.
>
> CLAUDE.md is the most important customization — your stack, your rules, your incidents.
>
> Hookify rules: your blocking patterns. Add one for every incident you've seen.
>
> Agent commands: strip what doesn't apply, add domain-specific ones.
>
> Routine prompts: replace placeholders with your prod URLs and channels."

### Recap (slide 41)

> "Quick recap.
>
> Setup: CLAUDE.md as operating manual, hooks turn policy into enforcement, hookify is policy as markdown, MCPs extend Claude's reach.
>
> Workflow: issue, bead, worktree. Confidence Gate. Cross-worktree isolation. Fifteen parallel sessions.
>
> Agents: orchestrator plus twenty-six specialists. Right-sized, parallelized. Model economics. /vote-for-pr.
>
> Routines: cron Claude agents. Verify outcomes, not code. Catch silent failures. The meta-routine.
>
> Questions?"

---

## Anticipated Q&A

### "What if the hooks fight my workflow?"

> "Every hook is a script. Every script is editable. Disable the ones you don't need; rewrite the ones that don't fit. The toolkit is a template, not a religion. Most teams strip about a third of the hooks initially, then add their own as incidents reveal new patterns to block."

### "Doesn't fifteen parallel sessions blow your context budget?"

> "Each session has its own context. They don't share. The shared state is the beads file — a few KB — and the coordination state file, also small. Claude API charges per-session, so yes, fifteen sessions cost fifteen times one session. But each session is shipping a different feature, so cost-per-PR drops, not rises. The constraint is human attention, not API spend."

### "Do you trust Claude to run cron jobs unsupervised?"

> "We trust it the same way we trust any cron job: scoped, narrow, well-tested, with auditable outputs. A routine that posts to a Slack channel and files GH issues is observable. We can read its work tomorrow morning. If a routine starts going off the rails, we kill it the same way we'd kill a misbehaving Lambda. The safety property we lean on is: routines have hard constraints in their prompts. 'Do not modify production data. Do not modify the repo. Your only side effect is filing a GH issue.' Those constraints are honored."

### "What's the failure mode when a hook breaks?"

> "Hooks log to stderr. The harness shows the model the stderr output. The model usually figures it out and works around it. If a hook is genuinely broken — exit codes wrong, infinite loop — we catch it during the next dev session because everything blocks. Fix-forward."

### "What's the ROI?"

> "We measure two things. Wall-clock to PR is down forty percent. Silent failures caught in prod went from one a quarter to zero in the last ninety days. The dollar value of one prevented silent-churn week is more than the entire monthly Claude bill."

### "Could I use this for non-SaaS?"

> "Yes. Strip the SaaS-specific commands — /customer-support, /sales-onboarding, /marketing-content. Keep the workflow, hooks, agents, model selection. The bones are general. We've heard from a couple of folks using it on internal CLIs and on a Rust backend. The hookify rules need adapting per stack but the framework holds."

### "What models are you using?"

> "Opus 4.7 for orchestration and complex work. Sonnet 4.6 for routine. Haiku 4.5 for triage and classification. The model-selection rules are in templates/model-selection.md in the toolkit. We track per-agent model usage and adjust quarterly."

### "What if my company doesn't allow public model APIs?"

> "Anthropic has a private VPC offering. Same harness, same hooks. The toolkit doesn't care which API endpoint Claude Code is talking to. If you're on AWS Bedrock or Google Vertex with Claude, the toolkit also works — Claude Code supports both."

### "How long did this take to build?"

> "About three thousand hours over eighteen months. The first six months were a mess — we were just figuring out what Claude Code could do. The next six was building hooks and agents reactively, in response to incidents. The last six has been generalization and packaging. The toolkit is the artifact of the third phase."

### "What's the hardest hook to write?"

> "check-cross-worktree.sh. It has to detect what worktree the current process is in, what worktree the target file is in, and decide whether to allow or block. There are edge cases — symlinks, submodules, repos cloned outside ~/repos — that took several incidents to handle. The version in the toolkit reflects all those iterations."

### "Where does the routine code actually run?"

> "Anthropic offers a scheduled-agents capability — Claude agents that run on cron in their cloud. We use that. There are alternatives: GitHub Actions running Claude Code in headless mode on a cron schedule, self-hosted runners, etc. The routine prompts are platform-agnostic. Pick a runner that fits your security posture."

### "What about prompt injection in routines?"

> "Real concern. Three mitigations. One: routines query data, they don't accept arbitrary user input. The data they query — your prod logs — could in theory contain injected text, but the routine prompts have hard constraints that limit what they can do regardless. Two: the only side effect a routine has is filing a GH issue or closing one — neither is destructive. Three: we audit routine outputs weekly. Anything that looks off is investigated."

### "What about cost when something goes wrong?"

> "Routines have a maximum-run timer. If the agent gets stuck, it terminates. If it tries to invoke unbounded tool calls, the harness rate-limits. We've never had a routine cost more than ten dollars in a single run, even when going completely sideways. The economics are bounded."

### "How do I roll this out to a team?"

> "Don't roll out everything at once. Start with three things: hooks for branch protection and .env reads, the worktree workflow, and one or two specialist agents — start with /security-auditor and /code-reviewer. Get the team comfortable. Then add hookify rules per incident. Then add routines once you have one or two production silent-failure stories. The order of adoption matters; jumping to routines first overwhelms people."

---

## Failure modes during the talk

| Symptom | Recovery |
|---|---|
| .env block hook doesn't fire | Switch to asciinema cast `02c-env-block.cast` (in demo/asciinema/) |
| /start-task slow / times out | Pre-recorded cast `04b-start-task.cast` |
| tmux session crashes mid-demo | `tmux attach -t <session>` to recover, or skip to next slide |
| Slidev dev server crashes | PDF backup at `demo/slides/dist/slides.pdf` |
| Network down — can't reach API | All material is local. Skip live demos, narrate from this script |
| WSL crash recovery hook fires unexpectedly during talk | Acknowledge with humor: "the system is showing you it's real" |

If something genuinely breaks: **stay calm, narrate what should have happened, and move on**. The audience will forgive a glitch. They will not forgive you stalling.
