#!/bin/bash
# Claude Code Hook: Remind to create success prompt when user confirms work is done
# Triggers on UserPromptSubmit when user says "merged", "looks good", etc.
#
# Expects success prompts to live at: .claude/prompts/success/
# Expects branch naming convention: feature/GH-###-description
#
# Exit codes:
#   0 - Continue (message passed to stdout as reminder to Claude)

USER_MESSAGE="$CLAUDE_USER_MESSAGE"

# Check if message contains confirmation phrases
if echo "$USER_MESSAGE" | grep -qiE '\b(merged|looks good|that works|perfect|lgtm|ship it|approved)\b'; then

  # Try to detect current issue number from branch name
  BRANCH=$(git branch --show-current 2>/dev/null)
  ISSUE_NUM=""

  if echo "$BRANCH" | grep -qE 'GH-[0-9]+'; then
    ISSUE_NUM=$(echo "$BRANCH" | grep -oE 'GH-[0-9]+' | head -1)
  fi

  # Check if a success prompt already exists for this issue
  if [ -n "$ISSUE_NUM" ]; then
    EXISTING=$(ls .claude/prompts/success/success-${ISSUE_NUM}*.md 2>/dev/null | head -1)

    if [ -z "$EXISTING" ]; then
      echo ""
      echo "<user-prompt-submit-hook>"
      echo "REMINDER: Create a success prompt for $ISSUE_NUM"
      echo "File: .claude/prompts/success/success-${ISSUE_NUM}-description-$(date +%Y-%m-%d).md"
      echo "Document what was built, key decisions, and reusable patterns."
      echo "</user-prompt-submit-hook>"
    fi
  fi
fi

exit 0
