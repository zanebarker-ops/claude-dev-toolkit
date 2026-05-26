#!/usr/bin/env bash
# test-task-id-scoping.sh — GH-3590 regression test.
#
# Bug: pre-codex-budget-cap.sh and post-codex-debit.sh extracted the task id
# from the WHOLE compound command. `cd /tmp/T-99 && codex run T-42` charged
# T-99 against the tier cap instead of T-42, and the post-hook recorded the
# attempt against T-99 — silently invalidating both safety floors.
#
# This test fires the live hooks against six compound forms and asserts the
# pre-hook denies on T-42's tier cap (not T-99's), and that the post-hook
# attributes the attempt to T-42 (not T-99 / T-100 / etc).
#
# What it proves:
#   - Compound `cd <dir> && codex …` scopes to the codex sub
#   - Compound `echo <T-NN> && codex …` ignores the leading T-NN
#   - Wrapped `timeout N codex …` scopes correctly
#   - Wrapped `bash -lc '… && codex …'` descends one level
#   - Env-var-prefixed `CDT_TASK_ID=T-NN codex …` is preserved (NOT stripped)
#   - Plain `codex run T-42` baseline still works
#
# Usage:
#   orchestration/verify/test-task-id-scoping.sh

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ORCH="$ROOT/orchestration"
export ORCHESTRATION_DIR="$ROOT/.orchestration"

rm -rf "$ORCHESTRATION_DIR"
mkdir -p "$ORCHESTRATION_DIR"

source "$ORCH/lib/state-helper.sh"

fail() { printf '\033[31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32m[ OK ]\033[0m %s\n' "$*"; }

hook_input_bash() {
  local cmd="$1" exit_code="${2:-0}" stdout="${3:-}"
  jq -nc --arg c "$cmd" --argjson ec "$exit_code" --arg out "$stdout" '{
    session_id: "scope-test",
    tool_name: "Bash",
    tool_input: { command: $c },
    tool_response: { exit_code: $ec, stdout: $out, stderr: "" }
  }'
}

# ---- Pre-hook tier-cap scoping ----
# Seed T-42 at attempts.codex=1 (cap=1). T-99 and T-100 are at 0.
# If the hook scopes correctly, every compound mentioning T-99/T-100 BEFORE
# the codex sub MUST still deny against T-42.
state_init_task "T-42"
state_init_task "T-99"
state_init_task "T-100"
state_apply '.tasks["T-42"].attempts.codex = 1' --arg tid "T-42"
export CDT_CODEX_TIER_CAP=1
export CDT_CODEX_CAP_CENTS=10000  # high so budget cap doesn't mask

assert_denied_for_t42() {
  local label="$1" cmd="$2"
  local out reason
  out="$($ORCH/hooks/pre-codex-budget-cap.sh < <(hook_input_bash "$cmd"))"
  local decision="$(echo "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"')"
  reason="$(echo "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"
  if [[ "$decision" != "deny" ]]; then
    fail "$label: expected DENY (T-42 at cap), got $decision. cmd=[$cmd]"
  fi
  if [[ "$reason" != *"T-42"* ]]; then
    fail "$label: deny reason should reference T-42, got: $reason"
  fi
  if [[ "$reason" == *"T-99"* || "$reason" == *"T-100"* ]]; then
    fail "$label: deny reason wrongly references decoy task. reason=$reason"
  fi
  ok "$label: pre-hook denied scoped to T-42"
}

assert_denied_for_t42 "compound cd-T99"        "cd /tmp/T-99 && codex run T-42"
assert_denied_for_t42 "compound echo-T100"     "echo T-100 && codex-companion task T-42 --json"
assert_denied_for_t42 "wrapped bash-lc"        "bash -lc 'cd /tmp/T-99 && codex run T-42'"
assert_denied_for_t42 "wrapped timeout"        "timeout 5m codex run T-42"
assert_denied_for_t42 "env-var prefix"         "CDT_TASK_ID=T-42 codex run"
assert_denied_for_t42 "plain baseline"         "codex run T-42"

# Counter-check: compound that ONLY mentions T-99 in a decoy and runs codex
# without a T-NN should NOT deny (no tid found, no tier cap fires).
out="$($ORCH/hooks/pre-codex-budget-cap.sh < <(hook_input_bash "cd /tmp/T-99 && codex run"))"
decision="$(echo "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"')"
if [[ "$decision" == "deny" ]]; then
  fail "no-tid baseline: should NOT deny (decoy T-99 must NOT trigger T-99 lookup). out=$out"
fi
ok "no-tid baseline: pre-hook allowed (decoy T-99 ignored)"

# Non-spending sub in compound — should bypass cap entirely.
out="$($ORCH/hooks/pre-codex-budget-cap.sh < <(hook_input_bash "cd /tmp/T-42 && codex status"))"
decision="$(echo "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"')"
if [[ "$decision" == "deny" ]]; then
  fail "nonspend compound: should NOT deny (status is non-spending). out=$out"
fi
ok "nonspend compound: pre-hook allowed"

# ---- Post-hook attempt-attribution scoping ----
# Reset state. Run post-hook against the mock companion's JSON output for T-42,
# wrapped in a compound that decoys T-99. Verify attempts.codex bumps on T-42,
# NOT on T-99.
rm -rf "$ORCHESTRATION_DIR"
mkdir -p "$ORCHESTRATION_DIR"
state_init_task "T-42"
state_init_task "T-99"

# Mock output: spike-shape JSON. The post-hook prefers mock-derived tid, so
# to test scoping we use a real-NDJSON-shaped output (NO task_id field) so the
# hook falls through to cmdline extraction.
mock_real_shape='{"event":"turn.completed","usage":{"input_tokens":100,"output_tokens":50}}'

post_input="$(hook_input_bash "cd /tmp/T-99 && codex run T-42" 0 "$mock_real_shape")"
$ORCH/hooks/post-codex-debit.sh < <(printf '%s' "$post_input")

t42_attempts="$(state_read '.tasks["T-42"].attempts.codex')"
t99_attempts="$(state_read '.tasks["T-99"].attempts.codex')"

if [[ "$t42_attempts" != "1" ]]; then
  fail "post-hook attempt scoping: expected T-42.attempts.codex=1, got $t42_attempts"
fi
if [[ "$t99_attempts" != "0" ]]; then
  fail "post-hook attempt scoping: T-99.attempts.codex must stay 0, got $t99_attempts (decoy leaked!)"
fi
ok "post-hook attributes attempt to T-42 (T-99 decoy ignored)"

# bash-lc inner descent for post-hook too.
post_input="$(hook_input_bash "bash -lc 'cd /tmp/T-99 && codex run T-42'" 0 "$mock_real_shape")"
$ORCH/hooks/post-codex-debit.sh < <(printf '%s' "$post_input")

t42_attempts="$(state_read '.tasks["T-42"].attempts.codex')"
t99_attempts="$(state_read '.tasks["T-99"].attempts.codex')"

if [[ "$t42_attempts" != "2" ]]; then
  fail "post-hook bash-lc inner: expected T-42.attempts.codex=2, got $t42_attempts"
fi
if [[ "$t99_attempts" != "0" ]]; then
  fail "post-hook bash-lc inner: T-99 leaked, got $t99_attempts"
fi
ok "post-hook bash-lc inner: attributes attempt to T-42"

echo
ok "orchestration: task-id scoping regression: PASS"
