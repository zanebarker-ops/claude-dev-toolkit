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

# Resolve the git hooks directory the way git itself would. Use
# `git rev-parse --git-path hooks` instead of `--git-dir + /hooks` because:
# - For LINKED WORKTREES, --git-dir returns .git/worktrees/<name> (per-worktree
#   admin), but git reads hooks from the COMMON hooks path shared with the
#   main worktree. --git-path hooks resolves to the right one.
# - It also honors core.hooksPath when set, so we don't need to handle that
#   special case ourselves.
if ! (cd "$TARGET" && git rev-parse --git-dir >/dev/null 2>&1); then
  error "Target is not a git repo: $TARGET"
  exit 1
fi
HOOKS_DIR_REL=$(cd "$TARGET" && git rev-parse --git-path hooks 2>/dev/null)
# --git-path returns a path relative to the worktree; resolve to absolute.
case "$HOOKS_DIR_REL" in
  /*) HOOKS_DIR="$HOOKS_DIR_REL" ;;
  *)  HOOKS_DIR="$TARGET/$HOOKS_DIR_REL" ;;
esac
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
  # An existing pre-push hook is present and differs from the toolkit version.
  # Refuse to overwrite — could silently disable Husky, custom CI checks, etc.
  # User must explicitly remove or chain.
  error "Existing pre-push hook found at $DEST (differs from the toolkit version)."
  echo "" >&2
  echo "  This installer will NOT overwrite an existing pre-push hook." >&2
  echo "" >&2
  echo "  Options:" >&2
  echo "    A) Remove the existing hook (if you don't need it):" >&2
  echo "         rm $DEST" >&2
  echo "         bash $0 $TARGET" >&2
  echo "" >&2
  echo "    B) Chain manually (run both hooks): edit $DEST and add this" >&2
  echo "       at the end (or at the top, depending on desired order):" >&2
  echo "         bash $SRC" >&2
  echo "" >&2
  echo "    C) Use a hook framework like Husky or pre-commit (recommended" >&2
  echo "       for projects that have multiple hooks)." >&2
  echo "" >&2
  exit 1
fi

if [ -f "$DEST" ] && cmp -s "$SRC" "$DEST"; then
  # Same content, but ensure executable bit (could have been lost via a
  # manual non-preserving copy).
  chmod +x "$DEST"
  info "$DEST already matches the toolkit version — skipping (exec bit ensured)."
else
  # Normalize line endings during copy — defense in depth in case the source
  # ever sneaks back into CRLF (e.g. Windows-cloned repo with autocrlf=true).
  # Git on Linux/macOS rejects '#!/bin/bash
' as a shebang.
  tr -d '
' < "$SRC" > "$DEST"
  chmod +x "$DEST"
  info "Installed pre-push-review-reminder → $DEST"
fi

echo ""
echo -e "${GREEN}Done.${NC} Git pre-push hook is active for this repo."
echo ""
echo "  To remove: rm $DEST"
echo "  To restore previous: mv $DEST.backup $DEST  (if backup exists)"
