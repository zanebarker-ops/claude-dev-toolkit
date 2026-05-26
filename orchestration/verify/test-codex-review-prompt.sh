#!/usr/bin/env bash
# test-codex-review-prompt.sh — codex-review-prompt.sh regression test.
#
# Exercises codex-review-prompt.sh's two pre-flight checks against synthetic
# git repos so the assertions are isolated from the actual your project branch
# state. Each test sets up a tmp repo with a specific commit/diff shape,
# invokes the script with --base, and asserts on the emitted JSON verdict.
#
# Cases:
#   1. HEAD missing ALL 3 trailers → REDO with all 3 named
#   2. HEAD missing ONE trailer → REDO naming just that one
#   3. HEAD has all 3 trailers, no schema change → PROMPT
#   4. HEAD has all 3 trailers, schema change WITHOUT ref-arch doc → REDO
#   5. HEAD has all 3 trailers, schema change WITH ref-arch doc → PROMPT
#   6. Archived migration in diff doesn't trigger ref-arch check → PROMPT
#   7. Base branch missing → REDO with clear reason
#   8. --help prints usage and exits 0

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SCRIPT="$ROOT/orchestration/scripts/codex-review-prompt.sh"

# Tests use generic agent names + generic schema/doc paths to demonstrate the
# env-driven configuration. Real installations would use their own agent names
# (e.g. "bug-finder code-reviewer security-auditor") and schema globs.
export CDT_REQUIRED_REVIEWERS="agent-a agent-b agent-c"
export CDT_SCHEMA_GLOBS="**/migrations/*.sql"
export CDT_SCHEMA_IGNORE_GLOBS="**/migrations/archive/*.sql"
export CDT_REFARCH_DOC_PATHS="docs/architecture.md"

fail() { printf '\033[31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32m[ OK ]\033[0m %s\n' "$*"; }

# setup_repo <trailers-comma-list> <files-on-base> <files-on-head>
#   Creates a fresh tmp git repo with a `base` branch (initial commit) and a
#   `feature` branch on top with the specified trailers + modified files.
#   files-on-* are space-separated paths; each gets a stub file written.
#   trailers are comma-separated agent names.
setup_repo() {
  local trailers="$1" base_files="$2" head_files="$3"
  local tmp="$(mktemp -d)"
  (
    cd "$tmp"
    git init -q -b base
    git config user.email test@example.com
    git config user.name "Test"
    # Initial commit on base.
    echo "base" > README.md
    for f in $base_files; do
      mkdir -p "$(dirname "$f")"
      echo "// base" > "$f"
    done
    git add -A
    git commit -q -m "base"

    # Feature branch with the head diff.
    git checkout -q -b feature
    for f in $head_files; do
      mkdir -p "$(dirname "$f")"
      echo "// head" > "$f"
    done
    git add -A

    # Build commit message with trailers.
    local msg="feat: test"$'\n'$'\n'"body"
    if [[ -n "$trailers" ]]; then
      msg+=$'\n'
      IFS=, read -r -a tarr <<<"$trailers"
      for t in "${tarr[@]}"; do
        msg+=$'\n'"Reviewed-By: $t"
      done
    fi
    git commit -q -m "$msg"
  )
  echo "$tmp"
}

# run_script <tmp-repo> [extra-args...]
run_script() {
  local tmp="$1"; shift
  (cd "$tmp" && bash "$SCRIPT" --base base "$@") 2>&1
}

# ---- Test 1: missing all 3 trailers ----
tmp1="$(setup_repo "" "" "src/foo.ts")"
out="$(run_script "$tmp1")"
verdict="$(echo "$out" | jq -r .verdict)"
[[ "$verdict" == "REDO" ]] || fail "1: expected REDO, got $verdict ($out)"
reason="$(echo "$out" | jq -r .reason)"
for a in agent-a agent-b agent-c; do
  [[ "$reason" == *"$a"* ]] || fail "1: REDO reason should name '$a'. Got: $reason"
done
rm -rf "$tmp1"
ok "missing all 3 trailers → REDO names all 3 agents"

# ---- Test 2: missing only one trailer ----
tmp2="$(setup_repo "agent-a,agent-b" "" "src/bar.ts")"
out="$(run_script "$tmp2")"
[[ "$(echo "$out" | jq -r .verdict)" == "REDO" ]] || fail "2: expected REDO"
reason="$(echo "$out" | jq -r .reason)"
[[ "$reason" == *"agent-c"* ]] || fail "2: REDO should name 'security-auditor'. Got: $reason"
[[ "$reason" != *"agent-a"* && "$reason" != *"agent-b"* ]] \
  || fail "2: REDO should NOT name present trailers. Got: $reason"
