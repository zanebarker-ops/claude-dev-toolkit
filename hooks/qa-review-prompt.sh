#!/bin/bash
# Claude Code Hook: QA Review before committing changes
# Triggers on UserPromptSubmit when user asks to commit
#
# Exit codes:
#   0 - Continue (message passed to stdout as instruction to Claude)

# UserPromptSubmit hooks receive JSON on STDIN with the prompt in `.prompt` —
# the previously-used $CLAUDE_USER_MESSAGE env var is never set by Claude Code,
# which left this hook permanently inert. Env var kept as manual-run fallback.
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat)
fi
USER_MESSAGE=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null || true)
[ -z "$USER_MESSAGE" ] && USER_MESSAGE="${CLAUDE_USER_MESSAGE:-}"

# Check if message is asking to commit
if echo "$USER_MESSAGE" | grep -qiE '\b(commit|push|create pr|make pr|submit)\b'; then

  # Check if there are staged or unstaged changes
  CHANGES=$(git status --porcelain 2>/dev/null)

  if [ -n "$CHANGES" ]; then
    echo ""
    echo "<user-prompt-submit-hook>"
    echo "QA REVIEW REQUIRED: Before committing, review changes as a senior QA engineer."
    echo ""
    echo "You are a 15-year senior QA engineer. Review all pending changes:"
    echo "1. Were changes made surgically (minimal, focused)?"
    echo "2. Any unnecessary modifications or 'while I'm here' improvements?"
    echo "3. Any security concerns (exposed secrets, missing validation)?"
    echo "4. Any unintended side effects?"
    echo ""
    echo "Run: git diff --cached (staged) and git diff (unstaged)"
    echo "If issues found, fix them before committing."
    echo "</user-prompt-submit-hook>"
  fi
fi

exit 0
