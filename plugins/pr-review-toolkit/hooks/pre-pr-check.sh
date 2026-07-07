#!/bin/bash
# PR Review Toolkit - Pre-PR Check Hook
# Reminds to run review before creating a PR

# Hook input arrives as JSON on STDIN with the command at .tool_input.command —
# the previously-used $TOOL_INPUT env var is never set by Claude Code, which
# made this hook a permanent no-op. Env var kept as manual-run fallback.
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat)
fi
COMMAND=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command') or d.get('command',''))" 2>/dev/null || true)
[ -z "$COMMAND" ] && COMMAND="${TOOL_INPUT:-}"

# Check if this is a gh pr create command
if echo "$COMMAND" | grep -q "gh pr create"; then
  # Check if review marker exists (created by running /review-pr)
  MARKER_FILE=".pr-review-completed"

  if [ ! -f "$MARKER_FILE" ]; then
    # stderr, not stdout: on PreToolUse exit 0, plain stdout is only visible in
    # verbose/transcript mode — stderr is surfaced in the conversation.
    cat >&2 <<'REMINDER'

╔════════════════════════════════════════════════════════════════╗
║  ⚠️  PR REVIEW REMINDER                                        ║
╠════════════════════════════════════════════════════════════════╣
║  Have you run the PR Review Toolkit?                          ║
║                                                                ║
║  Recommended before creating PR:                              ║
║    /pr-review-toolkit:review-pr                               ║
║                                                                ║
║  This catches:                                                 ║
║    • Security issues (RLS, auth)                              ║
║    • Silent failures (unhandled errors)                       ║
║    • Test coverage gaps                                       ║
║    • Code complexity issues                                   ║
╚════════════════════════════════════════════════════════════════╝

REMINDER
  fi
fi

# Always allow the command to proceed
exit 0
