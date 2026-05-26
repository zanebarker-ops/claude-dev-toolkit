#!/usr/bin/env bash
# test-first-writer-race.sh — catches the round-6 bug Codex review found.
# Without the fix, two writers loading state-helper.sh concurrently against a
# missing state.json could each call the load-time `echo > FILE` AFTER a
# sibling already grabbed the lock and wrote, wiping that update.
#
# With the fix (init inside flock), this test must report zero lost updates.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
export ORCHESTRATION_DIR="$ROOT/.orchestration"

WRITERS=10
INCREMENTS=5
EXPECTED=$((WRITERS * INCREMENTS))

# Wipe state, then spawn writers WITHOUT pre-creating state.json.
rm -rf "$ORCHESTRATION_DIR"
mkdir -p "$ORCHESTRATION_DIR"

pids=()
for w in $(seq 1 $WRITERS); do
  (
    # Each worker freshly sources state-helper.sh — simulates separate hook
    # processes loading the helper for the first time against a missing file.
    source "$ROOT/orchestration/lib/state-helper.sh"
    for i in $(seq 1 $INCREMENTS); do
      state_debit_codex 1 "T-${w}"
    done
  ) &
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; done

jq . "$ORCHESTRATION_DIR/state.json" > /dev/null || { echo FAIL: corrupted JSON; exit 1; }
total="$(jq -r '.cost_ledger.month_total_cents' "$ORCHESTRATION_DIR/state.json")"
entries="$(jq -r '.cost_ledger.entries | length' "$ORCHESTRATION_DIR/state.json")"

echo "first-writer race: writers=$WRITERS incr=$INCREMENTS expected=$EXPECTED"
echo "observed total=$total entries=$entries"

if [[ "$total" == "$EXPECTED" && "$entries" == "$EXPECTED" ]]; then
  echo "PASS: no lost updates from first-writer race"
else
  echo "FAIL: lost updates — first-writer race not handled"
  exit 1
fi
