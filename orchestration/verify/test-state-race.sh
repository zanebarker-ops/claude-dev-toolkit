#!/usr/bin/env bash
# test-state-race.sh — fire 20 concurrent writers at state.json; verify
# every increment lands (ledger total == sum of all writer contributions)
# and state.json never ends up with corrupted JSON.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
export ORCHESTRATION_DIR="$ROOT/.orchestration"
rm -rf "$ORCHESTRATION_DIR"
mkdir -p "$ORCHESTRATION_DIR"
source "$ROOT/orchestration/lib/state-helper.sh"

WRITERS=20
INCREMENTS_PER_WRITER=10
EXPECTED=$((WRITERS * INCREMENTS_PER_WRITER))

pids=()
for w in $(seq 1 $WRITERS); do
  (
    for i in $(seq 1 $INCREMENTS_PER_WRITER); do
      state_debit_codex 1 "T-${w}"
    done
  ) &
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; done

# Validate: JSON is well-formed and total equals expected.
jq . "$ORCHESTRATION_DIR/state.json" > /dev/null || { echo FAIL: corrupted JSON; exit 1; }
total="$(state_read '.cost_ledger.month_total_cents')"
entries="$(state_read '.cost_ledger.entries | length')"

echo "writers=$WRITERS increments_each=$INCREMENTS_PER_WRITER expected_total=$EXPECTED"
echo "observed_total=$total observed_entries=$entries"

if [[ "$total" == "$EXPECTED" && "$entries" == "$EXPECTED" ]]; then
  echo "PASS: flock + atomic-rename held under $WRITERS concurrent writers, $EXPECTED total writes, zero lost updates"
  exit 0
else
  echo "FAIL: lost updates"
  exit 1
fi