rm -rf "$tmp2"
ok "missing one trailer (agent-c) → REDO names only that one"

# ---- Test 3: all 3 trailers, no schema change → PROMPT ----
tmp3="$(setup_repo "agent-a,agent-b,agent-c" "" "src/baz.ts")"
out="$(run_script "$tmp3")"
[[ "$(echo "$out" | jq -r .verdict)" == "PROMPT" ]] || fail "3: expected PROMPT, got: $out"
prompt="$(echo "$out" | jq -r .prompt)"
[[ "$prompt" == *"final binding review"* ]] || fail "3: prompt should mention 'final binding review'"
[[ "$prompt" == *"REDO"* && "$prompt" == *"APPROVE"* ]] || fail "3: prompt should explain APPROVE/REDO"
rm -rf "$tmp3"
ok "all 3 trailers + no schema change → PROMPT (with checklist)"

# ---- Test 4: schema change WITHOUT ref-arch doc → REDO ----
tmp4="$(setup_repo "agent-a,agent-b,agent-c" "" "db/migrations/20260601_add_table.sql")"
out="$(run_script "$tmp4")"
[[ "$(echo "$out" | jq -r .verdict)" == "REDO" ]] || fail "4: expected REDO, got: $out"
reason="$(echo "$out" | jq -r .reason)"
[[ "$reason" == *"architecture.md"* ]] || fail "4: REDO should name architecture.md. Got: $reason"
rm -rf "$tmp4"
ok "schema change without ref-arch doc → REDO names architecture.md"

# ---- Test 5: schema change WITH ref-arch doc → PROMPT ----
tmp5="$(setup_repo "agent-a,agent-b,agent-c" "" "db/migrations/20260601_add_table.sql docs/architecture.md")"
out="$(run_script "$tmp5")"
[[ "$(echo "$out" | jq -r .verdict)" == "PROMPT" ]] || fail "5: expected PROMPT, got: $out"
rm -rf "$tmp5"
ok "schema change + ref-arch doc updated → PROMPT"

# ---- Test 6: archived migration alone doesn't trigger ref-arch check ----
tmp6="$(setup_repo "agent-a,agent-b,agent-c" "" "db/migrations/archive/001_legacy.sql")"
out="$(run_script "$tmp6")"
[[ "$(echo "$out" | jq -r .verdict)" == "PROMPT" ]] || fail "6: archived migration should NOT trigger ref-arch check, got: $out"
rm -rf "$tmp6"
ok "archive/ migration alone → PROMPT (no ref-arch required)"

