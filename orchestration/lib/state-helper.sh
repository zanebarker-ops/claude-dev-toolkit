#!/usr/bin/env bash
# state-helper.sh — flock-guarded atomic writes to .orchestration/state.json
#
# WRITER DISCIPLINE (resolves Q4 in phase-1-spike-results.md):
#
#   Multiple processes may want to update state.json simultaneously:
#     - The lead (Claude) via Bash calls
#     - PostToolUse hooks that fire per tool call
#     - Helper scripts (escalate.sh, recompute-deps.sh)
#
#   ALL of them go through this helper. The helper uses flock(1) on a
#   sibling lock file (state.json.lock) with a 10-second timeout. Inside
#   the lock we do a read-modify-write via jq, write to a temp file in
#   the same directory, fsync, then rename. fs rename is atomic on the
#   same volume on Linux, so readers never observe a half-written file.
#
#   Hooks NEVER write to state.json directly. They invoke this helper.
#   That gives us a single-writer-discipline through one well-known
#   serialization point.

set -euo pipefail

STATE_DIR="${ORCHESTRATION_DIR:-$PWD/.orchestration}"
STATE_FILE="$STATE_DIR/state.json"
LOCK_FILE="$STATE_DIR/state.json.lock"

mkdir -p "$STATE_DIR"
# Lock-file existence is required for flock(1), but its contents are unused —
# safe to create unconditionally. Use noclobber-in-subshell so concurrent loads
# don't race each other on this trivial init.
[[ -f "$LOCK_FILE" ]] || (set -C; : > "$LOCK_FILE") 2>/dev/null || true
# Data file is intentionally NOT created here. state_apply initializes it
# inside the flock so the first concurrent writer can't be overwritten by
# a later load-time init from a sibling process. state_read tolerates absence.
DEFAULT_STATE='{"tasks":{},"cost_ledger":{"month_total_cents":0,"entries":[]},"review_log":[]}'

# state_apply <jq-filter>
#   Runs the given jq filter against the current state and atomically writes
#   the result back. Bails out if jq fails (no partial write).
state_apply() {
  local filter="$1"
  shift
  (
    flock -w 10 9 || { echo "state-helper: lock timeout" >&2; exit 1; }
    # First-writer initialization happens inside the lock, so any concurrent
    # "first writer" will block on flock, observe the file we just created,
    # and apply its update on top instead of overwriting.
    [[ -f "$STATE_FILE" ]] || printf '%s\n' "$DEFAULT_STATE" > "$STATE_FILE"
    local tmp
    tmp="$(mktemp "$STATE_FILE.XXXXXX")"
    # Extra args after the filter are forwarded to jq (e.g. --arg name value).
    # This is how callers feed dynamic strings safely instead of interpolating
    # them into the filter text (which broke on quotes/backslashes).
    if jq "$@" "$filter" "$STATE_FILE" > "$tmp"; then
      mv -f "$tmp" "$STATE_FILE"
    else
      rm -f "$tmp"
      echo "state-helper: jq filter failed: $filter" >&2
      exit 1
    fi
  ) 9>"$LOCK_FILE"
}

# state_read <jq-filter>
#   Read-only query — also takes the lock so it never reads a partial write.
state_read() {
  local filter="$1"
  (
    flock -s -w 10 9 || { echo "state-helper: lock timeout" >&2; exit 1; }
    if [[ -f "$STATE_FILE" ]]; then
      jq -r "$filter" "$STATE_FILE"
    else
      printf '%s\n' "$DEFAULT_STATE" | jq -r "$filter"
    fi
  ) 9>"$LOCK_FILE"
}

# state_init_task <task-id>
state_init_task() {
  local tid="$1"
  state_apply ".tasks[\"$tid\"] //= {
    tier: \"sonnet\",
    status: \"pending\",
    attempts: {sonnet: 0, opus: 0, codex: 0},
    last_failure: null
  }"
}

# state_record_attempt <task-id> <tier> <pass|fail> [failure-reason]
state_record_attempt() {
  local tid="$1" tier="$2" outcome="$3" reason="${4:-}"
  # Ensure full task struct exists (tier, attempts.*, status, last_failure) before
  # mutating any field. Without this, an attempt recorded ahead of state_init_task
  # creates a partial object and a later //= init no-ops on the present keys.
  state_init_task "$tid"
  state_apply '
    .tasks[$tid].attempts[$tier] += 1
    | .tasks[$tid].last_failure = (if $outcome == "fail" then $reason else null end)
    | .tasks[$tid].status = (if $outcome == "pass" then "passed" else "in_progress" end)
  ' --arg tid "$tid" --arg tier "$tier" --arg outcome "$outcome" --arg reason "$reason"
}

