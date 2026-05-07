# macOS + tmux + iTerm2 Multi-Session Setup

A portable runbook for setting up a Mac with tmux, iTerm2, and an iTerm2 Dynamic Profiles config that exposes 15 named, tmux-backed sessions as separate iTerm2 profiles. Mirror of [`wsl-tmux-terminal-setup.md`](wsl-tmux-terminal-setup.md), adapted for macOS. All paths are user-agnostic so the same config works on any Mac.

---

## Goal

By the end of this runbook the machine will have:

- Homebrew installed
- tmux installed via brew
- The toolkit's `scripts/claude-session.sh` available as a launcher that creates, attaches to, or switches to a named tmux session — even when invoked from inside an existing tmux session
- An iTerm2 Dynamic Profiles file with 15 profiles (`Session - Main` plus `Session 2` through `Session 15`), each launching its own tmux session via the launcher
- No hardcoded usernames, repo paths, or machine-specific references

> **One difference from the WSL doc:** the launcher used here (`claude-session.sh`) is project-aware — it prefixes session names with the first 8 chars of the current git repo (so `safegamer-main`, not `main`) and auto-runs `claude --dangerously-skip-permissions` on attach. If you'd rather have a minimal "drop into bash inside a named tmux session" launcher like the WSL doc's `wsl-session.sh`, copy that block (Step 5 of the WSL doc) verbatim into `~/scripts/wsl-session.sh` — the chmod and tmux behavior are platform-agnostic — and substitute it in Step 7 below.

---

## Prerequisites

- macOS 13 (Ventura) or newer — earlier should work but is untested
- Admin access (for Homebrew install)
- Internet connectivity
- Xcode Command Line Tools (`xcode-select --install` if not already installed)

---

## Step 1 — Install Homebrew

If brew is not already on the machine:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the post-install instructions to add brew to your shell profile (the installer prints the exact line for your shell). Verify:

```bash
brew --version
```

---

## Step 2 — Install tmux

```bash
brew install tmux
tmux -V
```

Confirm a version line prints (e.g. `tmux 3.5a`). The `tmux ls` "no server running" message is normal when no sessions are running.

---

## Step 3 — Drop in `~/.tmux.conf`

This is the same baseline as the WSL doc with two macOS adaptations: `pbcopy` instead of `clip.exe` for the clipboard hook, and the optional notification path uses `terminal-notifier` (covered in Step 9).

