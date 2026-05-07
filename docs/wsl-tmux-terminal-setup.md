# WSL + tmux + Windows Terminal Multi-Session Setup

A portable runbook for setting up a Windows machine with WSL (Ubuntu), tmux, and a Windows Terminal config that exposes 15 named, tmux-backed sessions as separate terminal profiles. All paths are user-agnostic so the same config works on any machine.

---

## Goal

By the end of this runbook the machine will have:

- WSL 2 with Ubuntu installed
- tmux installed inside Ubuntu
- A reusable launcher script at `~/scripts/wsl-session.sh` that creates, attaches to, or switches to a named tmux session — even when invoked from inside an existing tmux session
- A Windows Terminal `settings.json` with 15 profiles (`Session - Main` plus `Session 2` through `Session 15`), each launching its own tmux session via the launcher script
- No hardcoded usernames, repo paths, or machine-specific references

---

## Prerequisites

- Windows 10 22H2 or Windows 11
- Administrator access on the Windows machine
- Internet connectivity
- Windows Terminal (ships with Windows 11; on Windows 10 install via `winget install Microsoft.WindowsTerminal` or from the Microsoft Store)

---

## Step 1 — Install WSL with Ubuntu

Open **PowerShell as Administrator** and run:

```powershell
wsl --install -d Ubuntu
```

Reboot when prompted. After reboot, Ubuntu opens automatically and asks for a UNIX username and password. Pick whatever you want — the rest of this runbook does not depend on the username.

Verify the install:

```powershell
wsl -l -v
```

Expected output shows `Ubuntu` as the distro at `VERSION  2`. If the version shows `1`, run `wsl --set-version Ubuntu 2`.

If `Ubuntu` is not the distro name on your machine (for example `Ubuntu-24.04`), note the exact name — you will substitute it in Step 7.

---

## Step 2 — Update Ubuntu

Inside the Ubuntu shell:

```bash
sudo apt update && sudo apt upgrade -y
```

---

## Step 3 — Install tmux

```bash
sudo apt install -y tmux
tmux -V
```

Confirm a version line prints (e.g. `tmux 3.4`). The `tmux ls` "no such file or directory" message is normal when no sessions are running.

Drop in a sensible baseline `~/.tmux.conf`. This covers mouse scroll, sane numbering, vim-style pane navigation, a status bar with session info + clock, and a hook for the optional token-usage indicator (described below).

```bash
cat > ~/.tmux.conf <<'EOF'
# ---- General -----------------------------------------------------------------
set -g history-limit 50000              # 50k lines of scrollback per pane
set -g mouse on                         # mouse scroll, click panes/windows, resize
set -g base-index 1                     # windows start at 1, not 0
setw -g pane-base-index 1               # panes too
set -g renumber-windows on              # close window 2, window 3 becomes 2
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",xterm-256color:Tc"   # truecolor in modern terminals
set -sg escape-time 10                  # makes vim feel responsive in tmux
set -g focus-events on                  # vim auto-reload, etc.

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

# ---- Quick session switcher (prefix + s gives a list) ------------------------
# Built in: prefix + s
# Add: prefix + S to detach all OTHER clients on this session (kicks idle tabs)
bind S detach-client -a

# ---- Sync panes (run same command in every pane of current window) -----------
bind y setw synchronize-panes \; display "sync: #{?pane_synchronized,ON,OFF}"

# ---- Copy mode: Vim-like, copy to system clipboard via win32yank/clip.exe ----
setw -g mode-keys vi
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "clip.exe"
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "clip.exe"

# ---- Status bar --------------------------------------------------------------
set -g status-interval 5
set -g status-position bottom
set -g status-style "bg=#0f1626,fg=#e6edf3"
set -g status-left-length 40
set -g status-left "#[fg=#22d3ee,bold] #S #[fg=#7d8590]│ "
set -g status-right-length 100
# status-right shows: <claude tokens> | <window count> | <hostname> | <time>
# The tokens script is wired up in Step 9 (Tmux accessories).
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

# Resurrect: persist sessions across reboots
set -g @resurrect-capture-pane-contents 'on'
set -g @resurrect-strategy-vim 'session'

# Continuum: auto-save every 15 min, auto-restore on tmux start
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'

# Prefix highlight (visible cue when prefix is active)
set -g @prefix_highlight_show_copy_mode 'on'
set -g @prefix_highlight_show_sync_mode 'on'

# Sessionx: fzf-powered session picker with live previews (prefix+o)
set -g @sessionx-bind 'o'
set -g @sessionx-window-mode 'on'
set -g @sessionx-preview-enabled 'true'
set -g @sessionx-preview-location 'right'
set -g @sessionx-preview-ratio '60%'

# Notify: toast when a flagged command finishes (prefix+m to flag)
set -g @tnotify-verbose 'on'
set -g @tnotify-sleep-duration '0'

# Extrakto: fzf-pick paths/URLs/SHAs from pane buffer (prefix+tab)
set -g @extrakto_split_direction 'p'
set -g @extrakto_grab_area 'window full'

# Initialize TPM (must be the LAST line)
run '~/.tmux/plugins/tpm/tpm'
EOF
```

