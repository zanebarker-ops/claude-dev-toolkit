#!/usr/bin/env bash
# hello-world.sh — Phase 1 acceptance: simulate one task through the full
# Sonnet → Opus → Codex escalation ladder, with all four hooks firing
# against a real state.json, and a $0.10 budget cap. NO live Claude/OpenAI
# calls; sub-agents are stubbed as bash functions so we can exercise the
# control flow end-to-end in <1 second and prove the contracts hold.
#
# What it proves (maps to Phase 1 spike acceptance):
#   - state.json initializes, transitions tiers, records every attempt
#   - escalate.sh advances the ladder once a tier's cap is hit
#   - pre-codex-budget-cap.sh denies the codex call when budget exhausted
#   - post-codex-debit.sh debits the ledger on a successful codex call
#   - pre-agent-loop-cap.sh denies a 4th sonnet attempt on the same task
#   - post-sb-commit-update.sh records pass/fail without lead intervention
#
# Usage:
#   orchestration/scripts/hello-world.sh

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ORCH="$ROOT/orchestration"
ORCHESTRATION_DIR="$ROOT/.orchestration"
export ORCHESTRATION_DIR

# Fresh state.json + ledger for each run.
rm -rf "$ORCHESTRATION_DIR"
mkdir -p "$ORCHESTRATION_DIR"

# Budget for this spike: 10 cents.
export CDT_CODEX_CAP_CENTS=10

source "$ORCH/lib/state-helper.sh"

TID=T-42
state_init_task "$TID"

log()  { printf '\033[36m[hw]\033[0m %s\n' "$*"; }
fail() { printf '\033[31m[hw FAIL]\033[0m %s\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32m[hw OK ]\033[0m %s\n' "$*"; }

# Synthesize the JSON the hook would receive from Claude Code.
hook_input_agent() {
  local prompt="$1" model="$2"
  jq -nc --arg p "$prompt" --arg m "$model" '{
    session_id: "spike",
    tool_name: "Agent",
    tool_input: { subagent_type: "developer", prompt: $p, model: $m }
  }'
}
hook_input_bash() {
  local cmd="$1" exit_code="${2:-0}" stdout="${3:-}"
  jq -nc --arg c "$cmd" --argjson ec "$exit_code" --arg out "$stdout" '{
    session_id: "spike",
    tool_name: "Bash",
    tool_input: { command: $c },
    tool_response: { exit_code: $ec, stdout: $out, stderr: "" }
  }'
}

# decision_is_deny <hook-output-json>
decision_is_deny() {
  [[ "$(echo "$1" | jq -r '.hookSpecificOutput.permissionDecision // "allow"')" == "deny" ]]
}

# ---- Tier 1: Sonnet, 3 attempts, all fail ----
for i in 1 2 3; do
  log "Sonnet attempt $i: invoke developer Agent"
  hook_out="$($ORCH/hooks/pre-agent-loop-cap.sh < <(hook_input_agent "task=$TID implement feature" claude-sonnet-4-6))"
  decision_is_deny "$hook_out" && fail "pre-agent-loop-cap should NOT deny attempt $i (attempts < cap)"

  log "  sb-commit.sh fails (sim'd test failure)"
  # PostToolUse hook records the failure to state.json automatically.
  $ORCH/hooks/post-sb-commit-update.sh < <(hook_input_bash "bash sb-commit.sh $TID 'attempt $i'" 1 "tests: failed") || true
done

attempts="$(state_read ".tasks[\"$TID\"].attempts.sonnet")"
[[ "$attempts" == "3" ]] || fail "expected sonnet attempts=3, got $attempts"
ok "Sonnet: 3 attempts recorded by post-sb-commit hook"

# 4th sonnet attempt should be DENIED by pre-agent-loop-cap.
log "Sonnet attempt 4: should be DENIED"
hook_out="$($ORCH/hooks/pre-agent-loop-cap.sh < <(hook_input_agent "task=$TID implement feature" claude-sonnet-4-6))"
decision_is_deny "$hook_out" || fail "pre-agent-loop-cap MUST deny 4th sonnet attempt"
reason="$(echo "$hook_out" | jq -r '.hookSpecificOutput.permissionDecisionReason')"
ok "Sonnet 4th attempt denied (reason: $reason)"

