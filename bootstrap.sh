#!/usr/bin/env bash
# bootstrap.sh — full host setup for the Claude Dev Toolkit
#
# What it does:
#   1. Detects platform (WSL / Linux / macOS)
#   2. Installs system packages: tmux, gh, fzf, entr, bc, jq, gitleaks
#   3. Installs nvm + Node LTS
#   4. Installs the Claude Code CLI (npm install -g @anthropic-ai/claude-code)
#   5. Installs oxlint
#   6. Drops a baseline ~/.tmux.conf if one isn't there
#   7. Installs Tmux Plugin Manager (TPM)
#   8. Installs the wsl-session.sh launcher to ~/scripts/ (WSL only)
#   9. Installs the tmux-claude-tokens.sh status script to ~/scripts/
#   10. Optionally chains into install.sh for the project-level file drop
#
# Idempotent — safe to re-run; each step skips if already installed.
#
# Usage:
#   ./bootstrap.sh                          # full host setup, no project install
#   ./bootstrap.sh /path/to/your-project    # full host setup + install.sh in project
#   ./bootstrap.sh --check                  # dry run, only verify what's installed
#   ./bootstrap.sh --skip-host /path/...    # skip host setup, run install.sh only
#
# Exit codes:
#   0 — success
#   1 — unrecoverable error
#   2 — unsupported platform

set -euo pipefail

# ---- colored output ----------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1" >&2; }
section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }
skip()    { echo -e "${YELLOW}↷${NC} $1"; }

# ---- arg parsing -------------------------------------------------------------
TOOLKIT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET=""
CHECK_ONLY=false
SKIP_HOST=false

for arg in "$@"; do
  case "$arg" in
    --check)      CHECK_ONLY=true ;;
    --skip-host)  SKIP_HOST=true ;;
    -h|--help)
      head -25 "$0" | tail -23
      exit 0 ;;
    *)            TARGET="$arg" ;;
  esac
done

# ---- platform detection ------------------------------------------------------
detect_platform() {
  case "$(uname -s)" in
    Linux*)
      if grep -qi microsoft /proc/version 2>/dev/null || \
         grep -qi wsl /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    Darwin*) echo "macos" ;;
    *) echo "unknown" ;;
  esac
}

PLATFORM=$(detect_platform)

# ---- check mode --------------------------------------------------------------
check_tool() {
  local name="$1" cmd="${2:-$1}"
  if command -v "$cmd" >/dev/null 2>&1; then
    info "$name: $($cmd --version 2>&1 | head -1 || echo installed)"
  else
    warn "$name: not installed"
  fi
}

if [ "$CHECK_ONLY" = true ]; then
  section "Tool check"
  echo "  Platform: $PLATFORM"
  check_tool node
  check_tool npm
  check_tool "Claude Code" claude
  check_tool tmux
  check_tool git
  check_tool gh
  check_tool oxlint
  check_tool gitleaks
  check_tool jq
  check_tool fzf
  check_tool bc
  [ "$PLATFORM" = "wsl" ] || [ "$PLATFORM" = "linux" ] && check_tool entr
  [ -d "$HOME/.tmux/plugins/tpm" ] && info "TPM: installed at ~/.tmux/plugins/tpm" || warn "TPM: not installed"
  [ -f "$HOME/.tmux.conf" ] && info "~/.tmux.conf: present" || warn "~/.tmux.conf: missing"
  [ -f "$HOME/scripts/wsl-session.sh" ] && info "wsl-session.sh: present" || warn "wsl-session.sh: missing"
  [ -f "$HOME/scripts/tmux-claude-tokens.sh" ] && info "tmux-claude-tokens.sh: present" || warn "tmux-claude-tokens.sh: missing"
  exit 0
fi

# ---- skip-host: only run install.sh ------------------------------------------
if [ "$SKIP_HOST" = true ]; then
  if [ -z "$TARGET" ]; then
    error "--skip-host requires a target path"; exit 1
  fi
  exec "$TOOLKIT_DIR/install.sh" "$TARGET"
fi