Reload with `tmux source-file ~/.tmux.conf` if a session is already running. The plugin lines do nothing yet — Step 9 installs TPM and runs them.

---

## Step 4 — Install Claude Code

The whole point of this setup is to run Claude Code inside each tmux-backed session, so install the CLI now.

```bash
# Node.js (via nvm — recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc
nvm install --lts
nvm use --lts

# Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Authenticate
claude auth login
# Follow the prompts to log in with your Anthropic account
```

Verify:

```bash
claude --version    # should print 2.x.x
node --version      # should print v20+ or v22+
```

For the rest of the toolchain (oxlint, gh CLI, gitleaks, jq, beads), see [Required Tools (Linux / WSL)](../README.md#required-tools-linux--wsl) in the main README.

> **Why install Claude before the launcher?** Each tmux session in the next steps will typically run a Claude session. Installing the CLI first means you can drop directly into Claude inside any session without leaving to install it later.

---

## Step 5 — Create the session launcher script

Inside the Ubuntu shell:

```bash
mkdir -p "$HOME/scripts"
cat > "$HOME/scripts/wsl-session.sh" <<'EOF'
#!/usr/bin/env bash
# wsl-session.sh
# Launch, attach, or switch to a named tmux session.
# Usage: wsl-session.sh <session-name>
# Example: wsl-session.sh main

set -euo pipefail

SESSION_NAME="${1:-main}"
cd "$HOME"

if [ -n "${TMUX:-}" ]; then
    # Already inside tmux - create the session if missing, then switch to it.
    # This avoids the "sessions should be nested with care" error that
    # tmux raises when you try to start a new session from inside one.
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        tmux new-session -d -s "$SESSION_NAME"
    fi
    exec tmux switch-client -t "$SESSION_NAME"
else
    # Not inside tmux - attach if a session with this name exists,
    # otherwise create it. -A is the "attach or create" flag.
    exec tmux new-session -A -s "$SESSION_NAME"
fi
EOF

chmod +x "$HOME/scripts/wsl-session.sh"
```

### Smoke test (from outside tmux)

If you are currently attached to a tmux session, detach first with `Ctrl-b d`. Then:

```bash
"$HOME/scripts/wsl-session.sh" smoketest
```

You should land inside tmux. Detach with `Ctrl-b d`. Then:

```bash
tmux ls
```

`smoketest` should be listed. Kill it with `tmux kill-session -t smoketest`.

### Smoke test (from inside tmux)

While attached to any tmux session, run:

```bash
"$HOME/scripts/wsl-session.sh" othersession
```

The current client should switch to a session named `othersession`. `tmux ls` from inside it should show both your original session and `othersession`. Switch back with `Ctrl-b s` (interactive session picker) or by re-running the script with the original name.

---

## Step 6 — Locate the Windows Terminal settings file

Windows Terminal stores `settings.json` at:

```
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

If Windows Terminal was installed outside the Microsoft Store, the path may be:

```
%LOCALAPPDATA%\Microsoft\Windows Terminal\settings.json
```

Open Windows Terminal at least once before continuing so the file exists. Back up the current file:

```powershell
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
Copy-Item $wt "$wt.bak"
```

---

## Step 7 — Write the new settings.json

Replace the contents of `settings.json` with the block below. If your WSL distro name is **not** `Ubuntu`, do a find-and-replace on `-d Ubuntu` to match what `wsl -l -v` shows. If you want to use the default distro instead, change `wsl.exe -d Ubuntu --` to `wsl.exe --`.

The 15 session GUIDs below are pre-generated and unique. You can reuse them as-is — Windows Terminal only requires GUIDs to be unique within a single `settings.json` file, not across machines.

```json
{
  "$help": "https://aka.ms/terminal-documentation",
  "$schema": "https://aka.ms/terminal-profiles-schema",
  "actions": [],
  "copyFormatting": "none",
  "copyOnSelect": true,
  "defaultProfile": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
  "keybindings": [
    { "id": "Terminal.CopyToClipboard",     "keys": "ctrl+c" },
    { "id": "Terminal.PasteFromClipboard",  "keys": "ctrl+v" },
    { "id": "Terminal.FindText",            "keys": "ctrl+shift+f" },
    { "id": "Terminal.DuplicatePaneAuto",   "keys": "alt+shift+d" }
  ],
  "newTabMenu": [ { "type": "remainingProfiles" } ],
  "profiles": {
    "defaults": {},
    "list": [
      {
        "commandline": "%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
        "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
        "hidden": false,
        "name": "Windows PowerShell"
      },
      {
        "commandline": "%SystemRoot%\\System32\\cmd.exe",
        "guid": "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}",
        "hidden": false,
        "name": "Command Prompt"
      },
      {
        "guid": "{b453ae62-4e3d-5e58-b989-0a998ec441b8}",
        "hidden": false,
        "name": "Azure Cloud Shell",
        "source": "Windows.Terminal.Azure"
      },
      {
        "guid": "{27ddb777-3002-5ea2-986b-868806a77ed7}",
        "hidden": false,
        "name": "Ubuntu",
        "source": "Microsoft.WSL"
      },
      { "commandline": "wsl.exe -d Ubuntu -- bash -lc \"$HOME/scripts/wsl-session.sh main\"", "guid": "{348a23ad-7870-5c8c-a5c1-89e6bbfb671d}", "historySize": 20000, "name": "Session - Main" },
      { "commandline": "wsl.exe -d Ubuntu -- bash -lc \"$HOME/scripts/wsl-session.sh 2\"",    "guid": "{4156128d-b861-51d1-b493-73a93d168de0}", "historySize": 20000, "name": "Session 2" },
      { "commandline": "wsl.exe -d Ubuntu -- bash -lc \"$HOME/scripts/wsl-session.sh 3\"",    "guid": "{f5be208d-df16-5ba5-b253-3d0fc80c9849}", "historySize": 20000, "name": "Session 3" },
      { "commandline": "wsl.exe -d Ubuntu -- bash -lc \"$HOME/scripts/wsl-session.sh 4\"",    "guid": "{3ed80b05-3fdd-5de7-aabd-a954271b1c08}", "historySize": 20000, "name": "Session 4" },
      { "commandline": "wsl.exe -d Ubuntu -- bash -lc \"$HOME/scripts/wsl-session.sh 5\"",    "guid": "{9559b951-448d-5df4-9b49-9ec868bae76c}", "historySize": 20000, "name": "Session 5" },
      { "commandline": "wsl.exe -d Ubuntu -- bash -lc \"$HOME/scripts/wsl-session.sh 6\"",    "guid": "{8617f12e-2f2a-5abe-bc7d-eeb0c3ca74fd}", "historySize": 20000, "name": "Session 6" },
      { "commandline": "wsl.exe -d Ubuntu -- bash -lc \"$HOME/scripts/wsl-session.sh 7\"",    "guid": "{9345069f-2f45-5dbe-9df3-77bbd142bdc0}", "historySize": 20000, "name": "Session 7" },
      { "commandline": "wsl.exe -d Ubuntu -- bash -lc \"$HOME/scripts/wsl-session.sh 8\"",    "guid": "{e671e4c0-a27e-44ac-bb6f-f182656d610d}", "historySize": 20000, "name": "Session 8" },
      { "commandline": "wsl.exe -d Ubuntu -- bash -lc \"$HOME/scripts/wsl-session.sh 9\"",    "guid": "{c661adca-c220-4ec4-9d75-bf86fc1235c7}", "historySize": 20000, "name": "Session 9" },
      { "commandline": "wsl.exe -d Ubuntu -- bash -lc \"$HOME/scripts/wsl-session.sh 10\"",   "guid": "{7437b7a8-89b8-495a-a986-97da5d261c12}", "historySize": 20000, "name": "Session 10" },
      { "commandline": "wsl.exe -d Ubuntu -- bash -lc \"$HOME/scripts/wsl-session.sh 11\"",   "guid": "{5f6552b9-58f6-4bc8-b68b-2870f305f1fe}", "historySize": 20000, "name": "Session 11" },
      { "commandline": "wsl.exe -d Ubuntu -- bash -lc \"$HOME/scripts/wsl-session.sh 12\"",   "guid": "{9650cb8a-5859-435a-a128-da8be0843fa4}", "historySize": 20000, "name": "Session 12" },
      { "commandline": "wsl.exe -d Ubuntu -- bash -lc \"$HOME/scripts/wsl-session.sh 13\"",   "guid": "{b9786de8-b5d7-40cc-bd39-b9d1c06c54ec}", "historySize": 20000, "name": "Session 13" },
      { "commandline": "wsl.exe -d Ubuntu -- bash -lc \"$HOME/scripts/wsl-session.sh 14\"",   "guid": "{582cfc9e-9bd0-4873-a52b-2122d0c99b09}", "historySize": 20000, "name": "Session 14" },
      { "commandline": "wsl.exe -d Ubuntu -- bash -lc \"$HOME/scripts/wsl-session.sh 15\"",   "guid": "{1da6c0b1-e28e-4f78-8f1e-c089378ac36a}", "historySize": 20000, "name": "Session 15" }
    ]
  },
  "schemes": [],
  "themes": []
}
```

Save the file. Windows Terminal hot-reloads — the new profiles appear in the dropdown immediately.

### If you want fresh GUIDs instead

Generate as many as you need from PowerShell:

```powershell
1..15 | ForEach-Object { "{$([guid]::NewGuid())}" }
```

Replace each session profile's `guid` value with one of the outputs. The four built-in profiles (PowerShell, Command Prompt, Azure Cloud Shell, Ubuntu) keep their well-known GUIDs.

---

## Step 8 — Verify

Open Windows Terminal, click the dropdown arrow next to the new tab button, and confirm the 15 session profiles are listed. Open `Session - Main`. You should drop into a tmux session named `main`.

Detach with `Ctrl-b d`. From any WSL shell:

```bash
tmux ls
```

Should list `main`. Open a new `Session - Main` tab — it attaches to the same session, including any running processes. This is the property that makes long-running work survive accidental tab closes.

---

## Why this design

- `bash -lc "$HOME/..."` rather than a hardcoded `/home/<user>/...` path means no per-machine edits. The `-l` flag runs a login shell so `~/.profile` and `~/.bashrc` execute, picking up `PATH` additions, nvm, pyenv, etc.
- Single quotes around the commandline string would prevent variable expansion. Using `\"` to embed double quotes inside the JSON string is what makes `$HOME` actually expand inside the WSL bash invocation.
- The launcher's `$TMUX` check makes it safe to invoke from inside or outside tmux. Outside tmux, `tmux new-session -A -s "$NAME"` is the idempotent "attach or create" pattern. Inside tmux, `switch-client -t "$NAME"` jumps the current client to the target session, creating it detached first if it doesn't exist — this avoids the "sessions should be nested with care" error.
- Profile names are intentionally generic so the file is sharable across machines and contexts without revealing project or workload context.

---

## Step 9 — Tmux accessories

Quality-of-life additions on top of the baseline `.tmux.conf` from Step 3. All optional but worth it if you're going to live in tmux daily.

### 9a — Install Tmux Plugin Manager (TPM)

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Then inside any tmux session, press `prefix + I` (capital i — that's `Ctrl-b I` by default) to fetch and install the plugins listed in your `.tmux.conf`. They install into `~/.tmux/plugins/`.

The plugins enabled by the baseline config:

| Plugin | What you get | Why it helps for 15 parallel Claude sessions |
|---|---|---|
| **tmux-sensible** | Universally-agreed sane defaults | Safe baseline |
| **tmux-resurrect** | `prefix+Ctrl-s` save / `prefix+Ctrl-r` restore | Survives WSL restarts — get all 15 sessions back |
| **tmux-continuum** | Auto-save every 15 min, auto-restore on start | Hands-free session persistence |
| **tmux-yank** | Selection in copy mode → `clip.exe` (Windows clipboard) | Yank Claude output straight to Windows |
| **tmux-prefix-highlight** | Status-bar indicator when prefix is active | Visible cue when you forget if you pressed prefix |
| **tmux-pain-control** | Sane pane navigation/split keybinds (cwd-preserving) | New Claude pane in the same worktree, not `$HOME` |
| **tmux-cpu** | CPU/memory in status bar | 15 Claude sessions can pin a VM — see it before it crashes |
| **tmux-online-status** | Network-up indicator | Catch WSL DNS blips before blaming Claude API |
| **tmux-logging** | `prefix+alt+p` toggles per-pane logging to `~/tmux-logs/` | Capture Claude transcripts you'll want later |
| **tmux-sessionx** ⭐ | `prefix+o` opens fzf with live previews of every session | The killer feature for "which of my 15 sessions is running X?" |
| **tmux-notify** ⭐ | Mark pane → toast notification when its command exits | Stop polling 15 panes; get pinged when Claude finishes |
| **tmux-agent-indicator** ⭐ | Pane border + status-bar icon reflect AI agent state (idle / thinking / awaiting permission) | Purpose-built for Claude/Codex panes — instantly see which are blocked |
| **extrakto** | `prefix+tab` fzf-pick paths/URLs/SHAs/quotes from buffer | Pull file paths and error messages from Claude output without mouse |
| **tmux-fuzzback** | `prefix+?` fzf search across scrollback | Find "where did Claude print that migration filename 800 lines ago" |
| **tmux-autoreload** | Watch `~/.tmux.conf` and reload on save | Saves the `prefix+r` dance while tuning the config |

The ⭐ plugins are the ones you'd miss most after a week. Install all of them.

Most plugins have prerequisites:

```bash
sudo apt install -y fzf entr bc
# fzf:  required by tmux-sessionx, extrakto, fuzzback
# entr: required by tmux-autoreload (file-watcher)
# bc:   used by the token-counter script for floating-point math

# Optional: native Windows toasts for tmux-notify
# (without this, notifications fall back to terminal bell + status flash)
# Download wsl-notify-send.exe from
#   https://github.com/stuartleeks/wsl-notify-send/releases
# and put it on your Windows %PATH% (e.g. C:\Users\<you>\bin\)
```

### 9b — Token usage per session (the killer feature)

The status-right segment in the baseline config calls `~/scripts/tmux-claude-tokens.sh`. The script reads Claude Code's per-session JSONL transcripts under `~/.claude/projects/` and shows token totals for the most-recently-active session.

Install the script:

```bash
mkdir -p "$HOME/scripts"
cat > "$HOME/scripts/tmux-claude-tokens.sh" <<'EOF'
#!/usr/bin/env bash
# Sum tokens (input + output + cache create + cache read) from the most
# recently-modified Claude Code JSONL transcript on this machine.
# Output format suitable for tmux status-right: "🤖 12.3k"
set -euo pipefail

# Find the newest .jsonl across all Claude Code projects
LATEST=$(find "$HOME/.claude/projects" -name '*.jsonl' -type f -printf '%T@ %p
' 2>/dev/null          | sort -nr | head -1 | awk '{$1=""; print substr($0,2)}')

if [ -z "$LATEST" ] || [ ! -f "$LATEST" ]; then
  echo "🤖 ─"
  exit 0
fi

# jq present? If not, fall back to a coarse line count
if command -v jq >/dev/null 2>&1; then
  TOTAL=$(jq -r '
    [ .message.usage.input_tokens // 0,
      .message.usage.output_tokens // 0,
      .message.usage.cache_creation_input_tokens // 0,
      .message.usage.cache_read_input_tokens // 0 ]
    | add' "$LATEST" 2>/dev/null     | awk '{sum+=$1} END {printf "%.0f
", sum+0}')
else
  TOTAL=$(wc -l < "$LATEST")  # rough proxy: messages, not tokens
fi

# Humanize: 12345 -> "12.3k", 1234567 -> "1.2M"
if [ "${TOTAL:-0}" -ge 1000000 ]; then
  printf "🤖 %.1fM" "$(echo "$TOTAL / 1000000" | bc -l)"
elif [ "${TOTAL:-0}" -ge 1000 ]; then
  printf "🤖 %.1fk" "$(echo "$TOTAL / 1000" | bc -l)"
else
  printf "🤖 %s" "$TOTAL"
fi
EOF
chmod +x "$HOME/scripts/tmux-claude-tokens.sh"

# Verify
"$HOME/scripts/tmux-claude-tokens.sh"
```

The status bar refreshes every 5 seconds (`status-interval` in the baseline config). Reload tmux with `prefix + r` to pick up the new value.

> **Caveat:** the script reads the *most recently modified* transcript across ALL Claude projects on the box, not the one running inside the specific tmux session you're looking at. If you run multiple Claude sessions in parallel (which is the whole point of this setup), the displayed total is "the most recently active session." For per-session attribution, you'd need to wire each tmux session to a specific project path — see "Per-session token attribution" below.

### 9c — Per-session starting directory

If you want each session to open in a specific path, modify the launcher to switch on the session name. Insert this just after the `cd "$HOME"` line in `~/scripts/wsl-session.sh`:

```bash
case "$SESSION_NAME" in
  main)        cd "$HOME/repos/main-project" ;;
  infra)       cd "$HOME/repos/infra" ;;
  notes)       cd "$HOME/notes" ;;
  *)           cd "$HOME" ;;
esac
```

Note: this only affects the working directory of the *first* shell in a newly created session. Once the session exists, the `cd` is skipped on subsequent attaches.

### 9d — Per-pane logging (everything you typed, saved to disk)

Useful when something works and you want to copy-paste the exact commands later, or when something failed and you want a trace. `tmux-logging` is a popular plugin for this — add it to the plugin list:

```
set -g @plugin 'tmux-plugins/tmux-logging'
```

Then `prefix + alt+p` toggles per-pane logging to `~/tmux-logs/<session>-<window>-<pane>-<timestamp>.log`. `prefix + alt+P` saves the visible scrollback. `prefix + alt+shift+p` clears the pane history.

### 9e — Per-session token attribution (advanced)

If you want each tmux session to show ONLY its own session's token count (not the global most-recent), wire the Claude session ID to the tmux session at launch:

1. Modify `wsl-session.sh` to set `CLAUDE_SESSION_ID` for new tmux sessions when launching Claude
2. Update `tmux-claude-tokens.sh` to read `tmux show-environment CLAUDE_SESSION_ID` first, fall back to most-recent if unset

This is left as an exercise — Claude Code's per-session metadata format is still evolving and will need adjustment as the CLI changes.

### 9f — Quick keybinding reference

After applying the baseline config + plugins:

| Combo | Effect |
|---|---|
| `Ctrl-b` | tmux prefix (default) |
| `prefix + r` | reload `.tmux.conf` |
| `prefix + h/j/k/l` | jump pane left/down/up/right |
| `prefix + H/J/K/L` (repeat) | resize current pane in that direction |
| `prefix + "` / `prefix + %` | split horizontally / vertically |
| `prefix + c` | new window (in current path) |
| `prefix + s` | interactive session picker |
| `prefix + S` | detach OTHER clients (clean idle attach) |
| `prefix + y` | toggle synchronize-panes (run-everywhere) |
| `prefix + d` | detach current client |
| `prefix + [` | enter copy mode; `v` start, `y` yank to clipboard, `q` quit |
| `prefix + Ctrl-s` | resurrect: save sessions to disk |
| `prefix + Ctrl-r` | resurrect: restore from disk |
| `prefix + I` | TPM: install/update plugins |
| `prefix + alt-u` | TPM: uninstall removed plugins |

### 9g — Custom Windows Terminal icons

Add `"icon": "<path>"` to any profile in `settings.json`. For portability, put icon files at a stable Windows path like `%USERPROFILE%\.config\terminal-icons\session.ico` rather than inside a project repo.

### 9h — Custom color schemes

Define entries in the top-level `"schemes"` array of `settings.json`, then reference one with `"colorScheme": "<scheme-name>"` inside any profile.

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `sessions should be nested with care, unset $TMUX to force` | You ran the script from inside an existing tmux session. The updated launcher in Step 5 handles this with `switch-client`. If you see this message, your script is the older version — re-run the Step 5 install block. |
| Profile opens then closes immediately | Script not executable. Run `chmod +x ~/scripts/wsl-session.sh` inside WSL. |
| `wsl-session.sh: command not found` | Path wrong, or the variable did not expand. Confirm the JSON uses `bash -lc \"$HOME/...\"` with escaped double quotes, not single quotes. |
| `There is no distribution with the supplied name` | Distro name mismatch. Run `wsl -l -v`, then update `-d Ubuntu` to match exactly, or remove `-d Ubuntu` to use the default. |
| `tmux: command not found` | tmux not installed. `sudo apt install -y tmux`. |
| Sessions do not persist between tab closes | Profile is not going through the launcher. Reopen the profile and run `tmux ls` after detaching to confirm the named session exists. |
| Windows Terminal fails to load `settings.json` | JSON syntax error. Open `settings.json` and look for the parse error notification at the top of Windows Terminal, or validate with `Get-Content settings.json | ConvertFrom-Json`. |
