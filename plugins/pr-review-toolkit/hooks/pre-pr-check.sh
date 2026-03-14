#!/bin/bash
# PR Review Toolkit - Pre-PR Check Hook
# Reminds to run review before creating a PR

# Get the command being executed from stdin or environment
COMMAND="${TOOL_INPUT:-}"

# Check if this is a gh pr create command
if echo "$COMMAND" | grep -q "gh pr create"; then
  # Check if review marker exists (created by running /review-pr)
  MARKER_FILE=".pr-review-completed"

  if [ ! -f "$MARKER_FILE" ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ⚠️  PR REVIEW REMINDER                                        ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║  Have you run the PR Review Toolkit?                          ║"
    echo "║                                                                ║"
    echo "║  Recommended before creating PR:                              ║"
    echo "║    /pr-review-toolkit:review-pr                               ║"
    echo "║                                                                ║"
    echo "║  This catches:                                                 ║"
    echo "║    • Security issues (RLS, auth)                              ║"
    echo "║    • Silent failures (unhandled errors)                       ║"
    echo "║    • Test coverage gaps                                       ║"
    echo "║    • Code complexity issues                                   ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
  fi
fi

# Always allow the command to proceed
exit 0
