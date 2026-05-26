#!/bin/bash
# Claude Code Hook: Post-worktree cleanup automation
# Triggers after `git worktree remove` to:
# 1. Close the associated GitHub issue (if GH-### pattern found in path)
# 2. Sync all remaining worktrees with origin/dev
#
# Exit codes:
#   0 - Success (always returns 0 for PostToolUse)

# Derive main repo and worktrees directory dynamically
MAIN_REPO=$(git worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //')
if [ -z "$MAIN_REPO" ]; then
  MAIN_REPO=$(git rev-parse --show-toplevel 2>/dev/null)
fi

PROJECT_NAME=$(basename "$MAIN_REPO" 2>/dev/null)
WORKTREES_DIR="$(dirname "$MAIN_REPO")/${PROJECT_NAME}-worktrees"

# Get the tool input (the worktree path being removed)
TOOL_INPUT="$CLAUDE_TOOL_INPUT"

# =============================================================================
# STEP 1: Close GitHub issue
# =============================================================================

# Extract issue number from worktree path (e.g., GH-426-docs-fix -> 426)
if echo "$TOOL_INPUT" | grep -qE 'GH-[0-9]+'; then
  ISSUE_NUM=$(echo "$TOOL_INPUT" | grep -oE 'GH-[0-9]+' | head -1 | sed 's/GH-//')

  if [ -n "$ISSUE_NUM" ]; then
    echo "Closing GitHub issue #$ISSUE_NUM after worktree cleanup..."

    # Check if issue is already closed
    ISSUE_STATE=$(gh issue view "$ISSUE_NUM" --json state -q '.state' 2>/dev/null)

    if [ "$ISSUE_STATE" = "OPEN" ]; then
      # Add completion comment
      gh issue comment "$ISSUE_NUM" --body "## Completed

Worktree cleaned up. This issue has been automatically closed.

See the merged PR for details of changes made." 2>/dev/null

      # Close the issue
      gh issue close "$ISSUE_NUM" --reason completed 2>/dev/null

      echo "✓ Issue #$ISSUE_NUM closed."
    else
      echo "• Issue #$ISSUE_NUM is already closed."
    fi
  fi
fi

# =============================================================================
# STEP 2: Sync all remaining worktrees with origin/dev
# =============================================================================

echo ""
echo "Syncing all worktrees with origin/dev..."

# First, fetch latest from origin in main repo
cd "$MAIN_REPO" 2>/dev/null
git fetch origin dev --quiet 2>/dev/null

# Get list of worktree directories (excluding main repo)
if [ -d "$WORKTREES_DIR" ]; then
  for worktree in "$WORKTREES_DIR"/*/; do
    if [ -d "$worktree" ]; then
      WORKTREE_NAME=$(basename "$worktree")
      echo "• Syncing $WORKTREE_NAME..."

      (
        cd "$worktree" 2>/dev/null

        # Fetch latest
        git fetch origin dev --quiet 2>/dev/null

        # Check if there are uncommitted changes
        if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
          # No uncommitted changes, safe to merge
          git merge origin/dev --no-edit --quiet 2>/dev/null
          if [ $? -eq 0 ]; then
            echo "  ✓ Updated with latest from dev"
          else
            echo "  ⚠ Merge conflict - manual resolution needed"
          fi
        else
          echo "  ⚠ Uncommitted changes - skipping merge (run manually)"
        fi
      )
    fi
  done
else
  echo "• No worktrees directory found at $WORKTREES_DIR"
fi

echo ""
echo "✓ Worktree cleanup complete"

exit 0