# state_debit_codex <cents> <task-id>
state_debit_codex() {
  local cents="$1" tid="$2"
  # Use --arg/--argjson so a task id containing quotes/backslashes from
  # external Codex output can't break the jq filter and bypass cap recording.
  state_apply '
    .cost_ledger.month_total_cents += $cents
    | .cost_ledger.entries += [{
        ts: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
        tid: $tid,
        cents: $cents
      }]
  ' --argjson cents "$cents" --arg tid "$tid"
}

# state_record_review <tid> <phase> <round> <verdict> <ts_start_epoch> <ts_end_epoch> [reason]
#   Appends a Codex review entry to .review_log[]. Lazy-initializes the field
#   via //= so existing pre-Phase-2 state.json files survive without migration.
#   ts_start_epoch / ts_end_epoch are integer seconds since epoch; the helper
#   formats them to ISO-8601 UTC inside the jq filter.
state_record_review() {
  local tid="$1" phase="$2" round="$3" verdict="$4" ts_start="$5" ts_end="$6" reason="${7:-}"
  state_apply '
    .review_log //= []
    | .review_log += [{
        tid: $tid,
        phase: $phase,
        round: ($round | tonumber),
        ts_start: ($ts_start | tonumber | strftime("%Y-%m-%dT%H:%M:%SZ")),
        ts_end: ($ts_end | tonumber | strftime("%Y-%m-%dT%H:%M:%SZ")),
        verdict: $verdict,
        reason: $reason
      }]
  ' --arg tid "$tid" --arg phase "$phase" --arg round "$round" \
    --arg verdict "$verdict" --arg ts_start "$ts_start" --arg ts_end "$ts_end" \
    --arg reason "$reason"
}

# _codex_classify_subcmd <sub-command>
#   Classifies ONE sub-command (already split off a compound) as "spend" |
#   "nonspend" | "noncodex". Strips leading env-var assignments and command
#   modifiers (sudo / env / nice / nohup / time / timeout-N) in a fixed-point
#   loop, then matches the binary against codex / codex-companion / .mjs / .js
#   forms (including `node /path/codex-companion.mjs`).
#
#   Top-level shared helper — cmd_codex_classification AND cmd_codex_extract_subcmd
#   both call this. If behavior needs to change, fix HERE.
_codex_classify_subcmd() {
  local sub="$1"
  sub="$(echo "$sub" | sed -E 's/^[[:space:]]+//')"
  local prev=""
  while [[ "$prev" != "$sub" ]]; do
    prev="$sub"
    sub="$(echo "$sub" | sed -E 's/^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]* +//')"
    sub="$(echo "$sub" | sed -E 's/^(sudo|env|nice|nohup|time|timeout[[:space:]]+[0-9]+[smhd]?)[[:space:]]+//')"
  done
  if [[ "$sub" =~ ^node[[:space:]]+([^[:space:]]*codex-companion(\.m?js)?)([[:space:]]|$) ]]; then
    sub="${BASH_REMATCH[1]} ${sub#*${BASH_REMATCH[1]}}"
  fi
  local first="$(echo "$sub" | awk '{print $1}')"
  local base="${first##*/}"
  case "$base" in
    codex|codex-companion|codex-companion.mjs|codex-companion.js) ;;
    *) echo noncodex; return ;;
  esac
  local arg1="$(echo "$sub" | awk '{print $2}')"
  case "$arg1" in
    status|result|cancel|login|logout|whoami|doctor|update|completion|help|--help|--version)
      echo nonspend; return ;;
  esac
  echo spend
}

# cmd_codex_classification <command>
#   Returns one of: "spend" | "nonspend" | "noncodex".
#   Used by pre/post codex hooks to ensure symmetric detection.
cmd_codex_classification() {
  local cmd="$1"
  if ! echo "$cmd" | grep -qE '\b(codex|codex-companion)(\.m?js)?\b'; then
    echo noncodex
    return
  fi

  local splits="$(printf '%s\n' "$cmd" | sed -E 's/(\|\||&&|;|\|)/\n/g')"
  local saw_spend=0 saw_codex=0
  while IFS= read -r sub; do
    [[ -z "${sub//[[:space:]]/}" ]] && continue
    local c="$(_codex_classify_subcmd "$sub")"
    case "$c" in
      spend)    saw_codex=1; saw_spend=1 ;;
      nonspend) saw_codex=1 ;;
    esac
  done <<< "$splits"

  # Inspect bash/sh -c '…' quoted bodies one level deep.
  if echo "$cmd" | grep -qE '\b(bash|sh)[[:space:]]+-[lic]+[[:space:]]+'; then
    local inner="$(echo "$cmd" | sed -nE "s/.*\\b(bash|sh)[[:space:]]+-[lic]+[[:space:]]+['\"]([^'\"]*)['\"].*/\\2/p")"
    if [[ -n "$inner" ]]; then
      local inner_splits="$(printf '%s\n' "$inner" | sed -E 's/(\|\||&&|;|\|)/\n/g')"
      while IFS= read -r sub; do
        [[ -z "${sub//[[:space:]]/}" ]] && continue
        local c="$(_codex_classify_subcmd "$sub")"
        case "$c" in
          spend)    saw_codex=1; saw_spend=1 ;;
          nonspend) saw_codex=1 ;;
        esac
      done <<< "$inner_splits"
    fi
  fi

  if (( saw_codex == 0 )); then echo noncodex
  elif (( saw_spend == 0 )); then echo nonspend
  else echo spend
  fi
}

