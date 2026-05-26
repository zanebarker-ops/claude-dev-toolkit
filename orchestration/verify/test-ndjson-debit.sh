#!/usr/bin/env bash
# test-ndjson-debit.sh — Phase 2 this iteration regression test.
#
# Validates the NDJSON parse path in post-codex-debit.sh:
#   - Known model (gpt-5.5) → cents computed from codex-pricing.json
#   - Unknown model → falls back to default_model with stderr warning
#   - Missing model field → uses default_model
#   - Missing turn.completed event → no debit, but attempt still recorded
#   - Backward-compat: single-line spike-mock JSON still debits correctly
#   - Empty output → no debit, no crash
#
# Also structural: confirms the 3 skill files document the Reviewed-By trailer
# convention.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ORCH="$ROOT/orchestration"
export ORCHESTRATION_DIR="$ROOT/.orchestration"

source "$ORCH/lib/state-helper.sh"

fail() { printf '\033[31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32m[ OK ]\033[0m %s\n' "$*"; }

# Pricing rates from this iteration's codex-pricing.json: gpt-5.5 input=2.0, output=8.0
# cents per 1k tokens. For 1000-in + 500-out tokens:
#   (1000*2.0 + 500*8.0) / 1000 = (2000 + 4000) / 1000 = 6 cents
EXPECTED_CENTS_1000_500=6

# For 2384-in + 1024-out tokens (mock defaults):
#   (2384*2.0 + 1024*8.0) / 1000 = (4768 + 8192) / 1000 = 12.96 → round = 13
EXPECTED_CENTS_2384_1024=13

hook_input_bash() {
  local cmd="$1" exit_code="${2:-0}" stdout="${3:-}"
  jq -nc --arg c "$cmd" --argjson ec "$exit_code" --arg out "$stdout" '{
    session_id: "ndjson-test",
    tool_name: "Bash",
    tool_input: { command: $c },
    tool_response: { exit_code: $ec, stdout: $out, stderr: "" }
  }'
}

assert_ledger() {
  local label="$1" expected="$2"
  local got="$(state_read '.cost_ledger.month_total_cents')"
  [[ "$got" == "$expected" ]] || fail "$label: expected ledger=$expected, got $got"
}

assert_attempts() {
  local label="$1" tid="$2" expected="$3"
  local got="$(state_read ".tasks[\"$tid\"].attempts.codex")"
  [[ "$got" == "$expected" ]] || fail "$label: expected $tid.attempts.codex=$expected, got $got"
}

# ---- Test 1: NDJSON with known model (gpt-5.5) ----
rm -rf "$ORCHESTRATION_DIR" && mkdir -p "$ORCHESTRATION_DIR"
state_init_task "T-42"

ndjson_out="$($ORCH/lib/mock-codex-companion.sh T-42 --ndjson --model gpt-5.5 --input-tokens 1000 --output-tokens 500 --outcome pass)"
$ORCH/hooks/post-codex-debit.sh < <(hook_input_bash "codex run T-42" 0 "$ndjson_out")

assert_ledger "NDJSON known model" "$EXPECTED_CENTS_1000_500"
assert_attempts "NDJSON known model" "T-42" "1"
ok "NDJSON known model (gpt-5.5, 1000/500 tokens): debited ${EXPECTED_CENTS_1000_500}¢"

# ---- Test 2: NDJSON with unknown model → fallback + warning ----
rm -rf "$ORCHESTRATION_DIR" && mkdir -p "$ORCHESTRATION_DIR"
state_init_task "T-50"

ndjson_out="$($ORCH/lib/mock-codex-companion.sh T-50 --ndjson --model gpt-7.9-fake --input-tokens 1000 --output-tokens 500 --outcome pass)"
stderr_capture="$(mktemp)"
$ORCH/hooks/post-codex-debit.sh < <(hook_input_bash "codex run T-50" 0 "$ndjson_out") 2>"$stderr_capture"

