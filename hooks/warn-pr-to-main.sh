#!/usr/bin/env bash
# warn-pr-to-main.sh — Warns when creating a PR directly to main/master.
# Reminds the user to consider whether the change is safe for production
# or should go through a staging branch first.

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('command',''))" 2>/dev/null || echo "")

# Only trigger on gh pr create with --base main or --base master
if echo "$COMMAND" | grep -qE 'gh pr create' && echo "$COMMAND" | grep -qE '\-\-base (main|master)|\-\-base=(main|master)'; then
    cat >&2 << 'WARN'

  PR TARGET: main/master (PRODUCTION)

  You are creating a PR directly to the production branch.

  This is appropriate for:
    - Copy / verbiage changes
    - Image updates
    - Documentation changes
    - Simple non-destructive SQL

  This is NOT appropriate for:
    - Auth / session / OAuth changes
    - New feature implementations
    - API route or data model changes
    - Schema migrations with destructive ops

  If your change includes logic changes, consider using
  a staging branch (e.g. dev) instead.

WARN
fi

# Always allow — this is a warn-only hook
exit 0
