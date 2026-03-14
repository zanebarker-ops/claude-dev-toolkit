# Agent System

SafeGamer uses specialized AI agents for different tasks. **Use agents proactively based on the task type.**

## When to Use Which Agent

| Task Type | Agent | Example |
|-----------|-------|---------|
| **Full feature** | `/start-task` | "Build conversation guides" |
| **Design/architecture** | `/software-architect` | "Design schema for alerts" |
| **API/backend work** | `/backend-developer` | "Create webhook endpoint" |
| **UI/components** | `/frontend-developer` | "Build friend card component" |
| **Test-first dev** | `/tdd` | "Add email validation" (RED-GREEN-REFACTOR) |
| **Write tests** | `/test-automation` | "Add E2E tests for onboarding" |
| **Security review** | `/security-auditor` | "Check RLS on new table" |
| **Code review** | `/code-reviewer` | "Review this PR" |
| **Documentation** | `/documentation-writer` | "Document the Trust Network API" |
| **Deployment/infra** | `/devops-infrastructure` | "Setup new env variable" |
| **Support question** | `/customer-support` | "How do I explain billing?" |
| **Product info** | `/knowledge-base` | "What are the tier limits?" |
| **Marketing copy** | `/marketing-content` | "Write blog post about safety" |
| **Metrics/data** | `/data-analyst` | "Monthly revenue report" |
| **Sales/onboarding** | `/sales-onboarding` | "Handle price objection" |
| **Bug finding** | `/bug-finder` | "Find edge cases in risk calculator" |
| **PR voting** | `/vote-for-pr` | "Get consensus before PR" |
| **Quick PR review** | `/quick-review` | "Fast single-pass review" |

## Orchestration: Opus 4.6 as Orchestrator

For any task (feature, bug fix, refactor), use `/start-task`:

```
/start-task Build conversation guides feature with schema, API, and UI
```

Opus 4.6 orchestrates intelligently:
- **Decides** which specialist agents to invoke based on task complexity
- **Parallelizes** independent work (e.g., backend + frontend when API contract is defined)
- **Skips** unnecessary agents (a CSS fix does not need `/software-architect`)
- **Enforces** the security gate -- `/security-auditor` is mandatory before any PR touching auth/RLS/data/payments

The rigid 8-phase sequential pipeline (`/execute-feature`) has been archived.
Opus 4.6 replaces it with intelligent, right-sized orchestration.

## Quick Tasks: Direct Agent

For single-purpose tasks, invoke the agent directly:

```
/backend-developer Create API route for friend bulk verification
```

## PR Review Toolkit (Pre-PR Quality)

Before creating PRs, use the PR Review Toolkit for automated code review:

```bash
/pr-review-toolkit:review-pr              # Full review
/pr-review-toolkit:review-pr security     # Security focus (RLS, auth)
```

**6 Specialized Agents:**
- `code-reviewer` - CLAUDE.md compliance, security, bugs
- `silent-failure-hunter` - Error handling, Supabase patterns
- `pr-test-analyzer` - Test coverage gaps
- `comment-analyzer` - Comment accuracy
- `type-design-analyzer` - Type invariants
- `code-simplifier` - Simplify complex code

See `.claude/plugins/pr-review-toolkit/README.md` and `.claude/workflows.md` (Step 5b2) for details.

## External Tools (Globally Installed)

### Zeroshot (Multi-Agent Clusters)

**Globally installed:** `npm install -g @covibes/zeroshot` (already installed)

Multi-agent coordination framework for well-defined tasks. Uses isolated agents to check each other's work.

| Scenario | Command |
|----------|---------|
| GitHub issue | `zeroshot run 123` |
| Text description | `zeroshot run "Add dark mode"` |
| With PR creation | `zeroshot run 123 --pr` |
| Full automation | `zeroshot run 123 --ship` |
| Docker isolation | `zeroshot run 123 --docker` |
| Background mode | `zeroshot run 123 -d` |
| Monitor | `zeroshot watch` |

**When to use:** Well-defined tasks, batch operations, overnight runs.
**When NOT to use:** Exploratory work, unknown unknowns.

### Memory Keeper MCP (Cross-Session Context)

MCP server for persistent context across all Claude Code sessions.

| Operation | Tool |
|-----------|------|
| Start session | `mcp__memory-keeper__context_session_start` |
| Save context | `mcp__memory-keeper__context_save` |
| Get context | `mcp__memory-keeper__context_get` |
| Checkpoint | `mcp__memory-keeper__context_checkpoint` |
| Summarize | `mcp__memory-keeper__context_summarize` |

**Use for:** Persisting decisions, sharing context between parallel sessions, crash recovery.

## Creating New Features

1. Create PRP using `/generate-prp`
2. Execute with `/start-task` or `/execute-prp`

## Pre-PR Voting (REQUIRED)

Before creating any PR, run the multi-agent voting system:

**Quick option:** For fast feedback during development, use `/quick-review` instead (~15s single-pass vs ~90s multi-agent).

```bash
/vote-for-pr
```

**5 agents vote on your code:**
- `/test-automation` → Correctness (tests)
- `/code-reviewer` → Correctness, Minimalism
- `/bug-finder` → Correctness (edge cases)
- `/software-architect` → Correctness, Minimalism
- `/security-auditor` → Security (RLS, auth)

**Consensus required:** All agents must approve before PR creation.

See `.claude/workflows.md` Step 5c for full details.

**Full Agent Documentation:** See @docs/reference/systems/agent-reference.md for detailed agent documentation and @docs/reference/systems/agent-cheatsheet.md for quick syntax reference.
