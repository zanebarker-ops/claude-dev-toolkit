#!/usr/bin/env bash
# post-sb-commit-update.sh — PostToolUse(Bash) for sb-commit.sh
#
# When the developer agent runs `sb-commit.sh <task-id> <msg>`, this hook
# parses the exit code from tool_response and records pass/fail into
# state.json. Lead does not need to remember to update state — the hook does.

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

# Substring matches like `grep "sb-commit.sh T-42" …` must NOT update state.
# Use the shared classifier to require sb-commit.sh be the actual command being
# executed (after stripping env-vars and command modifiers).
if ! cmd_is_sb_commit_invocation "$cmd"; then
  exit 0
fi

# Scope task-id extraction to the sb-commit sub-command, not the whole compound.
# Caught by codex review: `cd /tmp/T-99 && bash sb-commit.sh T-42` formerly
# greped the entire compound and matched T-99, recording the attempt against
# the wrong task. This mirrors the same fix the codex hooks got earlier.
#
# Split on shell connectives (&&, ||, ;, |) and find the first sub-command
# whose stripped binary is sb-commit.sh.
sb_sub=""
splits="$(printf '%s\n' "$cmd" | sed -E 's/(\|\||&&|;|\|)/\n/g')"
while IFS= read -r sub; do
  [[ -z "${sub//[[:space:]]/}" ]] && continue
  stripped="$(echo "$sub" | sed -E 's/^[[:space:]]+//')"
  prev=""
  while [[ "$prev" != "$stripped" ]]; do
    prev="$stripped"
    stripped="$(echo "$stripped" | sed -E 's/^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]* +//')"
    stripped="$(echo "$stripped" | sed -E 's/^(sudo|env|nice|nohup|time|timeout[[:space:]]+[0-9]+[smhd]?|bash|sh|zsh)[[:space:]]+//')"
  done
  first="$(echo "$stripped" | awk '{print $1}')"
  if [[ "${first##*/}" == "sb-commit.sh" ]]; then
    sb_sub="$sub"
    break
  fi
done <<<"$splits"

tid="$(echo "$sb_sub" | grep -oE 'T-[0-9]+' | head -1 || true)"
[[ -z "$tid" ]] && exit 0

# Claude Code's Bash tool_response surface varies — exit_code may be absent;
# is_error/stderr are alternative failure signals. Treat the run as FAILURE
# unless we have positive evidence of success (exit_code==0 AND no is_error).
# Defaulting to "pass" when exit_code is missing would silently let failed
# sb-commit attempts be recorded as passes, breaking loop-cap escalation.
is_error="$(echo "$input" | jq -r '.tool_response.is_error // false')"
exit_code_raw="$(echo "$input" | jq -r '.tool_response.exit_code // null')"
stderr="$(echo "$input" | jq -r '.tool_response.stderr // empty')"
tier="$(state_read ".tasks[\"$tid\"].tier // \"sonnet\"")"

outcome=fail
if [[ "$is_error" != "true" ]]; then
  if [[ "$exit_code_raw" == "0" ]]; then
    outcome=pass
  elif [[ "$exit_code_raw" == "null" && -z "$stderr" ]]; then
    # No exit code and no stderr — treat as success only when payload genuinely
    # lacks any failure signal. Verbose? Yes. Better than silent false-positives.
    outcome=pass
  fi
fi

if [[ "$outcome" == "pass" ]]; then
  state_record_attempt "$tid" "$tier" pass
else
  reason="$(echo "$input" | jq -r '.tool_response.stderr // .tool_response.stdout // .tool_response.output // ""' | tr '\n' ' ' | cut -c1-200)"
  [[ -z "$reason" ]] && reason="sb-commit failed (no detail in tool_response)"
  state_record_attempt "$tid" "$tier" fail "$reason"
fi
exit 0
