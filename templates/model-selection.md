# Model Selection (Weekly Limits)

**Goal: Optimize Claude usage to stay within weekly limits.**

## VS Code Profiles

| Profile | Model | Weekly Limit | Use For |
|---------|-------|--------------|---------|
| **Sonnet-Profile** | Claude Sonnet | Max 100 | Task creation, PRPs, routine work |
| **Opus-Profile** | Claude Opus | Max 200 | Complex implementations, debugging |

## Opus 4.6 as Orchestrator

Opus 4.6 is the **primary orchestrator** for all project development. It:
- Receives the task via `/start-task`
- Handles infrastructure setup (GH issue, bead, worktree)
- Runs the Confidence Gate
- Decides which specialist agents to invoke
- Manages the security gate and completion sequence

Specialist agents (software-architect, backend-developer, etc.) provide domain knowledge but do NOT make orchestration decisions. Opus 4.6 makes all sequencing, parallelization, and skip decisions.

## Model Selection Rules

**ALWAYS use Sonnet (default) for:**
- Creating GitHub tasks/issues
- Generating PRPs (Product Requirements Plans)
- Code review (`/quick-review`, `/vote-for-pr`)
- Documentation updates
- Simple bug fixes (1-3 files)
- Routine CRUD operations

**Use Opus ONLY for:**
- Complex multi-file implementations
- Difficult debugging (intermittent bugs, race conditions)
- Architecture decisions requiring deep analysis
- Security audits on critical code
- When Sonnet produces incorrect results

## PRP Model Recommendation

**Every PRP MUST include a `Recommended Model` field:**

```markdown
## Implementation Details

**Recommended Model:** Sonnet | Opus
**Justification:** [Why this model]
```

| Task Complexity | Recommended Model |
|-----------------|-------------------|
| Simple (1-3 files, straightforward) | Sonnet |
| Medium (4-10 files, some complexity) | Sonnet |
| Complex (10+ files, intricate logic) | Opus |
| Critical (security, payments, auth) | Opus |

## Creating GitHub Tasks

**ALWAYS use Sonnet** when creating GitHub issues, bugs, or feature requests.

```bash
# Good - Uses Sonnet profile
# [In Sonnet-Profile VS Code profile]
gh issue create --title "Add logout button" --body "..."

# Bad - Wastes Opus quota on task creation
# [In Opus-Profile VS Code profile]
gh issue create --title "Add logout button" --body "..."
```

## Monitoring Usage

Track your weekly limits:
- Sonnet: 100 requests/week (routine work)
- Opus: 200 requests/week (complex work only)

**If approaching limits:** Switch to Sonnet for remaining routine work.
