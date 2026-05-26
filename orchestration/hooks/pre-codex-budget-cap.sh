#!/usr/bin/env bash
# pre-codex-budget-cap.sh — PreToolUse(Bash) guard for codex / codex-companion.
#
# Two independent hard floors (either can deny):
#
#   1. Per-task tier cap — .tasks[$tid].attempts.codex >= CODEX_TIER_CAP
#      Task id is recognized in three forms: --task-id flag, positional T-NN
#      token, or CDT_TASK_ID in tool_input.env.
#
#   2. Monthly budget cap — .cost_ledger.month_total_cents >= MAX_CENTS
#      Spike default 10 cents; prod target 5000 via CDT_CODEX_CAP_CENTS.
#
# Detection: the full command is split on shell connectives (&&, ||, ;, |),
# then EACH sub-command is classified as spending / non-spending / not-codex.
# A compound command is bypassed ONLY when every codex sub-command is non-spending.
# Mixed compounds like `codex status && codex-companion task T-1` fall through
# to the caps.
#
# Recognized invocation forms (per sub-command, after stripping env-var prefixes,
# `cd ... &&`, `sudo`, `env`, `nice`, `nohup`, `time`, `timeout N`):
#   - codex …
#   - codex-companion …
#   - /path/to/codex …
#   - /path/to/codex-companion …
#   - codex-companion.mjs / codex-companion.js (and node /path/codex-companion.mjs)
#
# Non-spending subcommands (always allowed even past cap):
#   status, result, cancel, logout, whoami, doctor, update, completion, help,
#   plus --help / --version anywhere in the command.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ORCH_LIB="$ROOT/orchestration/lib"
# Respect a caller-set ORCHESTRATION_DIR (e.g., from a verification
# script using mktemp -d). Default to the repo-local .orchestration/.
ORCHESTRATION_DIR="${ORCHESTRATION_DIR:-$ROOT/.orchestration}"
export ORCHESTRATION_DIR

source "$ORCH_LIB/state-helper.sh" 2>/dev/null || { echo '{}'; exit 0; }

input="$(cat)"
cmd="$(echo "$input" | jq -r '.tool_input.command // empty')"

# Quick reject: no codex word at all.
if ! echo "$cmd" | grep -qE '\bcodex(-companion)?(\.m?js)?\b'; then
  echo '{}'; exit 0
fi

# Classify each sub-command. Returns one of: "spend", "nonspend", "noncodex".
# Delegates to the shared `_codex_classify_subcmd` in state-helper.sh so the
# pre-hook, post-hook, and cmd_codex_classification all share one definition.
classify_sub() { _codex_classify_subcmd "$1"; }

# Split the command on shell connectives. We use sed to insert newlines at
# &&, ||, ;, | (but NOT ||, which we handle first). Quoted sections of compound
# bash -lc 'foo && bar' are conservatively treated as one big spending sub if
# they contain codex — safer to deny than to miss.
splits="$(printf '%s\n' "$cmd" | sed -E 's/(\|\||&&|;|\|)/\n/g')"

saw_spend=0
saw_codex=0
while IFS= read -r sub; do
  [[ -z "${sub//[[:space:]]/}" ]] && continue
  c="$(classify_sub "$sub")"
  case "$c" in
    spend)    saw_codex=1; saw_spend=1 ;;
    nonspend) saw_codex=1 ;;
  esac
done <<< "$splits"

# Also inspect bash/sh -c '...' quoted bodies recursively (one level).
if echo "$cmd" | grep -qE '\b(bash|sh)[[:space:]]+-[lic]+[[:space:]]+'; then
  inner="$(echo "$cmd" | sed -nE "s/.*\b(bash|sh)[[:space:]]+-[lic]+[[:space:]]+['\"]([^'\"]*)['\"].*/\\2/p")"
  if [[ -n "$inner" ]]; then
    inner_splits="$(printf '%s\n' "$inner" | sed -E 's/(\|\||&&|;|\|)/\n/g')"
    while IFS= read -r sub; do
      [[ -z "${sub//[[:space:]]/}" ]] && continue
      c="$(classify_sub "$sub")"
      case "$c" in
        spend)    saw_codex=1; saw_spend=1 ;;
        nonspend) saw_codex=1 ;;
      esac
    done <<< "$inner_splits"
  fi
fi

# If no codex invocation actually found, exit allow (false-positive on regex).
if (( saw_codex == 0 )); then
  echo '{}'; exit 0
fi

# If every codex invocation is non-spending, bypass caps.
if (( saw_spend == 0 )); then
  echo '{}'; exit 0
fi

# At least one spending codex invocation present. Run cap checks.

# Step 3: per-task tier cap.
CODEX_TIER_CAP="${CDT_CODEX_TIER_CAP:-1}"
# GH-3590: scope tid extraction to the codex sub-command so compound commands
# like `cd /tmp/T-99 && codex run T-42` debit T-42, not T-99.
codex_sub="$(cmd_codex_extract_subcmd "$cmd" || true)"
tid="$(echo "$codex_sub" | { grep -oE 'T-[0-9]+' || true; } | head -1)"
[[ -z "$tid" ]] && tid="$(echo "$input" | jq -r '.tool_input.env.CDT_TASK_ID // empty')"

if [[ -n "$tid" ]]; then
  attempts="$(state_read ".tasks[\"$tid\"].attempts.codex // 0")"
  if (( attempts >= CODEX_TIER_CAP )); then
    jq -n --arg tid "$tid" --argjson att "$attempts" --argjson cap "$CODEX_TIER_CAP" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("Task " + $tid + " has used codex tier " +
          ($att | tostring) + "/" + ($cap | tostring) +
          " attempts. Mark task FAILED — codex tier exhausted.")
      }
    }'
    exit 0
  fi
fi

# Step 4: monthly budget cap.
MAX_CENTS="${CDT_CODEX_CAP_CENTS:-10}"
current="$(state_read '.cost_ledger.month_total_cents // 0')"

if (( current >= MAX_CENTS )); then
  jq -n --argjson cur "$current" --argjson cap "$MAX_CENTS" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("Codex budget cap exceeded: " +
        ($cur | tostring) + " cents used of " + ($cap | tostring) +
        " cent cap. Mark task FAILED and run recompute-deps.sh.")
    }
  }'
  exit 0
fi

echo '{}'
exit 0
