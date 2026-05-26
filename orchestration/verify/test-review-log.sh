#!/usr/bin/env bash
# test-review-log.sh — Phase 2 this iteration regression test.
#
# Validates:
#   - state_record_review appends a structured entry to .review_log[]
#   - Existing pre-Phase-2 state.json files (no review_log key) are migrated
#     lazily on the first call — via `.review_log //= []`
#   - Concurrent appends from N writers all land (no lost entries under flock)
#   - The CLI dispatcher exposes a `review` subcommand
#   - dynamic-round-cap.sh returns the correct cap for each heuristic bucket
#
# Usage:
#   orchestration/verify/test-review-log.sh

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ORCH="$ROOT/orchestration"
export ORCHESTRATION_DIR="$ROOT/.orchestration"

rm -rf "$ORCHESTRATION_DIR"
mkdir -p "$ORCHESTRATION_DIR"

source "$ORCH/lib/state-helper.sh"

fail() { printf '\033[31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32m[ OK ]\033[0m %s\n' "$*"; }

# ---- 1. Lazy migration: write pre-Phase-2 state, then record a review ----
cat > "$ORCHESTRATION_DIR/state.json" <<'JSONEOF'
{"tasks":{"T-1":{"tier":"sonnet","status":"pending","attempts":{"sonnet":0,"opus":0,"codex":0},"last_failure":null}},"cost_ledger":{"month_total_cents":0,"entries":[]}}
JSONEOF

# Pre-condition: no review_log field.
[[ "$(jq 'has("review_log")' "$ORCHESTRATION_DIR/state.json")" == "false" ]] \
  || fail "test setup: state.json should NOT have review_log before record"

state_record_review "T-1" "code" "1" "REDO" "1716661800" "1716661830" "needs error handling"

# Post-condition: review_log exists with exactly one entry, fields populated.
len="$(jq '.review_log | length' "$ORCHESTRATION_DIR/state.json")"
[[ "$len" == "1" ]] || fail "expected review_log length 1, got $len"

entry="$(jq '.review_log[0]' "$ORCHESTRATION_DIR/state.json")"
[[ "$(echo "$entry" | jq -r '.tid')"     == "T-1" ]]                                  || fail "tid mismatch: $entry"
[[ "$(echo "$entry" | jq -r '.phase')"   == "code" ]]                                 || fail "phase mismatch: $entry"
[[ "$(echo "$entry" | jq -r '.round')"   == "1" ]]                                    || fail "round mismatch: $entry"
[[ "$(echo "$entry" | jq -r '.verdict')" == "REDO" ]]                                 || fail "verdict mismatch: $entry"
[[ "$(echo "$entry" | jq -r '.reason')"  == "needs error handling" ]]                 || fail "reason mismatch: $entry"
[[ "$(echo "$entry" | jq -r '.ts_start')" == "2024-05-25T18:30:00Z" ]]                || fail "ts_start mismatch: $entry"
[[ "$(echo "$entry" | jq -r '.ts_end')"   == "2024-05-25T18:30:30Z" ]]                || fail "ts_end mismatch: $entry"

# T-1's original task struct must be preserved untouched.
[[ "$(jq -r '.tasks["T-1"].tier' "$ORCHESTRATION_DIR/state.json")" == "sonnet" ]] \
  || fail "lazy migration corrupted .tasks"
ok "lazy migration: review_log appended without disturbing existing fields"

# ---- 2. Subsequent append ----
state_record_review "T-1" "code" "2" "APPROVED" "1716661900" "1716661925" ""
len="$(jq '.review_log | length' "$ORCHESTRATION_DIR/state.json")"
[[ "$len" == "2" ]] || fail "expected review_log length 2 after append, got $len"
[[ "$(jq -r '.review_log[1].verdict' "$ORCHESTRATION_DIR/state.json")" == "APPROVED" ]] || fail "second entry verdict"
ok "append: second entry recorded with empty reason"

# ---- 3. Concurrent appends ----
rm -rf "$ORCHESTRATION_DIR"
mkdir -p "$ORCHESTRATION_DIR"

WRITERS=15
ROUNDS_EACH=4
EXPECTED=$((WRITERS * ROUNDS_EACH))

pids=()
for w in $(seq 1 $WRITERS); do
  (
    # Each writer re-sources to mimic separate hook processes.
    source "$ORCH/lib/state-helper.sh"
    for r in $(seq 1 $ROUNDS_EACH); do
      state_record_review "T-${w}" "code" "$r" "REDO" "$((1716662000 + r))" "$((1716662000 + r + 10))" "writer-$w round-$r"
    done
  ) &
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; done

