#!/bin/bash
# Claude Code Hook: Block file modifications outside current worktree
# This runs before Edit/Write tool calls to enforce worktree isolation
#
# Exit codes:
#   0 - Allow the tool call (file is within current worktree)
#   2 - Block the tool call (file is outside current worktree)

# Get the current worktree root
CURRENT_WORKTREE=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$CURRENT_WORKTREE" ]; then
  exit 0  # Not in a git repo, allow
fi

# Read JSON input from stdin
INPUT=$(cat)

# Extract file_path from the JSON tool input. Use POSIX sed (BRE) so this works
# on both GNU and BSD/macOS grep+sed. The previous `grep -oP '...\K...'` relied
# on PCRE, which errors on macOS's default grep — yielding an empty match and
# silently ALLOWING the write, defeating containment (fail-open).
TARGET_FILE=$(printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

if [ -z "$TARGET_FILE" ]; then
  # Fail CLOSED: if the payload carries a file_path we couldn't parse, block
  # rather than allow — a parser miss must never become a containment bypass.
  if printf '%s' "$INPUT" | grep -q '"file_path"'; then
    echo "BLOCKED: check-cross-worktree could not parse file_path; failing closed." >&2
    exit 2
  fi
  exit 0  # No file_path in this tool call — nothing to contain, allow.
fi

# Convert to absolute path if relative
if [[ "$TARGET_FILE" != /* ]]; then
  TARGET_FILE="$(pwd)/$TARGET_FILE"
fi

# Normalize paths (resolve symlinks, remove .., etc.)
CURRENT_WORKTREE=$(realpath "$CURRENT_WORKTREE" 2>/dev/null || echo "$CURRENT_WORKTREE")
TARGET_FILE=$(realpath "$TARGET_FILE" 2>/dev/null || echo "$TARGET_FILE")

# Add trailing slash to ensure we match directory boundaries
CURRENT_WORKTREE_WITH_SLASH="${CURRENT_WORKTREE}/"

# Check if target file is within current worktree
# The target must start with the current worktree path + /
if [[ "$TARGET_FILE" == "$CURRENT_WORKTREE_WITH_SLASH"* ]] || [[ "$TARGET_FILE" == "$CURRENT_WORKTREE" ]]; then
  exit 0  # File is within current worktree, allow
fi

# File is outside current worktree - BLOCK
echo "" >&2
echo "========================================" >&2
echo "  BLOCKED: Cross-worktree modification" >&2
echo "========================================" >&2
echo "" >&2
echo "  Current worktree: $CURRENT_WORKTREE" >&2
echo "  Target file: $TARGET_FILE" >&2
echo "" >&2
echo "  You can only modify files within your current worktree." >&2
echo "" >&2
echo "  If you need to modify this file:" >&2
echo "  1. Switch to the session for that worktree" >&2
echo "  2. Or use the file lock coordination system" >&2
echo "" >&2
exit 2  # Exit code 2 blocks the tool call in Claude Code