```bash
cat > ~/.tmux.conf <<'EOF'
# ---- General -----------------------------------------------------------------
set -g history-limit 50000
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
set -sg escape-time 10
set -g focus-events on

# ---- Reload config quickly ---------------------------------------------------
bind r source-file ~/.tmux.conf \; display "tmux.conf reloaded"

# ---- Pane navigation (vim-style hjkl) ----------------------------------------
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# ---- Pane resizing (repeatable) ----------------------------------------------
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# ---- Splits keep CWD ---------------------------------------------------------
bind '"' split-window -v -c "#{pane_current_path}"
bind %   split-window -h -c "#{pane_current_path}"
bind c   new-window      -c "#{pane_current_path}"

# ---- Quick session switcher --------------------------------------------------
bind S detach-client -a

# ---- Sync panes --------------------------------------------------------------
bind y setw synchronize-panes \; display "sync: #{?pane_synchronized,ON,OFF}"

# ---- Copy mode: Vim-like, copy to macOS clipboard via pbcopy -----------------
setw -g mode-keys vi
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"

# ---- Status bar --------------------------------------------------------------
set -g status-interval 5
set -g status-position bottom
set -g status-style "bg=#0f1626,fg=#e6edf3"
set -g status-left-length 40
set -g status-left "#[fg=#22d3ee,bold] #S #[fg=#7d8590]│ "
set -g status-right-length 100
set -g status-right "#[fg=#a3e635]#(~/scripts/tmux-claude-tokens.sh 2>/dev/null) #[fg=#7d8590]│ #[fg=#67e8f9]#{session_windows}w #[fg=#7d8590]│ #[fg=#f59e0b]#{cpu_percentage} #[fg=#7d8590]│ #[fg=#a3e635]#{online_status} #[fg=#7d8590]│ #[fg=#e6edf3]%H:%M "
set -g window-status-current-style "bg=#22d3ee,fg=#06070d,bold"
set -g window-status-style "bg=default,fg=#7d8590"
set -g window-status-format " #I:#W "
set -g window-status-current-format " #I:#W "

# ---- Pane borders ------------------------------------------------------------
set -g pane-border-style "fg=#1a2236"
set -g pane-active-border-style "fg=#22d3ee"

# ---- Plugins (managed by TPM — see Step 9) -----------------------------------
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-prefix-highlight'
set -g @plugin 'tmux-plugins/tmux-pain-control'
set -g @plugin 'tmux-plugins/tmux-cpu'
set -g @plugin 'tmux-plugins/tmux-online-status'
set -g @plugin 'tmux-plugins/tmux-logging'
set -g @plugin 'omerxx/tmux-sessionx'
set -g @plugin 'rickstaa/tmux-notify'
set -g @plugin 'laktak/extrakto'
set -g @plugin 'roosta/tmux-fuzzback'
set -g @plugin 'b0o/tmux-autoreload'
set -g @plugin 'accessd/tmux-agent-indicator'

set -g @resurrect-capture-pane-contents 'on'
set -g @resurrect-strategy-vim 'session'
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'

set -g @prefix_highlight_show_copy_mode 'on'
set -g @prefix_highlight_show_sync_mode 'on'

set -g @sessionx-bind 'o'
set -g @sessionx-window-mode 'on'
set -g @sessionx-preview-enabled 'true'
set -g @sessionx-preview-location 'right'
set -g @sessionx-preview-ratio '60%'

set -g @tnotify-verbose 'on'
set -g @tnotify-sleep-duration '0'

set -g @extrakto_split_direction 'p'
set -g @extrakto_grab_area 'window full'

run '~/.tmux/plugins/tpm/tpm'
EOF
```

Reload with `tmux source-file ~/.tmux.conf` if a session is already running. The plugin lines do nothing yet — Step 9 installs TPM and runs them.

---

## Step 4 — Install Claude Code

```bash
# Node.js (via nvm — recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.zshrc   # or ~/.bash_profile if using bash
nvm install --lts
nvm use --lts

# Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Authenticate
claude auth login
```

Verify:

```bash
claude --version    # should print 2.x.x
node --version      # should print v20+ or v22+
```