# ---- Escalate to Opus ----
$ORCH/scripts/escalate.sh "$TID" > /dev/null
[[ "$(state_read ".tasks[\"$TID\"].tier")" == "opus" ]] || fail "escalate should move tier to opus"
ok "Escalated: sonnet -> opus"

# ---- Tier 2: Opus, 1 attempt, fails ----
log "Opus attempt 1: should be allowed"
hook_out="$($ORCH/hooks/pre-agent-loop-cap.sh < <(hook_input_agent "task=$TID retry as opus" claude-opus-4-7))"
decision_is_deny "$hook_out" && fail "Opus attempt 1 should NOT be denied"
$ORCH/hooks/post-sb-commit-update.sh < <(hook_input_bash "bash sb-commit.sh $TID 'opus retry'" 1 "tests: still failing")

[[ "$(state_read ".tasks[\"$TID\"].attempts.opus")" == "1" ]] || fail "expected opus attempts=1"
ok "Opus: 1 attempt recorded"

# 2nd opus attempt should be DENIED.
hook_out="$($ORCH/hooks/pre-agent-loop-cap.sh < <(hook_input_agent "task=$TID second opus retry" claude-opus-4-7))"
decision_is_deny "$hook_out" || fail "pre-agent-loop-cap MUST deny 2nd opus attempt"
ok "Opus 2nd attempt denied"

# ---- Escalate to Codex ----
$ORCH/scripts/escalate.sh "$TID" > /dev/null
[[ "$(state_read ".tasks[\"$TID\"].tier")" == "codex" ]] || fail "escalate should move tier to codex"
ok "Escalated: opus -> codex"

# ---- Tier 3: Codex with budget cap ----
# 3a. First codex call costs 4 cents. Should be allowed and debited.
log "Codex attempt 1: budget pre-check (current=0, cap=10)"
hook_out="$($ORCH/hooks/pre-codex-budget-cap.sh < <(hook_input_bash "codex-companion task $TID --json" 0 ""))"
decision_is_deny "$hook_out" && fail "Codex 1st call should NOT be denied (budget empty)"

mock_out="$($ORCH/lib/mock-codex-companion.sh "$TID" --cents 4 --outcome fail)"
$ORCH/hooks/post-codex-debit.sh < <(hook_input_bash "codex-companion task $TID --json" 0 "$mock_out")
spent="$(state_read '.cost_ledger.month_total_cents')"
[[ "$spent" == "4" ]] || fail "after 1st codex call expected ledger=4, got $spent"
ok "Codex call 1: ledger debited 4¢ (running total: $spent / 10)"

# 3b. Simulate a SECOND codex call worth 7 cents — would push us over cap.
# First the post hook fires (it ran), pushing total to 11. NEXT call's pre-hook should deny.
mock_out="$($ORCH/lib/mock-codex-companion.sh "$TID" --cents 7 --outcome fail)"
$ORCH/hooks/post-codex-debit.sh < <(hook_input_bash "codex-companion task $TID --json" 0 "$mock_out")
spent="$(state_read '.cost_ledger.month_total_cents')"
ok "Codex call 2: ledger now $spent / 10"

log "Codex attempt 3: budget pre-check should DENY"
hook_out="$($ORCH/hooks/pre-codex-budget-cap.sh < <(hook_input_bash "codex-companion task $TID --json" 0 ""))"
decision_is_deny "$hook_out" || fail "pre-codex-budget-cap MUST deny when ledger >= cap"
reason="$(echo "$hook_out" | jq -r '.hookSpecificOutput.permissionDecisionReason')"
ok "Codex 3rd call denied (reason: $reason)"

# ---- Codex tier cap (Q3 round-2 fix): --task-id triggers per-task cap ----
# .tasks.T-99 starts with attempts.codex = 0, then becomes 1 after a debit.
# CODEX_TIER_CAP defaults to 1, so the SECOND task-id-tagged call must deny.
state_init_task "T-99"
state_apply '.tasks["T-99"].attempts.codex = 1' --arg tid "T-99"

log "Tier cap test: codex call WITH --task-id T-99 (attempts=1, cap=1) -> DENY"
hook_out="$($ORCH/hooks/pre-codex-budget-cap.sh < <(hook_input_bash "codex-companion task --task-id T-99 --json" 0 ""))"
decision_is_deny "$hook_out" || fail "tier cap MUST deny when attempts.codex >= cap"
reason="$(echo "$hook_out" | jq -r '.hookSpecificOutput.permissionDecisionReason')"
ok "Tier cap denied (reason: $reason)"

# Counter-check: a call for a different task (T-100, attempts=0) should still be ALLOWED…
# …except the budget cap is already exceeded from the earlier 11 cents. So this
# tests the order: budget cap fires AFTER tier cap. We expect budget to still deny.
state_init_task "T-100"
log "Non-spending test: codex-companion status should be ALLOWED past budget cap"
hook_out="$($ORCH/hooks/pre-codex-budget-cap.sh < <(hook_input_bash "codex-companion status --task-id T-100" 0 ""))"
decision_is_deny "$hook_out" && fail "non-spending 'status' subcommand MUST NOT be denied"
ok "Non-spending status passed budget cap"

log "Non-spending test: codex-companion result --json -> ALLOWED"
hook_out="$($ORCH/hooks/pre-codex-budget-cap.sh < <(hook_input_bash "codex-companion result --json --task-id T-100" 0 ""))"
decision_is_deny "$hook_out" && fail "non-spending 'result' MUST NOT be denied"
ok "Non-spending result passed budget cap"

log "Non-spending test: codex-companion cancel -> ALLOWED"
hook_out="$($ORCH/hooks/pre-codex-budget-cap.sh < <(hook_input_bash "codex-companion cancel job-123" 0 ""))"
decision_is_deny "$hook_out" && fail "non-spending 'cancel' MUST NOT be denied"
ok "Non-spending cancel passed budget cap"

# ---- Final tier transition to FAILED ----
$ORCH/scripts/escalate.sh "$TID" > /dev/null
[[ "$(state_read ".tasks[\"$TID\"].tier")" == "failed" ]] || fail "escalate from codex should move to failed"
ok "Task $TID: codex -> failed (final)"

# ---- State snapshot ----
echo
log "Final state.json:"
jq '.' "$ORCHESTRATION_DIR/state.json"

echo
ok "Phase 1 hello-world: PASS"
