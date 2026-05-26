#!/usr/bin/env bash
# install-git-hooks.sh — Install OPTIONAL git hooks (separate from Claude Code
# hooks). These are server-side hooks that run on git operations like push,
# NOT Claude Code PreToolUse/PostToolUse hooks.
#
# Usage:
#   ./install-git-hooks.sh /path/to/your-project
#   ./install-git-hooks.sh .                        # current directory
#
# What it installs:
#   - git-hooks/pre-push-review-reminder → <project>/.git/hooks/pre-push
#     Reminds the developer to run PR review skills before pushing a
#     feature branch.
#
# This script is intentionally separate from install.sh because git hooks
# install per-clone and shouldn't be lumped in with the (per-project) Claude
# Code hooks.

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1"; }

TOOLKIT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-.}"
TARGET="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"

if [ ! -d "$TARGET" ]; then
  error "Target directory not found: $TARGET"
  exit 1
fi

# Resolve the git hooks directory. This must be the worktree's .git/hooks/
# OR the shared hooks dir if core.hooksPath is set.
GITDIR=$(cd "$TARGET" && git rev-parse --git-dir 2>/dev/null || echo "")
if [ -z "$GITDIR" ]; then
  error "Target is not a git repo: $TARGET"
  exit 1
fi

# Absolute path (git rev-parse --git-dir returns relative)
GITDIR=$(cd "$TARGET" && cd "$GITDIR" && pwd)

# Respect core.hooksPath if set — git ignores .git/hooks/ when this is
# configured. Resolve relative to the target worktree so the path is correct
# whether it's absolute or relative.
CUSTOM_HOOKS_PATH=$(cd "$TARGET" && git config --get core.hooksPath 2>/dev/null || true)
if [ -n "$CUSTOM_HOOKS_PATH" ]; then
  # If absolute, use as-is; otherwise resolve relative to TARGET.
  case "$CUSTOM_HOOKS_PATH" in
    /*) HOOKS_DIR="$CUSTOM_HOOKS_PATH" ;;
    *)  HOOKS_DIR="$TARGET/$CUSTOM_HOOKS_PATH" ;;
  esac
  HOOKS_DIR=$(cd "$HOOKS_DIR" 2>/dev/null && pwd || echo "$HOOKS_DIR")
else
  HOOKS_DIR="$GITDIR/hooks"
fi
mkdir -p "$HOOKS_DIR"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Claude Dev Toolkit — Git Hooks Installer (optional)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Toolkit:    $TOOLKIT_DIR"
echo "  Target:     $TARGET"
echo "  Hooks dir:  $HOOKS_DIR"
echo ""

# pre-push-review-reminder
SRC="$TOOLKIT_DIR/git-hooks/pre-push-review-reminder"
DEST="$HOOKS_DIR/pre-push"

if [ ! -f "$SRC" ]; then
  error "Source not found: $SRC"
  exit 1
fi

if [ -f "$DEST" ] && ! cmp -s "$SRC" "$DEST"; then
  warn "$DEST already exists and differs from the toolkit version."
  warn "Backed up existing hook to $DEST.backup"
  cp "$DEST" "$DEST.backup"
fi

cp "$SRC" "$DEST"
chmod +x "$DEST"
info "Installed pre-push-review-reminder → $DEST"

echo ""
echo -e "${GREEN}Done.${NC} Git pre-push hook is active for this repo."
echo ""
echo "  To remove: rm $DEST"
echo "  To restore previous: mv $DEST.backup $DEST  (if backup exists)"