# ---- banner ------------------------------------------------------------------
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Claude Dev Toolkit — Bootstrap${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "  Platform: $PLATFORM"
echo "  Toolkit:  $TOOLKIT_DIR"
[ -n "$TARGET" ] && echo "  Target:   $TARGET"
echo ""

# ---- install functions -------------------------------------------------------

install_apt_packages() {
  local pkgs=("$@")
  local missing=()
  for pkg in "${pkgs[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then missing+=("$pkg"); fi
  done
  if [ ${#missing[@]} -eq 0 ]; then
    skip "apt packages already present: ${pkgs[*]}"; return
  fi
  info "Installing apt packages: ${missing[*]}"
  sudo apt update -y
  sudo apt install -y "${missing[@]}"
}

install_brew() {
  if command -v brew >/dev/null 2>&1; then
    skip "Homebrew already installed"; return
  fi
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Apple Silicon path
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -f /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_brew_packages() {
  local pkgs=("$@")
  for pkg in "${pkgs[@]}"; do
    if brew list --formula "$pkg" >/dev/null 2>&1; then
      skip "brew $pkg"
    else
      info "brew install $pkg"
      brew install "$pkg"
    fi
  done
}

install_nvm_node() {
  if command -v node >/dev/null 2>&1 && node --version | grep -qE 'v(20|22|24)'; then
    skip "Node $(node --version)"
    return
  fi
  if [ ! -d "$HOME/.nvm" ]; then
    info "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  else
    skip "nvm already installed"
  fi
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  info "Installing Node LTS via nvm..."
  nvm install --lts
  nvm use --lts
  nvm alias default lts/*
  info "Node $(node --version) — npm $(npm --version)"
}

install_claude_code() {
  # Make sure nvm is sourced so 'npm' is on PATH
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

  if command -v claude >/dev/null 2>&1; then
    skip "Claude Code: $(claude --version 2>/dev/null || echo installed)"
    return
  fi
  info "Installing Claude Code CLI..."
  npm install -g @anthropic-ai/claude-code
  info "Claude Code installed. Run 'claude auth login' after this script finishes."
}

install_oxlint() {
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  if command -v oxlint >/dev/null 2>&1; then
    skip "oxlint $(oxlint --version 2>/dev/null | head -1)"
    return
  fi
  info "Installing oxlint..."
  npm install -g oxlint
}

install_tpm() {
  if [ -d "$HOME/.tmux/plugins/tpm" ]; then
    skip "Tmux Plugin Manager already at ~/.tmux/plugins/tpm"
    return
  fi
  info "Installing Tmux Plugin Manager..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  info "TPM installed. Run 'tmux source ~/.tmux.conf && ~/.tmux/plugins/tpm/bin/install_plugins' to fetch plugins."
}

write_tmux_conf() {
  local conf="$HOME/.tmux.conf"
  if [ -f "$conf" ]; then
    skip "~/.tmux.conf already exists (not overwriting — see docs/wsl-tmux-terminal-setup.md for the recommended config)"
    return
  fi
  info "Writing baseline ~/.tmux.conf..."
  cat > "$conf" <<'TMUX_EOF'
# ---- General ----
set -g history-limit 50000
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
set -sg escape-time 10
set -g focus-events on

# ---- Reload ----
bind r source-file ~/.tmux.conf \; display "tmux.conf reloaded"

# ---- Vim-style pane nav ----
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# ---- Repeatable resize ----
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# ---- Splits keep CWD ----
bind '"' split-window -v -c "#{pane_current_path}"
bind %   split-window -h -c "#{pane_current_path}"
bind c   new-window      -c "#{pane_current_path}"

# ---- Detach idle clients ----
bind S detach-client -a

# ---- Sync panes ----
bind y setw synchronize-panes \; display "sync: #{?pane_synchronized,ON,OFF}"

# ---- Copy mode (vim) ----
setw -g mode-keys vi
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "clip.exe 2>/dev/null || pbcopy 2>/dev/null || xclip -selection clipboard 2>/dev/null"
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "clip.exe 2>/dev/null || pbcopy 2>/dev/null || xclip -selection clipboard 2>/dev/null"

# ---- Status bar ----
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
set -g pane-border-style "fg=#1a2236"
set -g pane-active-border-style "fg=#22d3ee"

# ---- Plugins ----
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
set -g @tnotify-verbose 'on'
set -g @extrakto_split_direction 'p'
set -g @extrakto_grab_area 'window full'

run '~/.tmux/plugins/tpm/tpm'
TMUX_EOF
  info "~/.tmux.conf written. After tmux launches, press prefix+I to fetch plugins."
}

install_tpm_plugins_now() {
  if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then return; fi
  info "Fetching tmux plugins..."
  if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" 2>&1 | tail -5
  fi
}

write_wsl_session_launcher() {
  local script="$HOME/scripts/wsl-session.sh"
  mkdir -p "$HOME/scripts"
  if [ -f "$script" ]; then
    skip "wsl-session.sh already at ~/scripts/"
    return
  fi
  info "Writing ~/scripts/wsl-session.sh..."
  cat > "$script" <<'WSL_EOF'
#!/usr/bin/env bash
# wsl-session.sh — Launch, attach, or switch to a named tmux session.
# Usage: wsl-session.sh <session-name>
set -euo pipefail
SESSION_NAME="${1:-main}"
cd "$HOME"
if [ -n "${TMUX:-}" ]; then
  if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux new-session -d -s "$SESSION_NAME"
  fi
  exec tmux switch-client -t "$SESSION_NAME"
else
  exec tmux new-session -A -s "$SESSION_NAME"
fi
WSL_EOF
  chmod +x "$script"
  info "wsl-session.sh installed and executable."
}

write_tmux_claude_tokens_script() {
  local script="$HOME/scripts/tmux-claude-tokens.sh"
  mkdir -p "$HOME/scripts"
  if [ -f "$script" ]; then
    skip "tmux-claude-tokens.sh already at ~/scripts/"
    return
  fi
  info "Writing ~/scripts/tmux-claude-tokens.sh (status-bar token counter)..."
  cat > "$script" <<'TOKENS_EOF'
#!/usr/bin/env bash
# Reads the most recent Claude Code JSONL transcript and outputs total tokens
# in a tmux-status-bar-friendly format: "🤖 12.3k"
set -euo pipefail
LATEST=$(find "$HOME/.claude/projects" -name '*.jsonl' -type f -printf '%T@ %p\n' 2>/dev/null \
         | sort -nr | head -1 | awk '{$1=""; print substr($0,2)}')
if [ -z "$LATEST" ] || [ ! -f "$LATEST" ]; then echo "🤖 ─"; exit 0; fi
if command -v jq >/dev/null 2>&1; then
  TOTAL=$(jq -r '
    [ .message.usage.input_tokens // 0,
      .message.usage.output_tokens // 0,
      .message.usage.cache_creation_input_tokens // 0,
      .message.usage.cache_read_input_tokens // 0 ]
    | add' "$LATEST" 2>/dev/null \
    | awk '{sum+=$1} END {printf "%.0f\n", sum+0}')
else
  TOTAL=$(wc -l < "$LATEST")
fi
if [ "${TOTAL:-0}" -ge 1000000 ]; then
  printf "🤖 %.1fM" "$(echo "$TOTAL / 1000000" | bc -l)"
elif [ "${TOTAL:-0}" -ge 1000 ]; then
  printf "🤖 %.1fk" "$(echo "$TOTAL / 1000" | bc -l)"
else
  printf "🤖 %s" "$TOTAL"
fi
TOKENS_EOF
  chmod +x "$script"
  info "tmux-claude-tokens.sh installed."
}

# ---- platform pipelines ------------------------------------------------------

bootstrap_wsl_or_linux() {
  section "System packages (apt)"
  install_apt_packages tmux git curl ca-certificates fzf entr bc jq

  section "GitHub CLI"
  if ! command -v gh >/dev/null; then
    info "Installing gh from GitHub apt repo..."
    type -p curl >/dev/null
    sudo mkdir -p -m 755 /etc/apt/keyrings
    out=$(mktemp); wget -nv -O "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg
    sudo cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install -y gh
  else
    skip "gh $(gh --version 2>&1 | head -1)"
  fi

  section "gitleaks (secret scanner)"
  if ! command -v gitleaks >/dev/null; then
    local ver="8.21.2"
    local url="https://github.com/gitleaks/gitleaks/releases/download/v${ver}/gitleaks_${ver}_linux_x64.tar.gz"
    info "Downloading gitleaks $ver..."
    tmp=$(mktemp -d)
    curl -sL "$url" | tar -xz -C "$tmp"
    sudo mv "$tmp/gitleaks" /usr/local/bin/gitleaks
    sudo chmod +x /usr/local/bin/gitleaks
    rm -rf "$tmp"
    info "gitleaks $(gitleaks version)"
  else
    skip "gitleaks $(gitleaks version 2>&1 | head -1)"
  fi

  section "Node LTS (via nvm)"
  install_nvm_node

  section "Claude Code CLI"
  install_claude_code

  section "oxlint"
  install_oxlint

  section "Tmux config + plugins"
  write_tmux_conf
  install_tpm
  install_tpm_plugins_now

  if [ "$PLATFORM" = "wsl" ]; then
    section "WSL session launcher"
    write_wsl_session_launcher
  fi

  section "Token-counter status script"
  write_tmux_claude_tokens_script
}

bootstrap_macos() {
  section "Homebrew"
  install_brew

  section "Brew packages"
  install_brew_packages tmux git gh fzf bc jq gitleaks

  section "Node LTS (via nvm)"
  install_nvm_node

  section "Claude Code CLI"
  install_claude_code

  section "oxlint"
  install_oxlint

  section "Tmux config + plugins"
  write_tmux_conf
  install_tpm
  install_tpm_plugins_now

  section "Token-counter status script"
  write_tmux_claude_tokens_script
}

# ---- run ---------------------------------------------------------------------
case "$PLATFORM" in
  wsl|linux) bootstrap_wsl_or_linux ;;
  macos)     bootstrap_macos ;;
  *)
    error "Unsupported platform: $PLATFORM (uname -s = $(uname -s))"
    exit 2 ;;
esac

# ---- chain into install.sh if a target was given -----------------------------
if [ -n "$TARGET" ]; then
  if [ ! -d "$TARGET" ]; then
    error "Target directory not found: $TARGET"; exit 1
  fi
  section "Project-level install"
  exec "$TOOLKIT_DIR/install.sh" "$TARGET"
fi

section "Done — next steps"
cat <<'NEXT'
  1. Run 'claude auth login' to authenticate Claude Code.
  2. Open Windows Terminal (WSL only) — copy
     docs/wsl-tmux-terminal-setup.md "Step 7" settings.json into
     %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
  3. To install the toolkit into a project, run:
       ./install.sh /path/to/your-project
     OR re-run with the path:
       ./bootstrap.sh /path/to/your-project
NEXT
