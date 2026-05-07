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

Optional — minimal sane tmux defaults. Create `~/.tmux.conf`:

```bash
cat > ~/.tmux.conf <<'EOF'
# Larger scrollback
set -g history-limit 50000

# Mouse support
set -g mouse on

# Start window/pane numbering at 1
set -g base-index 1
setw -g pane-base-index 1

# Reload config with prefix + r
bind r source-file ~/.tmux.conf \; display "Config reloaded"

# Use 256 colors
set -g default-terminal "screen-256color"
EOF
```

Reload with `tmux source-file ~/.tmux.conf` if a session is already running.

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

## Optional extras

**Per-profile starting directories.** If you want a session to always open in a specific path, modify the launcher to switch on the session name. Insert this just after the `cd "$HOME"` line in `wsl-session.sh`:

```bash
case "$SESSION_NAME" in
  infra)   cd "$HOME/repos/infra" ;;
  notes)   cd "$HOME/notes" ;;
  *)       cd "$HOME" ;;
esac
```

Note: this only affects the working directory of the *first* shell in a newly created session. Once the session exists, the `cd` is skipped on subsequent attaches.

**Custom icons.** Add `"icon": "<path>"` to any profile. For portability, put icon files at a stable Windows path like `%USERPROFILE%\.config\terminal-icons\session.ico` rather than inside a project repo, so the same `settings.json` works without edits across machines.

**Color schemes.** Define entries in the top-level `"schemes"` array, then reference one with `"colorScheme": "<scheme-name>"` inside any profile.

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
