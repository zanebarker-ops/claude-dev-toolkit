#!/usr/bin/env bash
# dynamic-round-cap.sh — recommend a Codex review round cap based on diff size.
#
# Heuristic (from the design ADR § "Convergence learnings from the spike"):
#
#   net-new files present     → 20 rounds  (greenfield code took 20 rounds to
#                                           converge during the spike; bounded
#                                           effort prevents runaway)
#   diff-lines ≤ 10           → 3 rounds   (small surgical change — typical of
#                                           the original spike-design cap)
#   diff-lines ≤ 100          → 7 rounds   (moderate refactor)
#   diff-lines > 100          → 20 rounds  (large change with substantial
#                                           review surface)
#
# Net-new-files dominates: even a tiny new-file diff still gets the 20-round
# budget because the reviewer has to inspect the file's entire contract, not
# just the changed lines.
#
# This script is consulted by the lead Claude session before invoking the
# Codex final-gate review. The cap is a recommendation, not an enforced floor
# (which would be the budget cap in pre-codex-budget-cap.sh).
#
# Usage:
#   dynamic-round-cap.sh --diff-lines N --net-new-files N
#   dynamic-round-cap.sh --from-git [--base BRANCH]
#
# --from-git computes both values from `git diff --stat --diff-filter=...`
# against the given base (default: dev).
#
# Output: a single integer to stdout. Exit codes:
#   0   ok
#   2   usage error (missing/invalid args)
#   3   git query failed (--from-git mode only)

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage:
  dynamic-round-cap.sh --diff-lines N --net-new-files N
  dynamic-round-cap.sh --from-git [--base BRANCH]
USAGE
  exit 2
}

diff_lines=""
net_new=""
from_git=0
base="dev"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --diff-lines)    diff_lines="${2:-}"; shift 2 ;;
    --net-new-files) net_new="${2:-}"; shift 2 ;;
    --from-git)      from_git=1; shift ;;
    --base)          base="${2:-}"; shift 2 ;;
    -h|--help)       usage ;;
    *)               echo "unknown arg: $1" >&2; usage ;;
  esac
done

if (( from_git == 1 )); then
  if [[ -n "$diff_lines" || -n "$net_new" ]]; then
    echo "--from-git cannot be combined with --diff-lines / --net-new-files" >&2
    usage
  fi
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "not in a git repo" >&2
    exit 3
  fi
  if ! git rev-parse --verify "$base" > /dev/null 2>&1; then
    echo "base ref '$base' not found" >&2
    exit 3
  fi
  # Count added+deleted lines across all changed files vs base.
  diff_lines="$(git diff --shortstat "$base"...HEAD 2>/dev/null |
    awk '{ ins=0; del=0; for (i=1;i<=NF;i++) { if ($i ~ /insertion/) ins=$(i-1); if ($i ~ /deletion/) del=$(i-1) } print ins+del }')"
  [[ -z "$diff_lines" ]] && diff_lines=0
  # Count files added (filter=A only) vs base.
  net_new="$(git diff --name-only --diff-filter=A "$base"...HEAD 2>/dev/null | wc -l)"
fi

# Validate.
if [[ -z "$diff_lines" || -z "$net_new" ]]; then
  echo "must supply both --diff-lines and --net-new-files (or use --from-git)" >&2
  usage
fi
if ! [[ "$diff_lines" =~ ^[0-9]+$ ]]; then
  echo "--diff-lines must be a non-negative integer (got: $diff_lines)" >&2
  exit 2
fi
if ! [[ "$net_new" =~ ^[0-9]+$ ]]; then
  echo "--net-new-files must be a non-negative integer (got: $net_new)" >&2
  exit 2
fi

# Apply heuristic. net-new dominates.
if (( net_new > 0 )); then
  echo 20
elif (( diff_lines <= 10 )); then
  echo 3
elif (( diff_lines <= 100 )); then
  echo 7
else
  echo 20
fi
