#!/bin/bash
# Claude Code Hook: Block operations in main repo (must use worktrees)
# This runs before tool execution to enforce worktree workflow
#
# Exit codes:
#   0 - Allow the tool call
#   2 - Block the tool call (stderr sent to Claude as feedback)
#
# Exceptions (allowed on dev):
#   - Success prompts: .claude/prompts/success-*.md

# Detect if we're in the main repo vs a worktree using git internals.
# In worktrees, .git at the repo root is a FILE (pointing to main .git).
# In the main repo, .git is a DIRECTORY. Works on all platforms.
TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$TOPLEVEL" ]; then
  exit 0  # Not in a git repo, allow
fi

# If .git is a regular file (not a symlink), we're in a worktree - allow operations.
# Symlinks are rejected to prevent bypass via symlink attack.
if [ -f "$TOPLEVEL/.git" ] && [ ! -L "$TOPLEVEL/.git" ]; then
  # Verify it's a real worktree by checking gitdir format
  if grep -q '^gitdir: ' "$TOPLEVEL/.git" 2>/dev/null; then
    exit 0
  fi
fi

# We're in the main repo (.git is a directory) - check branch
BRANCH=$(git branch --show-current 2>/dev/null)

# Block if on main or dev branch
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "dev" ]; then

  # Exception: Allow success prompts to be committed directly to dev
  # Check if only success prompt files are being modified
  STAGED=$(git diff --cached --name-only 2>/dev/null)
  UNSTAGED=$(git diff --name-only 2>/dev/null)
  UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null)
  ALL_CHANGES=$(printf '%s\n%s\n%s' "$STAGED" "$UNSTAGED" "$UNTRACKED" | grep -v '^$' | sort -u)

  # Check if all changes are success prompts (strict name pattern)
  ONLY_SUCCESS_PROMPTS=true
  while IFS= read -r file; do
    if [ -n "$file" ] && ! printf '%s\n' "$file" | grep -qE '^\.claude/prompts/success-[a-zA-Z0-9_-]+\.md$'; then
      ONLY_SUCCESS_PROMPTS=false
      break
    fi
  done <<< "$ALL_CHANGES"

  # Allow if only success prompts are being modified
  if [ "$ONLY_SUCCESS_PROMPTS" = true ] && [ -n "$ALL_CHANGES" ]; then
    exit 0
  fi

  # Derive project name and worktrees directory name
  PROJECT_NAME=$(basename "$TOPLEVEL")
  WORKTREES_DIR="${PROJECT_NAME}-worktrees"

  echo "" >&2
  echo "========================================" >&2
  echo "  BLOCKED: Working directly in main repo" >&2
  echo "========================================" >&2
  echo "" >&2
  echo "  Current directory: $(pwd)" >&2
  echo "  Current branch: $BRANCH" >&2
  echo "" >&2
  echo "  You MUST use a worktree for feature work:" >&2
  echo "" >&2
  echo "    git worktree add ../${WORKTREES_DIR}/GH-XXX-name -b feature/GH-XXX-name dev" >&2
  echo "    cd ../${WORKTREES_DIR}/GH-XXX-name" >&2
  echo "" >&2
  echo "  Exception: Success prompts (.claude/prompts/success-*.md) can be" >&2
  echo "  committed directly to dev without a worktree." >&2
  echo "" >&2
  exit 2  # Exit code 2 blocks the tool call in Claude Code
fi

exit 0