# ---- Test 6b: CDT_SCHEMA_IGNORE_GLOBS excludes specific paths ----
# A file path that DOES match CDT_SCHEMA_GLOBS ("**/migrations/*.sql") but
# is also matched by CDT_SCHEMA_IGNORE_GLOBS should NOT trigger the schema
# check. This test sets a one-off IGNORE_GLOB to exclude vendor/ migrations.
tmp6b="$(setup_repo "agent-a,agent-b,agent-c" "" "vendor/db/migrations/20260601_excluded.sql")"
out="$(cd "$tmp6b" && CDT_SCHEMA_IGNORE_GLOBS="vendor/**/migrations/*.sql **/migrations/archive/*.sql" bash "$SCRIPT" --base base 2>&1)"
[[ "$(echo "$out" | jq -r .verdict)" == "PROMPT" ]] || fail "6b: CDT_SCHEMA_IGNORE_GLOBS pattern should exclude vendor/, got: $out"
rm -rf "$tmp6b"
ok "CDT_SCHEMA_IGNORE_GLOBS-matched file → PROMPT (excluded from schema check)"

# ---- Test 7: base branch missing → REDO with clear reason ----
tmp7="$(setup_repo "agent-a,agent-b,agent-c" "" "src/qux.ts")"
out="$(cd "$tmp7" && bash "$SCRIPT" --base does-not-exist 2>&1)"
[[ "$(echo "$out" | jq -r .verdict)" == "REDO" ]] || fail "7: missing base should REDO, got: $out"
reason="$(echo "$out" | jq -r .reason)"
[[ "$reason" == *"base ref"* && "$reason" == *"does-not-exist"* ]] \
  || fail "7: REDO should name missing base ref. Got: $reason"
rm -rf "$tmp7"
ok "missing base branch → REDO names the missing ref"

# ---- Test 8: --help prints usage and exits 0 ----
out="$("$SCRIPT" --help 2>&1)"
rc=$?
[[ "$rc" == "0" ]] || fail "8: --help should exit 0, got $rc"
[[ "$out" == *"codex-review-prompt"* ]] || fail "8: --help should mention script name"
ok "--help prints usage and exits 0"

# ---- Test 9: CDT_USE_CODEX_REVIEW=off → SKIP verdict ----
tmp9="$(setup_repo "" "" "src/whatever.ts")"
out="$(cd "$tmp9" && CDT_USE_CODEX_REVIEW=off bash "$SCRIPT" --base base 2>&1)"
verdict="$(echo "$out" | jq -r .verdict)"
[[ "$verdict" == "SKIP" ]] || fail "9: expected SKIP, got $verdict ($out)"
reason="$(echo "$out" | jq -r .reason)"
[[ "$reason" == *"off"* && "$reason" == *"disabled"* ]] || fail "9: SKIP reason should explain disablement. Got: $reason"
rm -rf "$tmp9"
ok "CDT_USE_CODEX_REVIEW=off → SKIP (short-circuits before pre-flight)"

# ---- Test 10: invalid CDT_USE_CODEX_REVIEW → exit 2 ----
tmp10="$(setup_repo "" "" "src/whatever.ts")"
set +e
out="$(cd "$tmp10" && CDT_USE_CODEX_REVIEW=garbage bash "$SCRIPT" --base base 2>&1)"
rc=$?
set -e
[[ "$rc" == "2" ]] || fail "10: invalid kill switch should exit 2, got $rc"
[[ "$out" == *"invalid CDT_USE_CODEX_REVIEW"* ]] || fail "10: should print invalid-value message. Got: $out"
rm -rf "$tmp10"
ok "invalid CDT_USE_CODEX_REVIEW → exit 2 with clear message"

# ---- Test 11: --require-clean-tree + dirty tree → REDO ----
tmp11="$(setup_repo "agent-a,agent-b,agent-c" "" "src/foo.ts")"
# Make the tree dirty.
(cd "$tmp11" && echo "uncommitted" > src/dirty.ts)
out="$(cd "$tmp11" && bash "$SCRIPT" --base base --require-clean-tree 2>&1)"
[[ "$(echo "$out" | jq -r .verdict)" == "REDO" ]] || fail "11: dirty tree + --require-clean-tree should REDO, got: $out"
reason="$(echo "$out" | jq -r .reason)"
[[ "$reason" == *"Uncommitted changes"* ]] || fail "11: REDO reason should mention 'Uncommitted changes'. Got: $reason"
[[ "$reason" == *"src/dirty.ts"* ]] || fail "11: REDO reason should name the dirty file. Got: $reason"
rm -rf "$tmp11"
ok "--require-clean-tree + dirty tree → REDO names uncommitted files"

# ---- Test 12: --require-clean-tree + clean tree + all trailers → PROMPT ----
tmp12="$(setup_repo "agent-a,agent-b,agent-c" "" "src/bar.ts")"
out="$(cd "$tmp12" && bash "$SCRIPT" --base base --require-clean-tree 2>&1)"
[[ "$(echo "$out" | jq -r .verdict)" == "PROMPT" ]] || fail "12: clean tree should pass through to pre-flight, got: $out"
rm -rf "$tmp12"
ok "--require-clean-tree + clean tree + trailers → PROMPT (pre-flight runs)"

# ---- Test 13: kill switch off WINS over missing trailers (short-circuit first) ----
tmp13="$(setup_repo "" "" "src/baz.ts")"  # no trailers
out="$(cd "$tmp13" && CDT_USE_CODEX_REVIEW=off bash "$SCRIPT" --base base 2>&1)"
[[ "$(echo "$out" | jq -r .verdict)" == "SKIP" ]] || fail "13: off kill switch should win over trailer-missing REDO, got: $out"
rm -rf "$tmp13"
ok "kill switch 'off' short-circuits BEFORE trailer pre-flight (no REDO)"

echo
ok "orchestration/scripts/codex-review-prompt.sh regression: PASS"
