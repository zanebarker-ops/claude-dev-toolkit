#!/bin/bash
# Claude Code Hook: Run ESLint before git commit
# This runs before tool execution to catch lint errors before commits
#
# Expects a lint script at: scripts/lint-worktree.sh (in the main repo root)
# This script resolves lint tools from the main repo's node_modules,
# so it works from any worktree without needing a separate install.
#
# To customize: update LINT_SCRIPT_NAME below to match your project's script.
#
# Exit codes:
#   0 - Allow the tool call
#   2 - Block the tool call (stderr sent to Claude as feedback)

LINT_SCRIPT_NAME="scripts/lint-worktree.sh"

# Read the tool input from stdin
INPUT=$(cat)

# Extract the command from JSON input (allow optional whitespace after colon)
COMMAND=$(echo "$INPUT" | grep -oP '"command"\s*:\s*"\K[^"]*')

# Check if this is a git commit command
if echo "$COMMAND" | grep -q "git commit"; then
  # Resolve main repo root (always first entry in worktree list)
  MAIN_REPO=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')
  LINT_SCRIPT="$MAIN_REPO/$LINT_SCRIPT_NAME"

  if [ -f "$LINT_SCRIPT" ]; then
    echo "Running ESLint check before commit..." >&2

    LINT_OUTPUT=$("$LINT_SCRIPT" eslint 2>&1)
    LINT_EXIT=$?

    if [ $LINT_EXIT -ne 0 ]; then
      echo "" >&2
      echo "========================================" >&2
      echo "  BLOCKED: ESLint errors found" >&2
      echo "========================================" >&2
      echo "" >&2
      echo "$LINT_OUTPUT" >&2
      echo "" >&2
      echo "  Fix the errors above before committing." >&2
      echo "  Run: $LINT_SCRIPT eslint --fix" >&2
      echo "" >&2
      exit 2
    fi

    echo "ESLint check passed." >&2
  else
    echo "WARNING: $LINT_SCRIPT_NAME not found at $LINT_SCRIPT - skipping lint check" >&2
  fi
fi

exit 0
