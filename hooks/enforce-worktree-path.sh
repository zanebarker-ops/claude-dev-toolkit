#!/bin/bash
# Claude Code Hook: Enforce worktree creation path
# Blocks `git worktree add` unless target is in <project>-worktrees/
#
# Convention: worktrees must live in a sibling directory named
# <project-name>-worktrees/ relative to the main repo root.
#
# Exit codes:
#   0 - Allow the tool call
#   2 - Block the tool call (stderr sent to Claude as feedback)

# Read the tool input from stdin
INPUT=$(cat)

# Extract the command from JSON input
COMMAND=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | sed 's/"command":"//;s/"$//')

# Only check git worktree add commands
if echo "$COMMAND" | grep -q "git worktree add"; then
  # Extract the target path (first non-flag argument after 'git worktree add')
  TARGET_PATH=$(echo "$COMMAND" | sed 's/.*git worktree add //' | awk '{print $1}')

  # Normalize: convert backslashes to forward slashes
  TARGET_NORMALIZED=$(echo "$TARGET_PATH" | sed 's|\\|/|g')

  # Derive expected worktrees directory name from the main repo name
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  PROJECT_NAME=$(basename "$REPO_ROOT" 2>/dev/null)
  EXPECTED_DIR="${PROJECT_NAME}-worktrees"

  # Check if path contains the expected worktrees directory
  if echo "$TARGET_NORMALIZED" | grep -q "$EXPECTED_DIR"; then
    exit 0
  fi

  echo "" >&2
  echo "========================================" >&2
  echo "  BLOCKED: Wrong worktree location" >&2
  echo "========================================" >&2
  echo "" >&2
  echo "  Target path: $TARGET_PATH" >&2
  echo "" >&2
  echo "  Worktrees MUST be created in:" >&2
  echo "    ../${EXPECTED_DIR}/" >&2
  echo "" >&2
  echo "  Correct format:" >&2
  echo "    git worktree add ../${EXPECTED_DIR}/GH-###-name -b feature/GH-###-name dev" >&2
  echo "" >&2
  exit 2
fi

exit 0
