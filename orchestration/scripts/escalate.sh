#!/usr/bin/env bash
# escalate.sh <task-id>
#
# Bumps a task to the next tier on the escalation ladder.
# sonnet -> opus -> codex -> failed
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ORCHESTRATION_DIR="$ROOT/.orchestration"
export ORCHESTRATION_DIR
source "$ROOT/orchestration/lib/state-helper.sh"

tid="${1:?usage: escalate.sh <task-id>}"
state_init_task "$tid"
cur="$(state_read ".tasks[\"$tid\"].tier")"
case "$cur" in
  sonnet) next=opus ;;
  opus)   next=codex ;;
  codex)  next=failed ;;
  failed) next=failed ;;
  *)      next=sonnet ;;
esac
state_apply ".tasks[\"$tid\"].tier = \"$next\"
  | .tasks[\"$tid\"].status = (if \"$next\" == \"failed\" then \"failed\" else \"in_progress\" end)"
echo "$tid: $cur -> $next"
