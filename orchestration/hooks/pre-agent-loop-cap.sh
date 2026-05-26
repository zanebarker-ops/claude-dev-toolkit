#!/usr/bin/env bash
# pre-agent-loop-cap.sh — PreToolUse(Agent) guard
#
# Reads $STATE/state.json. If the task referenced in the Agent tool's prompt
# has hit its loop cap for its current tier, returns a structured "deny"
# decision so the lead receives a clean rejection (not a generic error or
# a loop-forever retry).
#
# Hook input arrives on stdin as JSON. Per Anthropic docs:
#   {
#     "session_id": "...",
#     "tool_name": "Agent",
#     "tool_input": {
#       "subagent_type": "developer",
#       "prompt": "...task=T-12...",
#       "model": "claude-sonnet-4-6"
#     }
#   }
#
# We extract the task id from the prompt (convention: "task=T-NN" tag in
# the prompt). If absent, we allow the call — guard only fires on tagged
# orchestration calls.
#
# Exit 0 + JSON decision = structured response (preferred over exit 2).

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ORCH_LIB="$ROOT/orchestration/lib"
ORCHESTRATION_DIR="$ROOT/.orchestration"
export ORCHESTRATION_DIR

# shellcheck source=../lib/state-helper.sh
source "$ORCH_LIB/state-helper.sh" 2>/dev/null || { echo '{}'; exit 0; }

input="$(cat)"
prompt="$(echo "$input" | jq -r '.tool_input.prompt // empty')"

# Extract task id (convention: "task=T-NN" or "T-NN" tag near top of prompt).
tid="$(echo "$prompt" | grep -oE 'T-[0-9]+' | head -1 || true)"
[[ -z "$tid" ]] && { echo '{}'; exit 0; }

# Hard floor 1: tasks in terminal `failed` status must never accept new Agent calls.
status="$(state_read ".tasks[\"$tid\"].status // \"pending\"")"
if [[ "$status" == "failed" ]]; then
  jq -n --arg tid "$tid" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("Task " + $tid + " is FAILED (terminal). Lead must NOT reopen it via Agent calls. Mark dependent tasks BLOCKED via recompute-deps.sh instead.")
    }
  }'
  exit 0
fi

tier="$(state_read ".tasks[\"$tid\"].tier // \"sonnet\"")"
attempts="$(state_read ".tasks[\"$tid\"].attempts[\"$tier\"] // 0")"

# Caps per tier (matches epic's escalation ladder).
# `failed` is intentionally not in CAPS — Step above blocks it. If a brand-new
# tier name slips through, conservative default cap=1 (not 3) so we err toward
# tighter guards instead of looser ones.
declare -A CAPS=( [sonnet]=3 [opus]=1 [codex]=1 )
cap="${CAPS[$tier]:-1}"

if (( attempts >= cap )); then
  jq -n --arg tid "$tid" --arg tier "$tier" --argjson cap "$cap" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("Task " + $tid + " has exhausted tier " + $tier +
        " (cap=" + ($cap | tostring) + "). Lead MUST call escalate.sh " + $tid +
        " to advance to next tier, NOT retry the same Agent call.")
    }
  }'
  exit 0
fi

echo '{}'
exit 0
