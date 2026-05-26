#!/usr/bin/env bash
# post-codex-debit.sh — PostToolUse(Bash) for codex-companion AND codex CLI.
#
# Fires on any Bash command that the pre-codex-budget-cap.sh classified as a
# spending Codex invocation (word-boundary detection: codex / codex-companion
# anywhere, wrapped or not). Has two parse paths:
#
#   1. Spike-mock single-line JSON: {task_id, tier, outcome, cents, summary}
#      Emitted by orchestration/lib/mock-codex-companion.sh.
#
#   2. Real codex CLI NDJSON event stream (gpt-5.5 et al). Last
#      `turn.completed` event has `usage: {input_tokens, output_tokens, ...}`.
#      Cost is computed via orchestration/lib/codex-pricing.json.
#      Unknown models fall back to default_model rates with a stderr warning
#      (no silent under-debit). Floats handled via jq; cents are rounded to
#      the nearest integer before debit.
#
# Both paths increment .tasks[tid].attempts.codex so the tier cap is
# enforceable even for real codex invocations the mock doesn't cover.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ORCH_LIB="$ROOT/orchestration/lib"
# Respect a caller-set ORCHESTRATION_DIR (e.g., from a verification
# script using mktemp -d). Default to the repo-local .orchestration/.
ORCHESTRATION_DIR="${ORCHESTRATION_DIR:-$ROOT/.orchestration}"
export ORCHESTRATION_DIR

source "$ORCH_LIB/state-helper.sh" 2>/dev/null || exit 0

input="$(cat)"
cmd="$(echo "$input" | jq -r '.tool_input.command // empty')"

# Mirror pre-codex-budget-cap.sh's detection: word-boundary on codex /
# codex-companion (and .mjs script form), so direct `codex review …` calls
# debit ledger and increment attempts just like codex-companion calls do.
# Use the same classifier as pre-codex-budget-cap.sh — symmetric detection
# of spending invocations across pre + post hooks. Substring matches like
# `echo "codex task"` or `grep T-42 …` are classified noncodex and skipped.
classification="$(cmd_codex_classification "$cmd")"
case "$classification" in
  noncodex|nonspend) exit 0 ;;
  spend) ;;
esac

# tool_response carries the captured output.
out="$(echo "$input" | jq -r '.tool_response.stdout // .tool_response.output // empty')"
last="$(echo "$out" | tail -n 1)"

# Path 1: spike-mock single-line JSON.
cents="$(echo "$last" | jq -r '.cents // empty' 2>/dev/null || true)"
mock_tid="$(echo "$last" | jq -r '.task_id // empty' 2>/dev/null || true)"
mock_outcome="$(echo "$last" | jq -r '.outcome // empty' 2>/dev/null || true)"

# Path 2: real codex NDJSON. task id is not in the output; extract from cmdline.
# scope tid extraction to the codex sub-command so compound commands
# like `cd /tmp/T-99 && codex run T-42` debit T-42, not T-99.
codex_sub="$(cmd_codex_extract_subcmd "$cmd" || true)"
real_tid="$(echo "$codex_sub" | { grep -oE 'T-[0-9]+' || true; } | head -1)"
[[ -z "$real_tid" ]] && real_tid="$(echo "$input" | jq -r '.tool_input.env.CDT_TASK_ID // empty')"

# Prefer mock-derived tid (more specific); fall back to cmdline.
tid="${mock_tid:-$real_tid}"

# Outcome: prefer mock-derived; otherwise infer from exit_code / is_error.
outcome="${mock_outcome:-}"
if [[ -z "$outcome" ]]; then
  is_error="$(echo "$input" | jq -r '.tool_response.is_error // false')"
  exit_code_raw="$(echo "$input" | jq -r '.tool_response.exit_code // null')"
  if [[ "$is_error" == "true" || ( "$exit_code_raw" != "null" && "$exit_code_raw" != "0" ) ]]; then
    outcome=fail
  else
    outcome=pass
  fi
fi

# Path 2: real codex CLI NDJSON event stream.
# When the mock-shape single-line JSON didn't give us a cents value, try to
# parse the output as NDJSON and find the last `turn.completed` event — that
# carries the usage tokens we need. Cost = (input * rate + output * rate +
# cached * rate) / 1000, looked up from codex-pricing.json. Unknown model
# falls back to default_model with a stderr warning so we never silently
# under-debit. jq is used for the float math because bash can't.
if [[ -z "$cents" || "$cents" == "null" ]]; then
  ndjson_completed="$(echo "$out" | jq -c 'select(type == "object") | select(.event == "turn.completed")' 2>/dev/null | tail -n 1)"
  if [[ -n "$ndjson_completed" ]]; then
    in_tokens="$(echo "$ndjson_completed" | jq -r '.usage.input_tokens // 0')"
    out_tokens="$(echo "$ndjson_completed" | jq -r '.usage.output_tokens // 0')"
    cached_tokens="$(echo "$ndjson_completed" | jq -r '.usage.cached_input_tokens // 0')"
    ndjson_model="$(echo "$ndjson_completed" | jq -r '.model // empty')"

    PRICING="$ORCH_LIB/codex-pricing.json"
    if [[ -f "$PRICING" ]] && jq -e . "$PRICING" >/dev/null 2>&1; then
      default_model="$(jq -r '.default_model // "gpt-5.5"' "$PRICING")"
      model="${ndjson_model:-$default_model}"

      input_rate="$(jq -r --arg m "$model" '.models[$m].input_cents_per_1k_tokens // empty' "$PRICING")"
      if [[ -z "$input_rate" || "$input_rate" == "null" ]]; then
        echo "post-codex-debit: unknown model '$model' not in codex-pricing.json; falling back to default_model '$default_model'" >&2
        model="$default_model"
        input_rate="$(jq -r --arg m "$model" '.models[$m].input_cents_per_1k_tokens // 0' "$PRICING")"
      fi
      output_rate="$(jq -r --arg m "$model" '.models[$m].output_cents_per_1k_tokens // 0' "$PRICING")"
      cached_rate="$(jq -r --arg m "$model" '.models[$m].cached_input_cents_per_1k_tokens // 0' "$PRICING")"

      cents="$(jq -n \
        --argjson it "$in_tokens" --argjson ot "$out_tokens" --argjson ct "$cached_tokens" \
        --argjson ir "$input_rate" --argjson or "$output_rate" --argjson cr "$cached_rate" \
        '(($it * $ir + $ot * $or + $ct * $cr) / 1000) | round')"
    fi
  fi
fi

# Debit ledger only when we have explicit cents (mock path or NDJSON parser).
if [[ -n "$cents" && "$cents" != "null" && "$cents" -gt 0 && -n "$tid" ]]; then
  state_debit_codex "$cents" "$tid"
fi

# Record the codex attempt regardless of cost-known-ness, so tier cap holds.
if [[ -n "$tid" ]]; then
  state_record_attempt "$tid" codex "$outcome"
fi
exit 0