For the rest of the toolchain (oxlint, gh CLI, gitleaks, jq, beads), see [Required Tools (macOS)](../README.md#required-tools-macos) in the main README.

---

## Step 5 — Get the session launcher

The toolkit's `scripts/claude-session.sh` is the launcher. After running `install.sh` from this repo (or copying the file manually), it lives at `<your-project>/scripts/claude-session.sh`.

If you want a single global launcher path that the iTerm2 profiles can share across projects, symlink one copy to `~/scripts/`:

```bash
mkdir -p ~/scripts
ln -sf "$HOME/repos/claude-dev-toolkit/scripts/claude-session.sh" ~/scripts/claude-session.sh
```

> **Behavior to know about** (different from the WSL doc's `wsl-session.sh`):
>
> - Session names get prefixed with the first 8 chars of the current git repo name. From inside `~/repos/safegamer-ai`, calling `claude-session.sh main` creates a tmux session named `safegamer-main`, not `main`. Different repos = different "main" sessions.
> - Each session auto-runs `claude --dangerously-skip-permissions` on attach. Detach with `Ctrl-b d`.
> - Falls back to `pwd` as the project name when run outside a git repo.
> - Special-cases names matching `GH-NNN-*` to switch into the matching worktree directory under `<repo>-worktrees/`.

If you'd prefer the WSL doc's minimal "drop into bash" behavior on Mac, write the simpler launcher from [Step 5 of the WSL doc](wsl-tmux-terminal-setup.md#step-5--create-the-session-launcher-script) to `~/scripts/wsl-session.sh` and substitute that path in Step 7.

### Smoke test

From any shell:

```bash
~/scripts/claude-session.sh smoketest
```

You should land inside a tmux session that auto-launches Claude. Detach with `Ctrl-b d`. Verify:

```bash
tmux ls
```

A session ending in `-smoketest` should be listed. Kill it with `tmux kill-session -t <name>`.

---

## Step 6 — Install iTerm2

```bash
brew install --cask iterm2
```

Open iTerm2 at least once before continuing so its support directories exist.

---

## Step 7 — Write the iTerm2 Dynamic Profiles JSON

iTerm2 watches `~/Library/Application Support/iTerm2/DynamicProfiles/` and hot-reloads any JSON files dropped in. We'll write one file with the 15 session profiles.

The 15 GUIDs below are pre-generated and unique. You can reuse them as-is — iTerm2 only requires GUIDs to be unique within the file.

```bash
mkdir -p "$HOME/Library/Application Support/iTerm2/DynamicProfiles"
cat > "$HOME/Library/Application Support/iTerm2/DynamicProfiles/sessions.json" <<'EOF'
{
  "Profiles": [
    { "Name": "Session - Main", "Guid": "348a23ad-7870-5c8c-a5c1-89e6bbfb671d", "Custom Command": "Custom Shell", "Command": "/bin/bash -lc \"$HOME/scripts/claude-session.sh main\"",  "Custom Directory": "Yes", "Working Directory": "$HOME", "Scrollback Lines": 20000 },
    { "Name": "Session 2",     "Guid": "4156128d-b861-51d1-b493-73a93d168de0", "Custom Command": "Custom Shell", "Command": "/bin/bash -lc \"$HOME/scripts/claude-session.sh 2\"",     "Custom Directory": "Yes", "Working Directory": "$HOME", "Scrollback Lines": 20000 },
    { "Name": "Session 3",     "Guid": "f5be208d-df16-5ba5-b253-3d0fc80c9849", "Custom Command": "Custom Shell", "Command": "/bin/bash -lc \"$HOME/scripts/claude-session.sh 3\"",     "Custom Directory": "Yes", "Working Directory": "$HOME", "Scrollback Lines": 20000 },
    { "Name": "Session 4",     "Guid": "3ed80b05-3fdd-5de7-aabd-a954271b1c08", "Custom Command": "Custom Shell", "Command": "/bin/bash -lc \"$HOME/scripts/claude-session.sh 4\"",     "Custom Directory": "Yes", "Working Directory": "$HOME", "Scrollback Lines": 20000 },
    { "Name": "Session 5",     "Guid": "9559b951-448d-5df4-9b49-9ec868bae76c", "Custom Command": "Custom Shell", "Command": "/bin/bash -lc \"$HOME/scripts/claude-session.sh 5\"",     "Custom Directory": "Yes", "Working Directory": "$HOME", "Scrollback Lines": 20000 },
    { "Name": "Session 6",     "Guid": "8617f12e-2f2a-5abe-bc7d-eeb0c3ca74fd", "Custom Command": "Custom Shell", "Command": "/bin/bash -lc \"$HOME/scripts/claude-session.sh 6\"",     "Custom Directory": "Yes", "Working Directory": "$HOME", "Scrollback Lines": 20000 },
    { "Name": "Session 7",     "Guid": "9345069f-2f45-5dbe-9df3-77bbd142bdc0", "Custom Command": "Custom Shell", "Command": "/bin/bash -lc \"$HOME/scripts/claude-session.sh 7\"",     "Custom Directory": "Yes", "Working Directory": "$HOME", "Scrollback Lines": 20000 },
    { "Name": "Session 8",     "Guid": "e671e4c0-a27e-44ac-bb6f-f182656d610d", "Custom Command": "Custom Shell", "Command": "/bin/bash -lc \"$HOME/scripts/claude-session.sh 8\"",     "Custom Directory": "Yes", "Working Directory": "$HOME", "Scrollback Lines": 20000 },
    { "Name": "Session 9",     "Guid": "c661adca-c220-4ec4-9d75-bf86fc1235c7", "Custom Command": "Custom Shell", "Command": "/bin/bash -lc \"$HOME/scripts/claude-session.sh 9\"",     "Custom Directory": "Yes", "Working Directory": "$HOME", "Scrollback Lines": 20000 },
    { "Name": "Session 10",    "Guid": "7437b7a8-89b8-495a-a986-97da5d261c12", "Custom Command": "Custom Shell", "Command": "/bin/bash -lc \"$HOME/scripts/claude-session.sh 10\"",    "Custom Directory": "Yes", "Working Directory": "$HOME", "Scrollback Lines": 20000 },
    { "Name": "Session 11",    "Guid": "5f6552b9-58f6-4bc8-b68b-2870f305f1fe", "Custom Command": "Custom Shell", "Command": "/bin/bash -lc \"$HOME/scripts/claude-session.sh 11\"",    "Custom Directory": "Yes", "Working Directory": "$HOME", "Scrollback Lines": 20000 },
    { "Name": "Session 12",    "Guid": "9650cb8a-5859-435a-a128-da8be0843fa4", "Custom Command": "Custom Shell", "Command": "/bin/bash -lc \"$HOME/scripts/claude-session.sh 12\"",    "Custom Directory": "Yes", "Working Directory": "$HOME", "Scrollback Lines": 20000 },
    { "Name": "Session 13",    "Guid": "b9786de8-b5d7-40cc-bd39-b9d1c06c54ec", "Custom Command": "Custom Shell", "Command": "/bin/bash -lc \"$HOME/scripts/claude-session.sh 13\"",    "Custom Directory": "Yes", "Working Directory": "$HOME", "Scrollback Lines": 20000 },
    { "Name": "Session 14",    "Guid": "582cfc9e-9bd0-4873-a52b-2122d0c99b09", "Custom Command": "Custom Shell", "Command": "/bin/bash -lc \"$HOME/scripts/claude-session.sh 14\"",    "Custom Directory": "Yes", "Working Directory": "$HOME", "Scrollback Lines": 20000 },
    { "Name": "Session 15",    "Guid": "1da6c0b1-e28e-4f78-8f1e-c089378ac36a", "Custom Command": "Custom Shell", "Command": "/bin/bash -lc \"$HOME/scripts/claude-session.sh 15\"",    "Custom Directory": "Yes", "Working Directory": "$HOME", "Scrollback Lines": 20000 }
  ]
}
EOF
```

Save the file. iTerm2 hot-reloads — the new profiles appear under **Profiles → Open Profile…** (or `⌘O`) immediately.

### Notes on the JSON

- iTerm2's JSON keys are not the same as Windows Terminal's. `Custom Command` set to `"Custom Shell"` plus a `Command` value tells iTerm2 to run that command directly instead of the default login shell.
- `bash -lc` (with `-l`) starts a login shell so `~/.zprofile`, `~/.profile`, and nvm/pyenv shims load. `\"$HOME/...\"` lets `$HOME` expand inside the login shell.
- `Working Directory` is set to `$HOME` so each profile starts there. `claude-session.sh` itself will `cd` into the right repo/worktree based on the session name.

### If you want fresh GUIDs instead

```bash
for i in {1..15}; do uuidgen; done
```

Replace each profile's `Guid` value with one of the outputs.

---

## Step 8 — Verify

Open iTerm2, hit `⌘O` to open the profile picker, and confirm the 15 session profiles are listed. Open `Session - Main`. You should land inside a tmux session (named `<project-prefix>-main`) with Claude already starting.

Detach with `Ctrl-b d`. From any shell:

```bash
tmux ls
```

Should list the session. Open a new `Session - Main` tab — it attaches to the same session, including any running processes. This is the property that makes long-running work survive accidental tab closes.

---

## Why this design

- `bash -lc "$HOME/..."` with a `$HOME`-relative path means no per-machine edits; the `-l` flag picks up shell profile additions (nvm, pyenv, brew shellenv, etc.).
- The `claude-session.sh` script's `tmux has-session` / `tmux new-session` / `tmux attach-session` flow is the macOS equivalent of the WSL doc's "attach or create" idempotence.
- Profile names are intentionally generic so the Dynamic Profiles file is sharable across machines without revealing project context. (The session names themselves get repo-prefixed at runtime, which is what you want.)

---

## Step 9 — Tmux accessories

Same plugins as the WSL doc — only the prerequisite installer changes.

### 9a — Install Tmux Plugin Manager (TPM)

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Inside any tmux session, press `prefix + I` (capital i) to fetch and install the plugins listed in your `.tmux.conf`.

The plugin table from the WSL doc applies verbatim — see [WSL doc Step 9a](wsl-tmux-terminal-setup.md#9a--install-tmux-plugin-manager-tpm) for what each plugin does.

Plugin prerequisites on macOS:

```bash
brew install fzf entr bc
# fzf:  required by tmux-sessionx, extrakto, fuzzback
# entr: required by tmux-autoreload
# bc:   used by the token-counter script

# Optional: native macOS notifications for tmux-notify
# (without this, notifications fall back to terminal bell + status flash)
brew install terminal-notifier
```

### 9b — Token usage per session

Same script as the WSL doc — copy the heredoc from [WSL doc Step 9b](wsl-tmux-terminal-setup.md#9b--token-usage-per-session-the-killer-feature) into `~/scripts/tmux-claude-tokens.sh` and `chmod +x` it. The script is platform-agnostic (it reads `~/.claude/projects/*.jsonl` regardless of OS).

### 9c — Per-session starting directory

`claude-session.sh` already handles this for `GH-NNN-*` names (it `cd`s into the matching worktree). For other names, you can either modify your local copy of the script or rely on each session's first command being a manual `cd`.

### 9d — Per-pane logging

Same as WSL — `tmux-logging` plugin, `prefix + alt+p` to toggle.

### 9e — Custom iTerm2 colors / icons / fonts

The Dynamic Profiles JSON accepts the same keys as iTerm2's main profile config. Common additions per profile:

```json
"Background Color":             { "Red Component": 0.06, "Green Component": 0.07, "Blue Component": 0.1, "Alpha Component": 1, "Color Space": "sRGB" },
"Normal Font":                  "JetBrainsMonoNL-Regular 14",
"Use Non-ASCII Font":           false,
"Badge Text":                   "Session 3"
```

Drop these inside any profile object. iTerm2 hot-reloads on save.

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `sessions should be nested with care, unset $TMUX to force` | Older launcher. The `claude-session.sh` shipped with this toolkit handles this case via `tmux has-session` / `attach-session`. Re-pull from the toolkit. |
| Profile opens then closes immediately | Script not executable, or path wrong. `chmod +x ~/scripts/claude-session.sh` and confirm `ls -l ~/scripts/claude-session.sh` resolves. |
| `claude-session.sh: command not found` | The symlink in `~/scripts/` is missing. Re-run the `ln -sf` command in Step 5, or update the JSON `Command` to point at the toolkit copy directly. |
| `tmux: command not found` | `brew install tmux`. |
| Sessions do not persist between tab closes | Profile is bypassing the launcher. Reopen the profile and run `tmux ls` after detaching to confirm the named session exists. |
| iTerm2 does not show the new profiles | Wrong directory. Confirm the file is at `~/Library/Application Support/iTerm2/DynamicProfiles/sessions.json` (note the spaces in the path). Check **iTerm2 → Settings → General → Preferences → Load preferences from a custom folder** is OFF, or that the custom folder also contains the DynamicProfiles dir. |
| `JSON parse error` in iTerm2 logs | Validate with `python3 -m json.tool < ~/Library/Application\ Support/iTerm2/DynamicProfiles/sessions.json`. |
| Claude doesn't auto-launch on attach | Expected if you swapped in the minimal `wsl-session.sh` from the WSL doc instead of using `claude-session.sh`. |
