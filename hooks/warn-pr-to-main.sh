#!/usr/bin/env bash
# warn-pr-to-main.sh — Warns when creating a PR to main/master.
# In a main-only model, PRs to main ARE the normal path — this is not a block.
# It's a production-safety nudge: confirm the change is safe to ship, and for
# risky logic changes make sure review/CI has run first.

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command') or d.get('command',''))" 2>/dev/null || echo "")

# Only trigger on gh pr create with --base main or --base master
if echo "$COMMAND" | grep -qE 'gh pr create' && echo "$COMMAND" | grep -qE '\-\-base (main|master)|\-\-base=(main|master)'; then
    cat >&2 << 'WARN'

  PR TARGET: main (PRODUCTION)

  main is the only long-lived branch, so this is the normal PR target.
  Before merging, double-check the change is safe to ship:

  Low-risk (merge once CI is green):
    - Copy / verbiage changes
    - Image updates
    - Documentation changes
    - Simple non-destructive SQL

  Higher-risk (get review + green CI first):
    - Auth / session / OAuth changes
    - New feature implementations
    - API route or data model changes
    - Schema migrations with destructive ops

  If your change includes risky logic, make sure it has been reviewed
  and CI has passed before you merge to production.

WARN
fi

# Always allow — this is a warn-only hook
exit 0