# cmd_codex_extract_subcmd <command>
#   Returns the first sub-command (after splitting on shell connectives) whose
#   stripped form is a SPENDING codex invocation. Returns the ORIGINAL sub —
#   leading env-var assignments are NOT stripped, so `CDT_TASK_ID=T-42
#   codex run` returns the whole thing. For `bash -lc '…'` wrappers, descends
#   one level into the quoted body. Empty output (return 1) if no spending sub.
#
#   GH-3590: scopes task-id extraction to the codex sub-command rather than the
#   whole compound — `cd /tmp/T-99 && codex run T-42` must yield T-42, not T-99,
#   when grepped for `T-[0-9]+`.
cmd_codex_extract_subcmd() {
  local cmd="$1"
  if ! echo "$cmd" | grep -qE '\b(codex|codex-companion)(\.m?js)?\b'; then
    return 1
  fi

  _extract_from_body() {
    local body="$1"
    local splits="$(printf '%s\n' "$body" | sed -E 's/(\|\||&&|;|\|)/\n/g')"
    while IFS= read -r sub; do
      [[ -z "${sub//[[:space:]]/}" ]] && continue
      if [[ "$(_codex_classify_subcmd "$sub")" == "spend" ]]; then
        # Strip only leading whitespace; preserve env-var prefix so a task id
        # passed as `CDT_TASK_ID=T-42 codex …` stays grep-visible.
        printf '%s\n' "$sub" | sed -E 's/^[[:space:]]+//'
        return 0
      fi
    done <<< "$splits"
    return 1
  }

  _extract_from_body "$cmd" && return 0

  if echo "$cmd" | grep -qE '\b(bash|sh)[[:space:]]+-[lic]+[[:space:]]+'; then
    local inner="$(echo "$cmd" | sed -nE "s/.*\\b(bash|sh)[[:space:]]+-[lic]+[[:space:]]+['\"]([^'\"]*)['\"].*/\\2/p")"
    if [[ -n "$inner" ]]; then
      _extract_from_body "$inner" && return 0
    fi
  fi
  return 1
}

# cmd_is_sb_commit_invocation <command>
#   Returns 0 if the command actually invokes sb-commit.sh (after stripping
#   env-vars and modifiers / splitting on shell connectives), 1 otherwise.
#   Mirrors classify-and-split logic from cmd_codex_classification — substring
#   mentions in `grep "sb-commit.sh T-42"` style commands return 1.
cmd_is_sb_commit_invocation() {
  local cmd="$1"
  if ! echo "$cmd" | grep -qE '\bsb-commit\.sh\b'; then
    return 1
  fi
  local splits="$(printf '%s\n' "$cmd" | sed -E 's/(\|\||&&|;|\|)/\n/g')"
  local found=1
  while IFS= read -r sub; do
    [[ -z "${sub//[[:space:]]/}" ]] && continue
    sub="$(echo "$sub" | sed -E 's/^[[:space:]]+//')"
    local prev=""
    while [[ "$prev" != "$sub" ]]; do
      prev="$sub"
      sub="$(echo "$sub" | sed -E 's/^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]* +//')"
      sub="$(echo "$sub" | sed -E 's/^(sudo|env|nice|nohup|time|timeout[[:space:]]+[0-9]+[smhd]?|bash|sh|zsh)[[:space:]]+//')"
    done
    local first="$(echo "$sub" | awk '{print $1}')"
    if [[ "${first##*/}" == "sb-commit.sh" ]]; then
      found=0
      break
    fi
  done <<< "$splits"
  return $found
}

# When sourced, only exports functions. When invoked directly, dispatch.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd="${1:-}"
  shift || true
  case "$cmd" in
    apply) state_apply "$@" ;;
    read)  state_read "$@" ;;
    init)  state_init_task "$@" ;;
    record) state_record_attempt "$@" ;;
    debit)  state_debit_codex "$@" ;;
    review) state_record_review "$@" ;;
    *) echo "usage: $0 {apply|read|init|record|debit|review} ..." >&2; exit 2 ;;
  esac
fi
