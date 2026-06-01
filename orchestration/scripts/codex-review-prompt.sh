#!/usr/bin/env bash
# codex-review-prompt.sh — emit the prompt the lead Claude pipes to Codex for
# the final binding review (Phase 2, the design ADR). Two responsibilities:
#
#   1. Pre-flight checks (cheap, no Codex tokens spent):
#      - HEAD commit MUST carry Reviewed-By: bug-finder, code-reviewer, and
#        security-auditor trailers (convention from this iteration #3601).
#      - If the diff vs base touches schema migrations (active, not archived),
#        the diff MUST also touch docs/architecture/database.md.
#
#   2. Prompt emission: if pre-flight passes, emit instructions for Codex
#      review. The prompt re-iterates the checklist so Codex independently
#      verifies what we already pre-checked locally.
#
# Output (always single-line JSON to stdout):
#   {"verdict": "PROMPT", "prompt": "<instructional text>"}
#   {"verdict": "REDO",   "reason": "<why>", "blocked_by": "preflight"}
#
# Lead Claude workflow:
#   out="$(orchestration/scripts/codex-review-prompt.sh)"
#   verdict="$(echo "$out" | jq -r .verdict)"
#   case "$verdict" in
#     SKIP)   echo "Codex review skipped (kill switch off)"; exit 0 ;;
#     REDO)   reason="$(echo "$out" | jq -r .reason)" ; abort "$reason" ;;
#     PROMPT) prompt="$(echo "$out" | jq -r .prompt) "; codex review --base main <<<"$prompt" ;;
#   esac
#
# Kill switch: CDT_USE_CODEX_REVIEW (default: shadow)
#   off          — emit SKIP verdict immediately (no pre-flight, no Codex)
#   shadow       — pre-flight runs; Codex called but verdict NOT binding (lead may override)
#   binding-main — pre-flight runs; Codex verdict binding ONLY for PRs targeting main
#   binding-all  — pre-flight runs; Codex verdict binding for all PRs
#
# Note: the binding semantics (REDO blocks merge) is a workflow rule enforced
# by the lead, not by this script. This script only short-circuits on `off`.
#
# This script NEVER invokes codex itself. That's the lead's job — keeps the
# script trivially testable without OpenAI auth.
#
# Usage:
#   codex-review-prompt.sh [--base BRANCH]   # base defaults to "main"

set -euo pipefail

base="main"
require_clean_tree=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) base="${2:?}"; shift 2 ;;
    --require-clean-tree) require_clean_tree=1; shift ;;
    -h|--help)
      sed -n '2,42p' "$0" >&2
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

# emit_redo <reason>
emit_redo() {
  local reason="$1"
  jq -nc --arg reason "$reason" '{verdict: "REDO", reason: $reason, blocked_by: "preflight"}'
  exit 0
}

# emit_prompt <prompt-text>
emit_prompt() {
  local prompt="$1"
  jq -nc --arg prompt "$prompt" '{verdict: "PROMPT", prompt: $prompt}'
  exit 0
}

# emit_skip <reason>
#   For CDT_USE_CODEX_REVIEW=off — short-circuits before pre-flight runs.
#   Lead Claude treats SKIP as "no Codex review needed, proceed to merge".
emit_skip() {
  local reason="$1"
  jq -nc --arg reason "$reason" '{verdict: "SKIP", reason: $reason}'
  exit 0
}

# ---- Kill switch: CDT_USE_CODEX_REVIEW=off short-circuits ----
case "${CDT_USE_CODEX_REVIEW:-shadow}" in
  off)
    emit_skip "CDT_USE_CODEX_REVIEW=off — Codex final-gate review disabled"
    ;;
  shadow|binding-main|binding-all)
    ;;  # fall through to pre-flight checks
  *)
    echo "invalid CDT_USE_CODEX_REVIEW='${CDT_USE_CODEX_REVIEW}' (expected: off|shadow|binding-main|binding-all)" >&2
    exit 2
    ;;
esac

# ---- Optional: clean-tree assertion for binding mode ----
# Per finding: binding mode should not be bypass-able
# by uncommitted local edits. Default off (local dev-friendly); binding
# rollouts should pass --require-clean-tree.
if (( require_clean_tree == 1 )); then
  dirty="$(git status --porcelain 2>/dev/null || true)"
  if [[ -n "$dirty" ]]; then
    emit_redo "Uncommitted changes present (--require-clean-tree). Commit or stash before re-running this gate. Dirty files: $(echo "$dirty" | head -5 | tr '\n' '; ')"
  fi
fi

# ---- Pre-flight 1: Reviewed-By trailers on HEAD ----
# CDT_REQUIRED_REVIEWERS is a space-separated list of agent names.
# Default empty = trailer pre-flight is SKIPPED (no required reviewers).
# Example: export CDT_REQUIRED_REVIEWERS="bug-finder code-reviewer security-auditor"
IFS=' ' read -r -a required_agents <<<"${CDT_REQUIRED_REVIEWERS:-}"

# %(trailers:key=Reviewed-By,valueonly=true) emits ONE line per matching trailer
# value (no key, no separator). Empty when none present.
trailers_raw="$(git log -1 --format='%(trailers:key=Reviewed-By,valueonly=true)' HEAD 2>/dev/null || true)"

missing=()
for agent in "${required_agents[@]}"; do
  # `grep -qFx` — fixed-string, whole-line match (anchored). Avoids partial
  # matches like "bug-finder-v2" being accepted for "bug-finder".
  if ! grep -qFx "$agent" <<<"$trailers_raw"; then
    missing+=("$agent")
  fi
