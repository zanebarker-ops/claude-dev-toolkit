#!/bin/bash
# claude-session.sh - Crash-proof Claude Code session manager
#
# Launches Claude Code sessions in tmux, independent of VS Code.
# When VS Code crashes, your Claude session survives.
#
# Usage:
#   ./scripts/claude-session.sh                    # Create/attach default session
#   ./scripts/claude-session.sh my-task            # Create/attach named session
#   ./scripts/claude-session.sh GH-123-feature     # Create/attach in worktree
#   ./scripts/claude-session.sh --list             # List all sessions
#   ./scripts/claude-session.sh --kill [name]      # Kill a session
#   ./scripts/claude-session.sh --check            # Check prerequisites only

set -e

# ─── Auto-detect project configuration ────────────────────────────────
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_NAME=$(basename "$REPO_ROOT")
PROJECT_DIR="$REPO_ROOT"
WORKTREES_DIR="$(dirname "$REPO_ROOT")/${PROJECT_NAME}-worktrees"
SESSION_PREFIX=$(echo "$PROJECT_NAME" | head -c 8 | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

print_header()  { echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n${BLUE}  Claude Session Manager: ${PROJECT_NAME}${NC}\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
print_status()  { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error()   { echo -e "${RED}✗${NC} $1"; }

check_prerequisites() {
    local missing=0
    echo -e "\n${BLUE}Checking prerequisites...${NC}"
    command -v tmux &>/dev/null && print_status "tmux: $(tmux -V)" || { print_error "tmux not installed. Run: sudo apt install tmux"; missing=1; }
    command -v git &>/dev/null && print_status "git installed" || { print_error "git not installed"; missing=1; }
    command -v claude &>/dev/null && print_status "Claude Code CLI installed" || print_warning "Claude Code CLI not in PATH"
    command -v gh &>/dev/null && { gh auth status &>/dev/null && print_status "GitHub CLI authenticated" || print_warning "GitHub CLI not authenticated. Run: gh auth login"; } || print_warning "GitHub CLI not installed"
    command -v bd &>/dev/null && print_status "Beads (bd) installed" || print_warning "Beads (bd) not installed (optional)"
    command -v op &>/dev/null && print_status "1Password CLI installed" || print_warning "1Password CLI not installed (optional)"
    [ -d "$PROJECT_DIR" ] && print_status "Project directory: $PROJECT_DIR" || { print_error "Project directory not found: $PROJECT_DIR"; missing=1; }
    return $missing
}

verify_integrations() {
    echo -e "\n${BLUE}Verifying integrations...${NC}"
    claude mcp list 2>/dev/null | grep -q "memory-keeper" && print_status "MCP Memory Keeper connected" || print_warning "MCP Memory Keeper not connected"
    cd "$PROJECT_DIR"
    local branch=$(git branch --show-current 2>/dev/null)
    [ -n "$branch" ] && print_status "Git branch: $branch"
    print_status "Active worktrees: $(git worktree list 2>/dev/null | wc -l)"
    command -v bd &>/dev/null && print_status "Ready beads: $(bd ready 2>/dev/null | grep -c '^\d' || echo '0') tasks"
}

list_sessions() {
    echo -e "\n${BLUE}Active ${PROJECT_NAME} sessions:${NC}"
    tmux list-sessions 2>/dev/null | grep "^${SESSION_PREFIX}" || echo "  No active sessions"
    echo -e "\n${BLUE}All tmux sessions:${NC}"
    tmux list-sessions 2>/dev/null || echo "  No tmux sessions running"
}

kill_session() {
    local session_name="${1:-$SESSION_PREFIX-main}"
    tmux has-session -t "$session_name" 2>/dev/null && { tmux kill-session -t "$session_name"; print_status "Killed: $session_name"; } || print_warning "Not found: $session_name"
}

signin_1password() {
    command -v op &>/dev/null || return 0
    echo -e "\n${BLUE}Signing into 1Password...${NC}"
    op account list &>/dev/null 2>&1 && op whoami &>/dev/null 2>&1 && print_status "Already signed in" && return 0
    eval $(op signin 2>/dev/null) && print_status "1Password sign-in successful" || print_warning "1Password sign-in skipped"
}

create_or_attach() {
    local session_name="${1:-main}"
    local full_session="${SESSION_PREFIX}-${session_name}"
    local work_dir="$PROJECT_DIR"

    if [[ "$session_name" =~ ^GH-[0-9]+ ]]; then
        local worktree_path="${WORKTREES_DIR}/${session_name}"
        [ -d "$worktree_path" ] && { work_dir="$worktree_path"; print_status "Using worktree: $worktree_path"; }
    fi

    if tmux has-session -t "$full_session" 2>/dev/null; then
        echo -e "\n${GREEN}Attaching to existing session: ${full_session}${NC}"
        tmux send-keys -t "$full_session" "claude --dangerously-skip-permissions" Enter
        echo -e "${YELLOW}Tip: Ctrl+b d to detach${NC}\n"
        sleep 1
        tmux attach-session -t "$full_session"
    else
        echo -e "\n${GREEN}Creating new session: ${full_session}${NC}"
        tmux new-session -d -s "$full_session" -c "$work_dir"
        tmux send-keys -t "$full_session" "cd '$work_dir' && clear" Enter

        # Status banner
        tmux send-keys -t "$full_session" "echo '' && echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' && echo '  Claude Session: $full_session' && echo '  Project: $PROJECT_NAME' && echo '  Directory: $work_dir' && echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' && echo ''" Enter

        # Git + beads info
        tmux send-keys -t "$full_session" "git branch --show-current 2>/dev/null && git worktree list 2>/dev/null | head -5 && echo ''" Enter
        tmux send-keys -t "$full_session" "command -v bd &>/dev/null && { echo 'Beads Ready:'; bd ready 2>/dev/null | head -5; echo ''; }" Enter

        # Instructions + launch
        tmux send-keys -t "$full_session" "echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' && echo '  claude --dangerously-skip-permissions  Start Claude' && echo '  Ctrl+b d   Detach    Ctrl+b [   Scroll mode' && echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' && echo ''" Enter
        tmux send-keys -t "$full_session" "claude --dangerously-skip-permissions" Enter

        echo -e "${YELLOW}Tip: Ctrl+b d to detach${NC}\n"
        sleep 1
        tmux attach-session -t "$full_session"
    fi
}

show_help() {
    cat << EOF

Claude Session Manager for: ${PROJECT_NAME}

USAGE:
    ./scripts/claude-session.sh [OPTIONS] [SESSION_NAME]

OPTIONS:
    --list, -l      List all active tmux sessions
    --kill, -k      Kill the specified session (or default)
    --check, -c     Check prerequisites and integrations only
    --help, -h      Show this help message

SESSION_NAME:
    Default: 'main'. If name matches a worktree (GH-###-*),
    the session starts in that worktree directory.

EXAMPLES:
    ./scripts/claude-session.sh                     # Default session
    ./scripts/claude-session.sh my-feature          # Named session
    ./scripts/claude-session.sh GH-123-feature      # Worktree session
    ./scripts/claude-session.sh --list              # List sessions
    ./scripts/claude-session.sh --kill my-feature   # Kill session

TMUX BASICS:
    Ctrl+b d        Detach (session keeps running)
    Ctrl+b [        Scroll/copy mode (q to exit)
    Ctrl+b c        New window
    Ctrl+b n/p      Next/previous window
    Ctrl+b %        Split vertically
    Ctrl+b "        Split horizontally

CRASH RECOVERY:
    VS Code crashes? Your tmux session survives!
    1. Open any terminal
    2. Run: tmux attach -t ${SESSION_PREFIX}-main
    3. Continue right where you left off

EOF
}

main() {
    print_header
    case "${1:-}" in
        --help|-h)  show_help; exit 0 ;;
        --list|-l)  list_sessions; exit 0 ;;
        --kill|-k)  kill_session "${2:-}"; exit 0 ;;
        --check|-c) check_prerequisites; verify_integrations; exit 0 ;;
        *)          check_prerequisites || exit 1; verify_integrations; signin_1password; create_or_attach "${1:-main}" ;;
    esac
}

main "$@"
