#!/usr/bin/env bash
# mock-codex-companion.sh — emits the JSON shapes the post-codex-debit hook
# expects from the real codex CLI. Two output modes:
#
#   Default — single-line JSON: {task_id, tier, outcome, cents, summary}
#     The spike-mock shape. Used by hello-world.sh and PR-A's test (path 1
#     in post-codex-debit.sh).
#
#   --ndjson — NDJSON event stream: thread.started / turn.started /
#     item.completed / turn.completed (last contains usage tokens + model).
#     Mirrors the real `codex --json` output shape so PR-C's test exercises
#     the NDJSON parse path in post-codex-debit.sh.
#
# Usage:
#   mock-codex-companion.sh <task-id> [--cents N] [--outcome pass|fail]
#   mock-codex-companion.sh <task-id> --ndjson [--model M] [--input-tokens N]
#                                              [--output-tokens N] [--outcome pass|fail]

set -euo pipefail
tid="${1:-T-0}"; shift || true
cents=4
outcome=fail
ndjson=0
model="gpt-5.5"
input_tokens=2384
output_tokens=1024
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cents)         cents="$2"; shift 2;;
    --outcome)       outcome="$2"; shift 2;;
    --ndjson)        ndjson=1; shift;;
    --model)         model="$2"; shift 2;;
    --input-tokens)  input_tokens="$2"; shift 2;;
    --output-tokens) output_tokens="$2"; shift 2;;
    *) shift;;
  esac
done

if (( ndjson == 1 )); then
  # Realistic NDJSON event stream — one JSON object per line.
  jq -nc --arg tid "$tid" '{event: "thread.started", thread_id: ("thr_" + $tid)}'
  jq -nc '{event: "turn.started", turn_id: "turn_1"}'
  jq -nc '{event: "item.completed", item: {type: "reasoning"}}'
  jq -nc --arg m "$model" \
         --argjson it "$input_tokens" \
         --argjson ot "$output_tokens" \
         --arg outcome "$outcome" '{
    event: "turn.completed",
    model: $m,
    usage: {
      input_tokens: $it,
      output_tokens: $ot,
      cached_input_tokens: 0
    },
    outcome: $outcome
  }'
  exit 0
fi

# Default: spike-mock single-line shape.
echo "mock-codex-companion: tier=codex task=$tid running…"
echo "mock-codex-companion: simulated work complete"
jq -nc --arg tid "$tid" --arg outcome "$outcome" --argjson cents "$cents" '{
  task_id: $tid, tier: "codex", outcome: $outcome, cents: $cents,
  summary: "mock run"
}'
