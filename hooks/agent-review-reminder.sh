#!/bin/bash
# Claude Code Hook: Remind to run security and code review agents before PR
# Triggers on UserPromptSubmit when user asks to create a PR
#
# Exit codes:
#   0 - Continue (message passed to stdout as instruction to Claude)

USER_MESSAGE="$CLAUDE_USER_MESSAGE"

# Check if message is asking to create a PR or asking about PR status
if echo "$USER_MESSAGE" | grep -qiE '\b(create pr|make pr|push.*pr|open.*pr|pr.*create|is there a pr|submit pr)\b'; then

  echo ""
  echo "<user-prompt-submit-hook>"
  echo "AGENT REVIEW CHECKLIST: Before creating a PR, you MUST run these agents:"
  echo ""
  echo "1. /security-auditor - Review for security issues (auth, secrets, injection)"
  echo "2. /code-reviewer - Review for code quality (types, patterns, bugs)"
  echo "3. /test-automation - Ensure tests exist and pass"
  echo ""
  echo "If you haven't run these agents yet, do so NOW before creating the PR."
  echo "DO NOT skip this step."
  echo ""
  echo "4. Include a '## Files Changed' section in the PR body listing ALL changed files."
  echo "   Run: git diff \$(git merge-base HEAD origin/dev) --name-only"
  echo "   Format each file as a bullet point with a brief description of what changed."
  echo ""
  echo "5. CI/CD DEPLOYMENT CHECK (BLOCKING)"
  echo "   After pushing, verify your CI/CD pipeline passes before creating the PR."
  echo "   Check your deployment/build status before proceeding."
  echo "   DO NOT create the PR until CI/CD passes or has an approved exception."
  echo "</user-prompt-submit-hook>"

fi

exit 0
