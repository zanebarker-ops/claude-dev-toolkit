# AGENTS.md — Install Instructions for AI Models

This file is written for AI coding assistants (Claude Code, Cursor, etc.) to read
and execute the full installation of the Claude Dev Toolkit on behalf of a user.

Follow the steps below in order. Do not skip, reorder, or substitute commands
unless the user explicitly tells you to.

---

## 0. Confirm intent and collect one value from the user

Before running anything, confirm with the user:

1. The **absolute path** to the target project they want the toolkit installed
   into (e.g. `/home/alice/repos/my-app`). Call this `$TARGET`.
2. Whether their git base branch is `dev` (default) or something else
   (e.g. `main`). Call this `$BASE_BRANCH`.

If the user has not provided these, ask for them before proceeding. Do not
guess. Do not install into the current working directory unless the user
explicitly confirms that is the target.

---

## 1. Check prerequisites

Run each of these and report any that are missing. Do NOT attempt to install
system packages (`apt`, `brew`, etc.) on the user's machine without explicit
permission — just report what's missing and let the user decide.

```bash
command -v git      # required
command -v node     # required
command -v npm      # required
command -v claude   # required (Claude Code CLI)
command -v gh       # required (GitHub CLI)
command -v oxlint   # required (linter used by hooks)
command -v tmux     # recommended (crash-proof sessions)
command -v jq       # recommended (crash recovery)
command -v gitleaks # optional (secret scanning)
```

If `claude`, `oxlint`, or `gh` are missing, stop and tell the user. These are
installed via:

- `npm install -g @anthropic-ai/claude-code`
- `npm install -g oxlint`
- `sudo apt install gh` (Debian/Ubuntu) or https://cli.github.com

---

## 2. Clone the toolkit

Clone into the user's home directory. If `~/claude-dev-toolkit` already exists,
pull instead of re-cloning.

```bash
if [ -d "$HOME/claude-dev-toolkit/.git" ]; then
  git -C "$HOME/claude-dev-toolkit" pull --ff-only
else
  git clone https://github.com/zanebarker-ops/claude-dev-toolkit.git "$HOME/claude-dev-toolkit"
fi
```

Use HTTPS (shown above) unless the user has told you SSH is configured, in
which case you may use `git@github.com:zanebarker-ops/claude-dev-toolkit.git`.

---

## 3. Verify the target project exists

```bash
test -d "$TARGET" || { echo "Target not found: $TARGET"; exit 1; }
test -d "$TARGET/.git" || echo "Warning: $TARGET is not a git repo"
```

If `$TARGET` is not a git repo, stop and confirm with the user before
continuing. The toolkit is designed for git-tracked projects.

---

## 4. Run the installer

```bash
"$HOME/claude-dev-toolkit/install.sh" "$TARGET"
```

The installer is idempotent — existing `settings.json`, `.oxlintrc.json`,
`CLAUDE.md`, and hookify rules are skipped, not overwritten. Read the
installer's output. If it reports any `✗` errors, stop and surface them to
the user.

The installer creates:

- `$TARGET/.claude/hooks/` — 18 workflow hooks
- `$TARGET/.claude/commands/` — 26 agent command prompts
- `$TARGET/.claude/plugins/pr-review-toolkit/` — PR review agents
- `$TARGET/.claude/templates/` — reference docs
- `$TARGET/.claude/coordination/` — multi-agent coordination state
- `$TARGET/.claude/settings.json` — hook registrations (if absent)
- `$TARGET/.oxlintrc.json` — lint config (if absent)
- `$TARGET/scripts/` — `lint-changed.sh`, `check-deploy.sh`,
  `claude-session.sh`, `migrate-to-ext4.sh`
- `$TARGET/CLAUDE.md` — starter project instructions (if absent)

---

## 5. Post-install customization

Do these in order. Ask the user before making any edit that requires a
decision — do not invent product names, branch names, or business context.

### 5a. Personalize `CLAUDE.md`

`$TARGET/CLAUDE.md` was generated from a template. It contains placeholders
that need the user's input. Open the file, list the placeholders you find
(e.g. product description, tech stack, conventions), and ask the user to
provide values. Then edit the file with their answers.

### 5b. Replace `[YOUR_PRODUCT]` in agent commands

Ask the user for their product name. Then:

```bash
cd "$TARGET/.claude/commands"
grep -rl '\[YOUR_PRODUCT\]' . | xargs sed -i "s/\[YOUR_PRODUCT\]/<product-name>/g"
```

Substitute `<product-name>` with the value the user provided. Do not guess.

### 5c. Configure the base branch (if not `dev`)

If `$BASE_BRANCH` is not `dev`, set it as an env var in the user's shell rc:

```bash
# Detect shell rc
RC="$HOME/.bashrc"
[ -n "${ZSH_VERSION:-}" ] && RC="$HOME/.zshrc"

echo "export LINT_BASE_BRANCH=$BASE_BRANCH" >> "$RC"
```

Also scan hooks for hardcoded `dev` references and report them to the user
(do not auto-edit — some references are intentional):

```bash
grep -l 'dev' "$TARGET/.claude/hooks/"*.sh
```

### 5d. Review `.claude/settings.json`

Open `$TARGET/.claude/settings.json` and confirm the hook registrations
match what the user expects. If the user had a pre-existing
`settings.json`, the installer skipped it — in that case, show the user
the template at `$TARGET/.claude/templates/settings.json.template` and
ask whether they want to merge hook entries in.

---

## 6. Verify the install

Run these from `$TARGET` and report the results:

```bash
cd "$TARGET"
ls .claude/hooks/ | wc -l           # expect ~18
ls .claude/commands/*.md | wc -l    # expect ~26
test -f .claude/settings.json && echo "settings: ok"
test -f .oxlintrc.json && echo "oxlint: ok"
test -f CLAUDE.md && echo "CLAUDE.md: ok"
test -x scripts/lint-changed.sh && echo "scripts: ok"
```

If any check fails, surface the failure to the user with the exact output.

---

## 7. Report back to the user

Give a concise summary:

- Files installed (counts from step 6)
- Any prerequisites still missing (from step 1)
- Any placeholders still unfilled (e.g. if the user didn't provide a
  product name)
- The next manual step: `./scripts/claude-session.sh` to start a
  crash-proof Claude session

---

## Hard rules for AI agents

- **Never** run `rm -rf` on the target project or anything under `$HOME`
  as part of this install.
- **Never** overwrite an existing `CLAUDE.md`, `.claude/settings.json`,
  or `.oxlintrc.json`. The installer already protects these — do not
  work around it.
- **Never** commit or push changes in `$TARGET` as part of the install.
  Leave that to the user.
- **Never** run `sudo` commands. If a prerequisite requires `sudo`,
  report it and stop.
- **Never** modify the user's `~/.ssh/`, git global config, or shell rc
  beyond the single `LINT_BASE_BRANCH` export in step 5c.
- If the user's project is on `/mnt/c/` (WSL Windows drive), warn them —
  the toolkit is much slower there. See the README section "Why WSL
  ext4?" for the migration path, but do not migrate without explicit
  permission.
