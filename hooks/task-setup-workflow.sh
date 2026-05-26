#!/bin/bash
# Claude Code Hook: Enforce task setup workflow
# Runs on UserPromptSubmit to inject workflow instructions for new tasks
#
# Convention: worktrees live at ../<project>-worktrees/
# Issue tracking: GitHub issues with GH-### prefix
# Optional: Beads (bd) CLI for persistent memory - remove bd steps if not used
#
# Exit codes:
#   0 - Continue (stdout is added as context to Claude)
#   2 - Block (not used here - we guide, not block)

# Read input from stdin
INPUT=$(cat)

# Extract the prompt
PROMPT=$(echo "$INPUT" | grep -o '"prompt":"[^"]*"' | sed 's/"prompt":"//;s/"$//' | head -1)

# Get current directory and branch
CURRENT_DIR=$(pwd)
BRANCH=$(git branch --show-current 2>/dev/null)

# Derive project name from repo root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
PROJECT_NAME=$(basename "$REPO_ROOT" 2>/dev/null)
WORKTREES_DIR="${PROJECT_NAME}-worktrees"

# Check if we're in main repo on dev/main branch (not in a worktree)
# Detects main repo by checking if .git is a directory (not a file, as in worktrees)
IN_MAIN_REPO=false
if [ -d "$REPO_ROOT/.git" ] && [ "$BRANCH" = "dev" -o "$BRANCH" = "main" ]; then
  IN_MAIN_REPO=true
fi

# Check if prompt looks like a new task (imperative verbs, feature requests, bug fixes)
TASK_KEYWORDS="add|create|build|implement|fix|update|change|remove|delete|refactor|migrate|setup|configure|write|make|enable|disable"
IS_NEW_TASK=false
if echo "$PROMPT" | grep -qiE "^($TASK_KEYWORDS)|please ($TASK_KEYWORDS)|can you ($TASK_KEYWORDS)|i need|i want|let's|we need"; then
  IS_NEW_TASK=true
fi

# Check if prompt already references an existing issue
HAS_ISSUE_REF=false
if echo "$PROMPT" | grep -qiE "GH-[0-9]+|#[0-9]+|issue [0-9]+|pr [0-9]+|PR #"; then
  HAS_ISSUE_REF=true
fi

# Check if bd (Beads) CLI is available
HAS_BEADS=false
if command -v bd &>/dev/null; then
  HAS_BEADS=true
fi

# If new task in main repo without issue reference, inject workflow instructions
if [ "$IN_MAIN_REPO" = true ] && [ "$IS_NEW_TASK" = true ] && [ "$HAS_ISSUE_REF" = false ]; then

  if [ "$HAS_BEADS" = true ]; then
    cat << EOF

<task-setup-reminder>
⚠️ NEW TASK DETECTED - MANDATORY SETUP REQUIRED

Before starting this work, you MUST create:

1. **GitHub Issue** (for external tracking):
   \`\`\`bash
   gh issue create --title "Brief title" --body "..." --label "enhancement"
   \`\`\`

2. **Beads Issue** (for persistent memory):
   \`\`\`bash
   bd create "Same title (GH-###)" -p 2
   \`\`\`

3. **Worktree + Branch** (for isolated workspace):
   \`\`\`bash
   git worktree add ../${WORKTREES_DIR}/GH-###-description -b feature/GH-###-description dev
   cd ../${WORKTREES_DIR}/GH-###-description
   \`\`\`

4. **Mark Beads in progress**:
   \`\`\`bash
   bd update ${PROJECT_NAME}-XXX --status in_progress
   \`\`\`

DO NOT skip this setup. Every task needs all 4 items created FIRST.
</task-setup-reminder>

EOF
  else
    cat << EOF

<task-setup-reminder>
⚠️ NEW TASK DETECTED - MANDATORY SETUP REQUIRED

Before starting this work, you MUST create:

1. **GitHub Issue** (for external tracking):
   \`\`\`bash
   gh issue create --title "Brief title" --body "..." --label "enhancement"
   \`\`\`

2. **Worktree + Branch** (for isolated workspace):
   \`\`\`bash
   git worktree add ../${WORKTREES_DIR}/GH-###-description -b feature/GH-###-description dev
   cd ../${WORKTREES_DIR}/GH-###-description
   \`\`\`

DO NOT skip this setup. Every task needs both items created FIRST.
</task-setup-reminder>

EOF
  fi
fi

# If in a worktree, remind about the current context
if [ -f "$REPO_ROOT/.git" ] && grep -q '^gitdir: ' "$REPO_ROOT/.git" 2>/dev/null; then
  ISSUE_NUM=$(basename "$CURRENT_DIR" | grep -oE 'GH-[0-9]+' | head -1)
  if [ -n "$ISSUE_NUM" ]; then
    echo ""
    echo "<current-context>"
    echo "Working in worktree for: $ISSUE_NUM"
    echo "Branch: $BRANCH"

    # Check for active beads issue (only if bd is available)
    if [ "$HAS_BEADS" = true ]; then
      BEADS_ISSUE=$(bd list --status in_progress 2>/dev/null | grep -oE "${PROJECT_NAME}-[a-z0-9]+" | head -1)
      if [ -n "$BEADS_ISSUE" ]; then
        echo "Beads issue: $BEADS_ISSUE"
      fi
    fi
    echo "</current-context>"
  fi
fi

exit 0
