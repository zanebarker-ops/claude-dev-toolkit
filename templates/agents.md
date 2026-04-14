# Agent System

This project uses specialized AI agents for different tasks. **Use agents proactively based on the task type.**

## When to Use Which Agent

| Task Type | Agent | Example |
|-----------|-------|---------|
| **Full feature** | `/start-task` | "Build user dashboard feature" |
| **Design/architecture** | `/software-architect` | "Design schema for notifications" |
| **API/backend work** | `/backend-developer` | "Create webhook endpoint" |
| **UI/components** | `/frontend-developer` | "Build profile card component" |
| **UI/UX design** | `/ux-hcd-designer` | "Evaluate onboarding usability" |
| **Mobile responsiveness** | `/mobile-audit` | "Audit mobile layout for dashboard" |
| **Test-first dev** | `/tdd` | "Add email validation" (RED-GREEN-REFACTOR) |
| **Write tests** | `/test-automation` | "Add E2E tests for onboarding" |
| **Security review** | `/security-auditor` | "Check RLS on new table" |
| **Code review** | `/code-reviewer` | "Review this PR" |
| **Documentation** | `/documentation-writer` | "Document the notifications API" |
| **Deployment/infra** | `/devops-infrastructure` | "Setup new env variable" |
| **Support question** | `/customer-support` | "How do I explain billing?" |
| **Product info** | `/knowledge-base` | "What are the tier limits?" |
| **Marketing copy** | `/marketing-content` | "Write blog post about our launch" |
| **Metrics/data** | `/data-analyst` | "Monthly revenue report" |
| **Sales/onboarding** | `/sales-onboarding` | "Handle price objection" |
| **Bug finding** | `/bug-finder` | "Find edge cases in calculator" |
| **PR voting** | `/vote-for-pr` | "Get consensus before PR" |
| **Quick PR review** | `/quick-review` | "Fast single-pass review" |

## Orchestration: Opus as Orchestrator

For any task (feature, bug fix, refactor), use `/start-task`:

```
/start-task Build notification system with schema, API, and UI
```

The orchestrator works intelligently:
- **Decides** which specialist agents to invoke based on task complexity
- **Parallelizes** independent work (e.g., backend + frontend when API contract is defined)
- **Skips** unnecessary agents (a CSS fix does not need `/software-architect`)
- **Enforces** the security gate — `/security-auditor` is mandatory before any PR touching auth/RLS/data/payments

## Quick Tasks: Direct Agent

For single-purpose tasks, invoke the agent directly:

```
/backend-developer Create API route for bulk user verification
```

## PR Review Toolkit (Pre-PR Quality)

Before creating PRs, use the PR Review Toolkit for automated code review:

```bash
/pr-review-toolkit:review-pr              # Full review
/pr-review-toolkit:review-pr security     # Security focus (RLS, auth)
```

**6 Specialized Agents:**
- `code-reviewer` - CLAUDE.md compliance, security, bugs
- `silent-failure-hunter` - Error handling, unchecked returns
- `pr-test-analyzer` - Test coverage gaps
- `comment-analyzer` - Comment accuracy
- `type-design-analyzer` - Type invariants
- `code-simplifier` - Simplify complex code

See `.claude/plugins/pr-review-toolkit/README.md` for details.

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
- `/test-automation` — Correctness (tests)
- `/code-reviewer` — Correctness, Minimalism
- `/bug-finder` — Correctness (edge cases)
- `/software-architect` — Correctness, Minimalism
- `/security-auditor` — Security (RLS, auth)

**Consensus required:** All agents must approve before PR creation.
