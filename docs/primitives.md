# Skills · Agents · MCPs · Workflows

A deep dive on the four building blocks of Claude Code — what each one *is*, where it lives, how the agent gets it, and when to reach for which. Also covers the enforcement model: how to make the agent *actually do* what you want, not just *be aware* it could.

> **TL;DR** — You don't train Claude. You **wire it up** in different places. Each of the four primitives has a different attachment point and a different enforcement strength. The strongest pattern is almost always *document soft + enforce hard with a hook*.

---

## Table of contents

- [The four primitives at a glance](#the-four-primitives-at-a-glance)
- [Skill (slash command)](#skill-slash-command)
- [Agent (subagent)](#agent-subagent)
- [MCP (model context protocol server)](#mcp-model-context-protocol-server)
- [Workflow (procedure)](#workflow-procedure)
- [How they compose](#how-they-compose)
- [The enforcement model — soft vs hard](#the-enforcement-model--soft-vs-hard)
- [Same goal, three enforcement options](#same-goal-three-enforcement-options)
- [Decision matrix — when to use what](#decision-matrix--when-to-use-what)
- [Common pitfalls](#common-pitfalls)
- [See also](#see-also)

---

## The four primitives at a glance

| Primitive | What it is | Lives at | Loaded when | Enforcement |
|---|---|---|---|---|
| **Skill** | Reusable prompt template (slash command) | `.claude/commands/<name>.md` | Skill is invoked (`/<name>` or Skill tool) | Soft — agent decides; CLAUDE.md hints help |
| **Agent** | A separate Claude instance with its own context window | `Agent` tool call | Spawned via Agent tool | Soft — orchestrator decides when to spawn |
| **MCP** | An external tool server that exposes capabilities over a protocol | `.mcp.json` config + the server process | Tools appear in the agent's tool list at session start | Soft — agent picks tools by description |
| **Workflow** | A multi-step pattern that orchestrates the other three | `CLAUDE.md` prose + `.claude/hooks/*.sh` | Read at session boot + enforced per tool call | **Hard** when backed by hooks; soft otherwise |

The key insight: **none of these are about "training" the model**. They're about *where you attach instructions* to the running agent — and *whether the attachment is a suggestion or a wall*.

---

## Skill (slash command)

### What it is

A markdown file containing a reusable prompt. When invoked, its content is **injected into the conversation as a system-prompt extension** — the agent loads the role/persona just-in-time and acts on it until the skill returns.

A skill is a *template you write once and apply many times*.

### Where it lives

```
.claude/commands/<name>.md
```

Example file (`/.claude/commands/code-reviewer.md`):

```markdown
# Code Reviewer

You are the Code Reviewer. Your role is to enforce code quality, security,
and conventions. ...

## Review checklist
- [ ] Code follows project conventions
- [ ] Types are properly defined
- ...

## Output format
... (the agent's response shape) ...
```

### How the agent gets it

1. At session start, Claude Code scans `.claude/commands/` and lists available skills in a system-reminder.
2. The user types `/code-reviewer` (or the agent calls the Skill tool with `skill: "code-reviewer"`).
3. The skill's markdown is loaded as instructions for the next turn.
4. The agent *becomes* the Code Reviewer until that turn completes.

### When to reach for it

- You have a **specific task** you do repeatedly (review, test, debug, write a particular kind of doc).
- The task has a **fixed shape** that benefits from a reusable prompt.
- You want users to be able to invoke it with a single command.

### Caveat

Skills are **soft instructions**. Nothing forces the agent to invoke them — even if CLAUDE.md says "always invoke `/security-auditor` before PRs," the agent may skip under context pressure. See [enforcement model](#the-enforcement-model--soft-vs-hard) below.

---

## Agent (subagent)

### What it is

A **separate Claude instance** spawned for a specific task. It has its own context window (doesn't share the parent's history), can be given a constrained tool set, and returns a single response when done.

Subagents are most useful when:
- The work would otherwise blow out the parent's context (open-ended research, deep file exploration)
- The work is **independent** and can be parallelized
- The work needs **isolation** so its intermediate output doesn't pollute the parent's reasoning

### Where it lives

Subagent types are defined either built-in (Claude Code ships `Explore`, `general-purpose`, `Plan`, etc.) or as project-specific subagents you configure.

The spawn happens via the `Agent` tool call:

```typescript
Agent({
  description: "short label",
  subagent_type: "Explore",
  prompt: "Find every usage of getUserById across the codebase..."
})
```

### How the agent gets it

The orchestrator agent (the lead Claude session) sees the `Agent` tool in its tool list. It decides when to spawn a subagent based on the task at hand.

You guide the choice via:
- CLAUDE.md notes ("For codebase exploration >3 queries, use `Explore`")
- The subagent_type's description (registered with Claude Code)

### Caveat

**Subagents cannot spawn subagents.** Anthropic docs are explicit: one level of nesting only. If your workflow needs multi-level delegation, do it sequentially from the lead, or use Skills.

---

## MCP (model context protocol server)

### What it is

An **external server** that exposes tools to Claude over a standardized protocol (MCP — Model Context Protocol). MCP servers can be local processes (stdio) or remote (HTTP). Once connected, the server's tools appear in the agent's tool list, namespaced as `mcp__<server>__<tool>`.

MCPs let Claude reach external systems — databases, observability platforms, ticket trackers, custom internal APIs — without anyone writing a custom Claude plugin.

### Where it lives

Configured in `.mcp.json` at the project root (or `~/.claude/mcp_settings.json` for user-wide):

```json
{
  "mcpServers": {
    "memory-keeper": {
      "command": "npx",
      "args": ["-y", "memory-keeper"]
    },
    "betterstack": {
      "command": "npx",
      "args": ["-y", "@betterstack/mcp"],
      "env": { "BETTERSTACK_TOKEN": "..." }
    }
  }
}
```

### How the agent gets it

1. Claude Code starts a session, reads `.mcp.json`, connects to each configured server.
2. Each server advertises its tools (with names + descriptions) via the protocol.
3. The agent's tool list now includes `mcp__memory-keeper__context_get`, `mcp__betterstack__telemetry_query`, etc.
4. The agent picks them like any other tool, based on the tool description matching the task.

### When to reach for it

- You need the agent to interact with an **external system** (logs, DBs, APIs, SaaS tools).
- A community or vendor already published an MCP server for the thing you want.
- You're willing to **write the tool descriptions well** — that's the main lever for "training" the agent to use the MCP correctly.

### Caveat

The agent's choice of MCP tool is driven by the **tool description**. A vague description ("Get data") means the agent won't know when to call it. A specific description ("Query production logs for the last 24h via Better Stack; returns structured rows") tells the agent exactly when to reach for it.

---

## Workflow (procedure)

### What it is

A **multi-step pattern** that orchestrates skills, agents, MCPs, and shell calls to deliver a complete unit of work. Examples: the issue→bead→worktree→PR pattern, the pre-PR review quorum, the post-merge verification routine.

Unlike skills/agents/MCPs, a workflow isn't a single artifact you invoke. It's a **rule set** the agent follows across many turns.

### Where it lives

Three places, in order of strength:

1. **`CLAUDE.md`** — the prose procedure manual. The agent reads it at session start and tries to follow it.
2. **A wrapper skill** (optional) — something like `/start-task` that walks the lead through the steps as a guided invocation. Useful when the workflow is too long to remember.
3. **`.claude/hooks/*.sh`** — Claude Code hooks that intercept tool calls and *enforce* specific steps. This is the only mechanism that **prevents** the agent from skipping a step.

### How the agent gets it

- CLAUDE.md is loaded at session boot. The agent tries to follow it.
- Hooks fire on every tool call (PreToolUse, PostToolUse, UserPromptSubmit, etc.) and can deny, modify, or augment the call.
- A skill like `/start-task` is invoked by the user or lead when starting a new task.

### When to reach for it

- You have a **multi-step process** that should happen the same way every time.
- The process touches multiple primitives (skills, agents, MCPs, shell, git).
- You want to enforce **discipline** — every PR goes through the same gates.

---

## How they compose

```
                       ┌─────────────────────┐
                       │      Workflow       │
                       │  (CLAUDE.md prose,  │
                       │   /start-task,      │
                       │   hooks enforcing)  │
                       └──────────┬──────────┘
                                  │ orchestrates
                ┌─────────────────┼─────────────────┐
                ▼                 ▼                 ▼
        ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
        │    Skill     │  │    Agent     │  │     MCP      │
        │  (prompt     │  │  (separate   │  │  (external   │
        │   template)  │  │   instance)  │  │   tools)     │
        └──────────────┘  └──────────────┘  └──────────────┘
              ▲                 ▲                 ▲
              │                 │                 │
        Loaded as           Spawned by         Tool calls
        system-prompt       Agent tool          in same
        on invocation                            conversation
```

A real example (the `/start-task` workflow that ships in this toolkit):

1. **Workflow** (`/start-task` skill + CLAUDE.md rules): "for any new task, create GH issue → bead → worktree → confidence gate → invoke specialists → review → PR"
2. **Skills** invoked during the workflow: `/security-auditor`, `/code-reviewer`, `/bug-finder`, `/test-automation`
3. **Agents** spawned: `Explore` (for deep code search), `Plan` (for architecture decisions)
4. **MCPs** called: `mcp__memory-keeper__*` (cross-session context), maybe `mcp__github__*` for PR ops
5. **Hooks** enforcing: `pre-commit-lint.sh` (no lint errors), `check-vercel-before-pr.sh` (no PR without Vercel green), `block-env-read.sh` (no reading `.env` files)

The Workflow doesn't *contain* the others — it *coordinates* them.

---

## The enforcement model — soft vs hard

This is the part most people miss when first wiring up Claude Code.

**Soft enforcement** = the agent has the information it needs to do the right thing, but nothing forces it. Examples:
- CLAUDE.md says "always do X" — the agent reads it, may comply, may not
- A skill is available — the agent may invoke it, may forget
- An MCP tool exists — the agent may pick it, may use Bash instead

**Hard enforcement** = a hook physically prevents the wrong action. Examples:
- `check-vercel-before-pr.sh` returns non-zero on `gh pr create` if Vercel preview hasn't passed
- `check-cross-worktree.sh` blocks Edit/Write on files outside the current worktree
- `block-env-read.sh` returns deny on `Read` of any `.env` file

Hard enforcement requires writing a **shell hook** that:
- Reads the tool-call JSON from stdin
- Returns an exit code (0 = allow, 2 = deny) and/or structured JSON output
- Is registered in `.claude/settings.json` under `hooks.<event>.<matcher>`

See [`hooks/README.md`](../hooks/README.md) for the existing hook catalog and [`hookify-rules/`](../hookify-rules/) for declarative rules.

---

## Same goal, three enforcement options

Say you want the agent to **always invoke `/security-auditor` before opening any PR.** You have three ways to wire that, each with different strength:

### Option 1 — Skill route (soft)

Just instruct in CLAUDE.md:

```markdown
## PR creation

Before any `gh pr create`, you MUST invoke `/security-auditor` and
attach its verdict to the PR description. Do not open the PR if
the auditor returns BLOCK.
```

**Failure mode:** under context pressure (long conversation, many tool calls), the agent may forget the rule. The rule is in the system prompt but competes with everything else the agent is tracking.

### Option 2 — Workflow route (still soft)

Encode it as a numbered step in the canonical PR workflow:

```markdown
## PR workflow

1. Create branch from dev
2. Implement changes
3. Run /security-auditor — verdict required before proceeding
4. Run /code-reviewer — verdict required before proceeding
5. Push and gh pr create
```

**Failure mode:** still soft. More legible than a one-line rule, but same fundamental property — the agent can skip Step 3 and proceed to Step 5. No mechanism stops it.

### Option 3 — Hook route (HARD)

Write a `.claude/hooks/check-security-before-pr.sh` PreToolUse hook on the `Bash` matcher that intercepts `gh pr create`:

```bash
#!/usr/bin/env bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

if echo "$COMMAND" | grep -qE 'gh\s+pr\s+create'; then
  TRAILERS=$(git log -1 --format='%(trailers:key=Reviewed-By,valueonly=true)' HEAD)
  if ! echo "$TRAILERS" | grep -qFx "security-auditor"; then
    cat >&2 <<MSG

========================================
  BLOCKED: /security-auditor required
========================================

  HEAD commit does not carry a 'Reviewed-By: security-auditor'
  trailer. Invoke /security-auditor and add the trailer to the
  commit (or a follow-up commit) before opening the PR.

MSG
    exit 2
  fi
fi
exit 0
```

Register in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": ".claude/hooks/check-security-before-pr.sh",
        "timeout": 5
      }]
    }]
  }
}
```

**Failure mode:** none from the agent's side. The agent **cannot** open a PR without the trailer. It can't forget. It can't rationalize. The Bash tool call returns deny + a clear message telling it what to do next.

### The pattern that works

The toolkit's recommendation: **document soft + enforce hard**.

- **Document soft** — CLAUDE.md explains the *why* and the *how*. Skill descriptions are clear. MCP tool descriptions are specific. This is what makes the agent *intend* to do the right thing.
- **Enforce hard** — hooks block the *consequential* mistakes. PR can't open without checks. `.env` can't be read. Schema migrations can't merge without ref-arch doc updates.

You don't need hard enforcement on everything. Use it where the cost of forgetting is high (production deploys, security checks, key rotation, RLS enforcement) and accept soft on everything else.

---

## Decision matrix — when to use what

| You want to... | Reach for | Why |
|---|---|---|
| Make the agent perform a specific task on demand | **Skill** | Reusable prompt template, invoked when needed |
| Have the agent do open-ended research without polluting main context | **Agent** (subagent) | Isolated context window |
| Give the agent access to a database, log platform, ticket tracker, etc. | **MCP** | Standardized external-tool protocol |
| Codify a multi-step process the team always does the same way | **Workflow** (CLAUDE.md + skill + hooks) | Combines all three primitives + enforcement |
| Prevent a specific mistake from ever happening | **Hook** (under Workflow) | Hard enforcement at the tool boundary |
| Customize how the agent reviews PRs | **Skill** (e.g. `/code-reviewer`) | Role-specific prompt with checklist |
| Parallelize independent work | **Agent** spawns (multiple in one message) | Independent context windows, true parallelism |
| Add a new vendor or service to the agent's reach | **MCP** | The standard answer; avoid custom plugins |
| Enforce "always document the why in commits" | **Skill** + **Hook** | Skill writes the commit; hook checks format |

---

## Common pitfalls

### "I told the agent in CLAUDE.md but it didn't do it"

Soft enforcement only. Under context pressure, instructions in CLAUDE.md can lose to other priorities. If the rule is **critical**, add a hook. If it's a *preference*, accept the failure rate.

### "My MCP is connected but the agent never uses it"

Tool description is too vague. The agent picks tools based on the description. Rewrite the MCP's tool descriptions to be **specific and task-aligned**: "Query production logs from the last 24h via Better Stack" beats "Get data".

### "I have 5 skills and they conflict / overlap"

Skills are most effective when **non-overlapping** and **named for the task**, not the topic. `/code-reviewer` and `/security-auditor` are clear; `/check-things` and `/quality-pass` are not.

### "My workflow is in CLAUDE.md but the team doesn't follow it"

CLAUDE.md is read by the agent, not the human team. For team discipline, also document the workflow in a `CONTRIBUTING.md` or runbook. For agent discipline, wire the critical steps into hooks.

### "Subagent spawned a subagent and it failed silently"

Subagents **cannot** spawn subagents. The Agent tool call inside a subagent will fail or no-op. Restructure: have the lead orchestrator spawn the second-level agent directly.

### "I want soft + hard but writing hooks feels heavy"

That's a feature. The friction of writing a hook is exactly what stops you from over-enforcing. Use hooks where the cost of skipping is real (security, deploys, data loss). Use soft instructions everywhere else.

---

## See also

- [`hooks/README.md`](../hooks/README.md) — the existing hook catalog and how to add a new one
- [`hookify-rules/`](../hookify-rules/) — declarative rules for common block/warn patterns
- [`commands/`](../commands/) — the shipped skills (slash commands) you can copy/customize
- [`docs/multi-agent-orchestration.md`](./multi-agent-orchestration.md) — the multi-vendor binding review loop (Claude + Codex), which combines all four primitives + hard enforcement
- [`AGENTS.md`](../AGENTS.md) — agent system overview
- [`templates/CLAUDE.md.template`](../templates/CLAUDE.md.template) — starting point for your own CLAUDE.md