done

if (( ${#missing[@]} > 0 )); then
  emit_redo "HEAD commit missing required Reviewed-By trailer(s): ${missing[*]}. Re-invoke the missing review skill(s) and add the trailer(s) to the next commit before re-running this gate."
fi

# ---- Pre-flight 2: ref-arch docs updated when schema migrations changed ----
# Verify the base ref resolves, then list changed files vs base...HEAD.
if ! git rev-parse --verify "$base" >/dev/null 2>&1; then
  emit_redo "base ref '$base' not found — pre-flight cannot determine the PR scope. Set --base correctly or rebase the branch."
fi

diff_files="$(git diff --name-only "$base"...HEAD 2>/dev/null || true)"

has_active_schema_change=0
# CDT_SCHEMA_GLOBS — space-separated bash glob patterns identifying
# SCHEMA-changing files in your repo (e.g. "**/migrations/*.sql").
# Default empty = ref-arch check is skipped entirely.
# CDT_SCHEMA_IGNORE_GLOBS — glob patterns to EXCLUDE (e.g. archived migrations).
IFS=' ' read -r -a schema_globs <<<"${CDT_SCHEMA_GLOBS:-}"
IFS=' ' read -r -a schema_ignore_globs <<<"${CDT_SCHEMA_IGNORE_GLOBS:-}"
if (( ${#schema_globs[@]} > 0 )); then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    ignored=0
    for g in "${schema_ignore_globs[@]}"; do
      [[ -z "$g" ]] && continue
      # shellcheck disable=SC2053
      if [[ "$f" == $g ]]; then ignored=1; break; fi
    done
    (( ignored == 1 )) && continue
    for g in "${schema_globs[@]}"; do
      [[ -z "$g" ]] && continue
      # shellcheck disable=SC2053
      if [[ "$f" == $g ]]; then has_active_schema_change=1; break; fi
    done
  done <<<"$diff_files"
fi

if (( has_active_schema_change == 1 )); then
  # CDT_REFARCH_DOC_PATHS — space-separated list of doc paths that MUST be
  # in the diff when a schema-changing file is present. Default empty = no doc requirement.
  IFS=' ' read -r -a refarch_docs <<<"${CDT_REFARCH_DOC_PATHS:-}"
  if (( ${#refarch_docs[@]} > 0 )); then
    missing_doc=0
    missing_names=""
    for doc in "${refarch_docs[@]}"; do
      [[ -z "$doc" ]] && continue
      doc_escaped="$(printf '%s' "$doc" | sed 's/\./\\./g')"
      if ! grep -qE "(^|/)${doc_escaped}\$" <<<"$diff_files"; then
        missing_doc=1
        missing_names+=" $doc"
      fi
    done
    if (( missing_doc == 1 )); then
      emit_redo "Schema-changing file(s) present in diff vs $base but required ref-arch doc(s) NOT updated:${missing_names}. Update the ref-arch doc(s) to reflect the schema change, then re-run this gate."
    fi
  fi
fi

# ---- All pre-flight passed — emit the Codex review prompt ----
# The prompt text below is the instructions Codex receives. Customize the
# "Project rules" block for your team. Codex itself runs git/env commands to
# inspect what's configured (CDT_REQUIRED_REVIEWERS, CDT_SCHEMA_GLOBS, etc.),
# so no shell interpolation is needed here.
prompt="$(cat <<'PROMPT_EOF'
You are performing the final binding review on this PR before merge.
Your verdict (APPROVE or REDO) is binding — APPROVE merges; REDO returns
the PR to Claude with your feedback.

## Local pre-flight already passed:
- HEAD commit carries the required Reviewed-By trailers (the lead reads
  CDT_REQUIRED_REVIEWERS to know which ones).
- If a schema-changing file is in the diff, the configured ref-arch doc(s)
  were also updated (CDT_SCHEMA_GLOBS + CDT_REFARCH_DOC_PATHS).

## Your review checklist:

1. Trailer verification (independent re-check):
   - Run: git log -1 --format='%(trailers:key=Reviewed-By,valueonly=true)' HEAD
   - Read CDT_REQUIRED_REVIEWERS from env (space-separated agent names).
   - Confirm every agent listed there appears as a Reviewed-By value.
   - If any is missing, emit REDO immediately.

2. Ref-arch doc consistency (only if CDT_SCHEMA_GLOBS is set):
   - List the diff files: git diff --name-only <base>...HEAD
   - If any file matches a CDT_SCHEMA_GLOBS pattern (and not CDT_SCHEMA_IGNORE_GLOBS),
     every doc path in CDT_REFARCH_DOC_PATHS MUST also be in the diff.
   - If not, emit REDO.

3. Independent correctness review:
   - Read the full diff using codex review tooling.
   - Look for bugs Claude's review agents missed.
   - Check for unintended scope expansion ("while I'm here" cleanups
     beyond what the PR description claims).
   - Verify the test plan in the PR body matches what's actually tested.

4. Project rules (customize for your team):
   - Branch-protection rules (no direct commits to protected branches).
   - Database/security rules (RLS, key management, etc.).
   - Code-quality rules (lint, tests, types).

## Output format:

Emit a single-line JSON object to stdout:
  {"verdict": "APPROVE", "summary": "<one-sentence rationale>"}
  {"verdict": "REDO", "reason": "<specific actionable feedback>"}

REDO reasons should be concrete enough for Claude to fix on the next round.
Do NOT request style nits; bound your scope to correctness, security, and
the checklist above.
PROMPT_EOF
)"

emit_prompt "$prompt"