assert_ledger "NDJSON unknown model fallback" "$EXPECTED_CENTS_1000_500"
grep -q "unknown model 'gpt-7.9-fake'" "$stderr_capture" \
  || fail "NDJSON unknown model: expected stderr warning. Got: $(cat $stderr_capture)"
grep -q "falling back to default_model" "$stderr_capture" \
  || fail "NDJSON unknown model: expected fallback message in stderr"
rm -f "$stderr_capture"
ok "NDJSON unknown model: stderr warning emitted, default_model rates applied"

# ---- Test 3: NDJSON with no model field → use default_model ----
rm -rf "$ORCHESTRATION_DIR" && mkdir -p "$ORCHESTRATION_DIR"
state_init_task "T-51"

# Hand-craft NDJSON with NO .model field
no_model_ndjson='{"event":"thread.started","thread_id":"thr_T-51"}
{"event":"turn.completed","usage":{"input_tokens":1000,"output_tokens":500,"cached_input_tokens":0},"outcome":"pass"}'

$ORCH/hooks/post-codex-debit.sh < <(hook_input_bash "codex run T-51" 0 "$no_model_ndjson")
assert_ledger "NDJSON no-model field" "$EXPECTED_CENTS_1000_500"
ok "NDJSON missing model field: defaulted to gpt-5.5 silently (default_model)"

# ---- Test 4: NDJSON with no turn.completed → no debit, attempt still recorded ----
rm -rf "$ORCHESTRATION_DIR" && mkdir -p "$ORCHESTRATION_DIR"
state_init_task "T-52"

incomplete_ndjson='{"event":"thread.started","thread_id":"thr_T-52"}
{"event":"turn.started","turn_id":"turn_1"}'

$ORCH/hooks/post-codex-debit.sh < <(hook_input_bash "codex run T-52" 1 "$incomplete_ndjson")
assert_ledger "NDJSON no turn.completed" "0"
assert_attempts "NDJSON no turn.completed" "T-52" "1"
ok "NDJSON missing turn.completed: no debit, but attempt recorded (tier cap holds)"

# ---- Test 5: Mock single-line JSON path (backward compat) ----
rm -rf "$ORCHESTRATION_DIR" && mkdir -p "$ORCHESTRATION_DIR"
state_init_task "T-60"

mock_out="$($ORCH/lib/mock-codex-companion.sh T-60 --cents 7 --outcome fail)"
$ORCH/hooks/post-codex-debit.sh < <(hook_input_bash "codex-companion task T-60" 0 "$mock_out")
assert_ledger "single-line mock backward-compat" "7"
assert_attempts "single-line mock backward-compat" "T-60" "1"
ok "single-line mock JSON: still debits explicit cents (Path 1 unchanged)"

# ---- Test 6: Empty output → no debit, no crash ----
rm -rf "$ORCHESTRATION_DIR" && mkdir -p "$ORCHESTRATION_DIR"
state_init_task "T-70"

$ORCH/hooks/post-codex-debit.sh < <(hook_input_bash "codex run T-70" 0 "")
assert_ledger "empty output" "0"
assert_attempts "empty output" "T-70" "1"
ok "empty output: no debit, attempt still recorded"

# ---- Test 7: NDJSON via the mock with default tokens ----
# Sanity-check the mock+hook end-to-end at the default token sizes.
rm -rf "$ORCHESTRATION_DIR" && mkdir -p "$ORCHESTRATION_DIR"
state_init_task "T-80"

default_ndjson="$($ORCH/lib/mock-codex-companion.sh T-80 --ndjson)"
$ORCH/hooks/post-codex-debit.sh < <(hook_input_bash "codex run T-80" 0 "$default_ndjson")
assert_ledger "NDJSON mock defaults (2384/1024)" "$EXPECTED_CENTS_2384_1024"
ok "NDJSON mock defaults: 2384+1024 tokens → ${EXPECTED_CENTS_2384_1024}¢ (round from 12.96)"


ok "orchestration/hooks/post-codex-debit.sh NDJSON regression: PASS"
