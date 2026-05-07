# Hookify Rules

**Declarative pattern-matching rules** that fire on Claude Code events. Markdown files with YAML frontmatter — no shell scripts to write. Good for "if Claude tries to do X, block it / warn about it" type policies.

> **Hookify vs. shell hooks:** [shell hooks](../hooks/) are scripts that run arbitrary code. Hookify rules are declarative — you describe the trigger and action in YAML. Use hookify when a regex check is enough; use a shell hook when you need real logic.

## File naming

Each rule lives in its own file: `hookify.<name>.local.md`

The `.local.md` suffix marks them as project-local rules (not shared upstream).

## Anatomy of a rule

```yaml
---
name: block-direct-main-dev          # unique identifier
enabled: true                        # quick toggle
priority: 100                        # higher = evaluated first
event: bash                          # which Claude Code event to hook
pattern: 'git\s+push.*\s+main\b'     # regex matched against the event payload
action: block                        # block | warn | inform
message: |
  Direct pushes to main are blocked.
  Open a PR instead.
---

(optional explanatory markdown body)
```

### Fields

| Field | Required | Notes |
|---|---|---|
| `name` | yes | unique identifier for the rule |
| `enabled` | yes | `true` / `false` — toggle without deleting the file |
| `event` | yes | `bash`, `edit`, `write`, `read`, `file`, or array `[edit, write]` |
| `action` | yes | `block` (exit 2 — model sees error and pivots), `warn` (allow, log a warning), `inform` (allow, inject a note) |
| `pattern` | one of | regex matched against the bash command string |
| `conditions` | one of | structured matchers — `field` + `operator` + `value` (e.g. `file_path` + `regex_match`) |
| `priority` | no | higher number = evaluated first; useful when multiple rules match |
| `message` | no | text shown to Claude when the rule fires (markdown OK) |

---

## The rules shipped here

### Hard blocks (cannot proceed)

| Rule | Triggers when... | Why |
|---|---|---|
| `block-direct-main-dev` | `git push` or `git commit` to `main`/`dev`, or `git checkout main` | Forces feature branches and PRs — no direct work on protected branches |
| `block-credentials-in-client` | Edit/write a client-side file containing service-role keys | Service-role keys must never be in client code; they grant full DB access |
| `block-cross-worktree` | Edit/write a file in a worktree other than the current one | Prevents one Claude session from clobbering work in another |
| `block-env-modification` | Edit/write to a `.env*` file | `.env` files contain secrets — must be edited by humans |
| `block-hook-bypass` | `git --no-verify` or `git -c core.hooksPath=...` | Catches attempts to skip pre-commit hooks |
| `block-push-without-lint` | `git push origin feature/...` without lint having run on the current commit | Forces lint to pass before push |

### Warnings (allow, but flag)

| Rule | Triggers when... | Why |
|---|---|---|
| `warn-console-log` | New `console.log` added in `src/` | Likely a leftover debug; remove or escalate to a logger |
| `warn-eslint-disable` | New `eslint-disable` comment added | Sometimes legitimate, often used to silence real issues — flag for review |
| `warn-pr-lint` | `gh pr create` without recent lint run | Confirms lint passed before PR opens |
| `warn-rls-missing` | Migration creates a table without `ENABLE ROW LEVEL SECURITY` | Tables without RLS are wide open — almost always a mistake on Supabase |
| `warn-security-definer` | Migration uses `SECURITY DEFINER` on a function | Powerful escalation — flag for security review |
| `warn-view-missing-security-invoker` | Migration creates a `VIEW` without `WITH (security_invoker=true)` | Views default to security-definer — almost always not what you want |
| `warn-migration-undocumented` | Migration file added without copyright/header comment | Forces consistent migration documentation |
| `warn-migration-duplicate-fields` | Migration adds a column that already exists | Catches schema duplication |
| `warn-migration-orphaned-tables` | Migration creates a table not referenced anywhere in code | Catches tables that won't be used (often a planning mistake) |

---

## How they get loaded

Hookify rules are loaded by a small interpreter that's wired into your `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash|Edit|Write|Read",
        "hooks": [{ "command": ".claude/hookify-loader.sh" }] }
    ]
  }
}
```

The loader script reads every `hookify-rules/hookify.*.local.md` file, parses the YAML, and applies the matching rules to the current tool call. Each rule that matches gets its action executed.

(If the loader script isn't shipped here yet, you can swap it for a shell hook with the same logic, or use the included declarative rules as documentation while you write the actual scripts.)

## Customizing

To **disable** a rule: change `enabled: true` to `enabled: false` in the frontmatter. Don't delete the file — you may want it back.

To **add** a rule: copy an existing one as a template, edit the frontmatter for your trigger and action, write a clear `message:` body. The filename should match the `name:` field.

To **debug** a rule: bump its `priority` to a high number (e.g. 1000) so it's evaluated first, then check the message you wrote. Hookify rule messages land in your Claude conversation as tool errors when `action: block`.

## Convention notes

The rules here assume:

- Worktrees live at `../<project>-worktrees/<branch-name>/`
- Migrations live in `<your-app-path>/migrations/` (Supabase or Postgres convention)
- Service-role keys are in environment variables prefixed with `SUPABASE_SERVICE_*` or `*_SERVICE_ROLE_KEY`

If your stack differs, edit the patterns to match.