len="$(jq '.review_log | length' "$ORCHESTRATION_DIR/state.json")"
[[ "$len" == "$EXPECTED" ]] || fail "concurrent appends: expected $EXPECTED entries, got $len (lost updates)"
ok "concurrent: $WRITERS writers × $ROUNDS_EACH rounds = $EXPECTED entries (no lost updates)"

# ---- 4. CLI dispatcher ----
rm -rf "$ORCHESTRATION_DIR"
mkdir -p "$ORCHESTRATION_DIR"

"$ORCH/lib/state-helper.sh" review "T-99" "plan" "1" "REDO" "1716663000" "1716663050" "scope creep"
len="$(jq '.review_log | length' "$ORCHESTRATION_DIR/state.json")"
[[ "$len" == "1" ]] || fail "CLI dispatcher: expected length 1, got $len"
[[ "$(jq -r '.review_log[0].tid' "$ORCHESTRATION_DIR/state.json")" == "T-99" ]] || fail "CLI dispatcher tid"
ok "CLI dispatcher: 'review' subcommand records entry"

# ---- 5. DEFAULT_STATE now includes review_log[] ----
rm -rf "$ORCHESTRATION_DIR"
mkdir -p "$ORCHESTRATION_DIR"
state_init_task "T-fresh"   # triggers DEFAULT_STATE creation via state_apply
[[ "$(jq 'has("review_log")' "$ORCHESTRATION_DIR/state.json")" == "true" ]] || fail "DEFAULT_STATE missing review_log"
[[ "$(jq '.review_log | length' "$ORCHESTRATION_DIR/state.json")" == "0" ]] || fail "fresh review_log not empty"
ok "DEFAULT_STATE: fresh state.json includes empty review_log[]"

# ---- 6. dynamic-round-cap.sh heuristic ----
cap="$($ORCH/scripts/dynamic-round-cap.sh --diff-lines 5 --net-new-files 0)"
[[ "$cap" == "3" ]]  || fail "dynamic-round-cap: 5 lines/0 new -> expected 3, got $cap"
cap="$($ORCH/scripts/dynamic-round-cap.sh --diff-lines 10 --net-new-files 0)"
[[ "$cap" == "3" ]]  || fail "dynamic-round-cap: 10 lines/0 new -> expected 3, got $cap"
cap="$($ORCH/scripts/dynamic-round-cap.sh --diff-lines 11 --net-new-files 0)"
[[ "$cap" == "7" ]]  || fail "dynamic-round-cap: 11 lines/0 new -> expected 7, got $cap"
cap="$($ORCH/scripts/dynamic-round-cap.sh --diff-lines 100 --net-new-files 0)"
[[ "$cap" == "7" ]]  || fail "dynamic-round-cap: 100 lines/0 new -> expected 7, got $cap"
cap="$($ORCH/scripts/dynamic-round-cap.sh --diff-lines 101 --net-new-files 0)"
[[ "$cap" == "20" ]] || fail "dynamic-round-cap: 101 lines/0 new -> expected 20, got $cap"
cap="$($ORCH/scripts/dynamic-round-cap.sh --diff-lines 5 --net-new-files 1)"
[[ "$cap" == "20" ]] || fail "dynamic-round-cap: 5 lines/1 new -> expected 20, got $cap"
cap="$($ORCH/scripts/dynamic-round-cap.sh --diff-lines 0 --net-new-files 0)"
[[ "$cap" == "3" ]]  || fail "dynamic-round-cap: 0 lines/0 new -> expected 3, got $cap"
ok "dynamic-round-cap heuristic: all 7 buckets correct"

# Invalid input rejected with exit 2.
set +e
"$ORCH/scripts/dynamic-round-cap.sh" --diff-lines abc --net-new-files 0 > /dev/null 2>&1
rc=$?
set -e
[[ "$rc" == "2" ]] || fail "dynamic-round-cap: non-int --diff-lines should exit 2, got $rc"
ok "dynamic-round-cap: invalid input rejected (exit 2)"

# ---- 7. codex-pricing.json sanity ----
PRICE="$ORCH/lib/codex-pricing.json"
jq . "$PRICE" > /dev/null || fail "codex-pricing.json is not valid JSON"
[[ "$(jq -r '.default_model' "$PRICE")" == "gpt-5.5" ]] || fail "pricing: default_model should be gpt-5.5"
[[ "$(jq -r '.models["gpt-5.5"].input_cents_per_1k_tokens // empty' "$PRICE")" != "" ]] || fail "pricing: missing gpt-5.5 input rate"
[[ "$(jq -r '.models["gpt-5.5"].output_cents_per_1k_tokens // empty' "$PRICE")" != "" ]] || fail "pricing: missing gpt-5.5 output rate"
ok "codex-pricing.json: valid JSON with gpt-5.5 default + input/output rates"

echo
ok "orchestration: review_log[] + dynamic-round-cap regression: PASS"
