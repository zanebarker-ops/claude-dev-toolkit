# Hooks

**Shell scripts that fire on Claude Code events.** They can block tool calls, inject context, or remind you about workflow steps. The `harness` runs them automatically — you never invoke them manually.

> **Hooks vs. hookify rules:** hooks are arbitrary shell scripts and can do anything (HTTP calls, complex logic, file system checks). [Hookify rules](../hookify-rules/) are declarative markdown files good for simple pattern matching. Use hooks when you need code; use hookify when a regex would do.

## How they wire in

Each hook is registered in `~/.claude/settings.json` (or your project's `.claude/settings.json`) under a specific event:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write", "hooks": [{ "command": ".claude/hooks/check-cross-worktree.sh" }] },
      { "matcher": "Bash",       "hooks": [{ "command": ".claude/hooks/gitleaks-scan.sh" }] },
      { "matcher": "Read",       "hooks": [{ "command": ".claude/hooks/block-env-read.sh" }] }
    ],
    "PostToolUse": [...],
    "UserPromptSubmit": [...],
    "Stop": [...]
  }
}
```

The four event types:

| Event | When it fires | Use for |
|---|---|---|
| `PreToolUse` | Before any tool call | Block writes, scan for secrets, inject context |
| `PostToolUse` | After a successful tool call | Cleanup, reminders, audit logging |
| `UserPromptSubmit` | When the user sends a prompt | Inject workflow reminders, recover from crashes |
| `Stop` | Before the model ends its turn | Final QA gates |

## Two superpowers

Every hook does one of two things:

1. **Block (exit 2)** — stops the tool call. The hook's stderr is shown to Claude as an error. Claude reads it and adjusts.
2. **Inform (exit 0 + stderr)** — the tool call proceeds, but Claude is given context. Use for soft warnings.

The model can never bypass a `block`. You don't have to remember the policy — the harness does.

---

## The hooks shipped here

### Workflow enforcement

| Hook | Event | What it does |
|---|---|---|
| `check-worktree.sh` | `PreToolUse:Edit\|Write` | Blocks edits in the main repo — forces feature branches in worktrees |
| `check-cross-worktree.sh` | `PreToolUse:Edit\|Write` | Blocks one session from editing files in another session's worktree |
| `enforce-worktree-path.sh` | `PreToolUse:Bash` | Blocks `git worktree add` unless target is in `<project>-worktrees/` |
| `task-setup-workflow.sh` | `UserPromptSubmit` | When a new task is detected, reminds you to create issue + bead + worktree |
| `post-worktree-cleanup.sh` | `PostToolUse:Bash` | After `git worktree remove`, closes the GH issue and syncs other worktrees |

### Pre-commit / pre-push gates

| Hook | Event | What it does |
|---|---|---|
| `pre-commit-lint.sh` | `PreToolUse:Bash` | Runs lint via `scripts/lint-worktree.sh` before `git commit` — blocks on errors |
| `gitleaks-scan.sh` | `PreToolUse:Bash` | Runs `gitleaks` before `git commit` — blocks if secrets are detected |
| `security-check.sh` | `PreToolUse:Bash` | Pre-commit checks: RLS on migrations, no service-role keys in client code |
| `check-ci-before-pr.sh` | `PreToolUse:Bash` | Blocks `gh pr create` unless a CI/CD verification marker file exists |
| `warn-pr-to-main.sh` | `PreToolUse:Bash` | When opening a PR to `main`/`master`, warns to consider staging branch first |
| `pre-push-review-reminder` | `PreToolUse:Bash` | Before `git push`, reminds to run review agents |

### Read protection

| Hook | Event | What it does |
|---|---|---|
| `block-env-read.sh` | `PreToolUse:Read` | Refuses to read `.env` files (credentials must never enter the model context) |

### Context injection / reminders

| Hook | Event | What it does |
|---|---|---|
| `database-context-injector.sh` | `PreToolUse:Edit\|Write` | When editing schema/migration files, injects `docs/database.md` content as context |
| `database-update-reminder.sh` | `PostToolUse:Edit\|Write` | After editing a migration, reminds to update `docs/database.md` |
| `agent-review-reminder.sh` | `UserPromptSubmit` | When user mentions opening a PR, reminds to run security/code review agents |
| `qa-review-prompt.sh` | `UserPromptSubmit` | When user mentions committing, prompts a QA review of the diff |
| `remind-success-prompt.sh` | `UserPromptSubmit` | When user says "merged" / "looks good", prompts to write a success log |

### Crash recovery

| Hook | Event | What it does |
|---|---|---|
| `wsl-crash-recovery.sh` | `UserPromptSubmit` | On every prompt, detects stale state from crashed sessions and outputs continuation prompts. Also writes the current session's state for future detection. |

---

## Customizing

Every hook is editable. Open the `.sh` file. Read the comment header — each one explains its purpose, exit codes, and any required dependencies (gitleaks, jq, etc.).

To **disable** a hook: remove its entry from `settings.json`. Don't delete the script; you may want it back.

To **add** a hook: write a new `.sh` script in this folder, make it executable (`chmod +x`), then add a `hooks.PreToolUse` entry referencing it.

## Convention notes

Several hooks assume a specific repo layout. If you don't match these conventions, customize the hook OR adopt the convention:

- Worktrees live at `../<project-name>-worktrees/<branch-name>/`
- Branches use the pattern `feature/GH-###-description` where `GH-###` is a GitHub issue number
- Lint is run via `scripts/lint-worktree.sh` from the repo root
- A CI/CD verification script writes `/tmp/<project-name>-ci-verified-<SHA>` on success

These are coupled with [hookify rules](../hookify-rules/) for things like blocking pushes to `main`.

## Debugging

If a hook isn't firing, check:

1. The script is in `~/.claude/hooks/` (or your project's `.claude/hooks/`) and `chmod +x`
2. The matcher in `settings.json` matches the tool name (`Edit`, `Bash`, etc., case-sensitive)
3. The script's exit code is what you expect — `set -x` at the top to see traces
4. Hook stderr lands in your Claude conversation, so any logged errors will show up there

Hooks log to stderr. The model sees stderr. If a hook is throwing a stack trace mid-conversation, fix it.
