#!/bin/bash
# lint-changed.sh - Run oxlint on files changed vs base branch
#
# Works from any worktree or the main repo.
# Default: lints only files changed vs base branch (use --all for everything).
#
# Usage:
#   scripts/lint-changed.sh                  # Changed files only (default)
#   scripts/lint-changed.sh --all            # All files
#   scripts/lint-changed.sh --fix            # Auto-fix changed files
#   scripts/lint-changed.sh --all --fix      # Auto-fix all files

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────
# Override these via environment variables or edit directly
BASE_BRANCH="${LINT_BASE_BRANCH:-main}"         # Branch to diff against
SRC_DIR="${LINT_SRC_DIR:-src}"                  # Source directory to lint
FILE_EXTENSIONS="${LINT_EXTENSIONS:-ts,tsx,js,jsx}"  # File extensions to lint

# ─── Parse flags ──────────────────────────────────────────────────────
LINT_ALL=false
LINT_FIX=false
for arg in "$@"; do
  case "$arg" in
    --all) LINT_ALL=true ;;
    --fix) LINT_FIX=true ;;
    *) echo "ERROR: Unknown flag '$arg'. Use --all or --fix." >&2; exit 1 ;;
  esac
done

# ─── Find oxlint ─────────────────────────────────────────────────────
OXLINT_BIN=$(command -v oxlint 2>/dev/null || true)
if [ -z "$OXLINT_BIN" ]; then
  echo "ERROR: oxlint not found. Install: npm install -g oxlint" >&2
  exit 1
fi

# ─── Resolve repo root ───────────────────────────────────────────────
# `|| true` so set -e doesn't kill the script before the friendly error prints
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -z "$REPO_ROOT" ]; then
  echo "ERROR: Not in a git repository" >&2
  exit 1
fi

# ─── Find oxlint config ──────────────────────────────────────────────
# Check current directory, then repo root, then main repo (for worktrees).
# Paths must be ABSOLUTE — we `cd "$REPO_ROOT"` before running oxlint, which
# would break a config resolved relative to the original cwd.
OXLINT_CONFIG=""
for candidate in "$PWD/.oxlintrc.json" "$REPO_ROOT/.oxlintrc.json"; do
  if [ -f "$candidate" ]; then
    OXLINT_CONFIG="$candidate"
    break
  fi
done

# For worktrees, also check main repo root
if [ -z "$OXLINT_CONFIG" ]; then
  MAIN_REPO=$(git worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //')
  if [ -n "$MAIN_REPO" ] && [ -f "$MAIN_REPO/.oxlintrc.json" ]; then
    OXLINT_CONFIG="$MAIN_REPO/.oxlintrc.json"
  fi
fi

OXLINT_ARGS=""
[ -n "$OXLINT_CONFIG" ] && OXLINT_ARGS="--config $OXLINT_CONFIG"
[ "$LINT_FIX" = true ] && OXLINT_ARGS="$OXLINT_ARGS --fix"

# ─── Find source directory ───────────────────────────────────────────
# Try common project structures
SRC_PATH=""
for candidate in "$REPO_ROOT/$SRC_DIR" "$REPO_ROOT/apps/web/$SRC_DIR" "$REPO_ROOT/packages/app/$SRC_DIR"; do
  if [ -d "$candidate" ]; then
    SRC_PATH="$candidate"
    break
  fi
done

if [ -z "$SRC_PATH" ]; then
  SRC_PATH="$REPO_ROOT/$SRC_DIR"
  if [ ! -d "$SRC_PATH" ]; then
    echo "ERROR: Source directory not found. Set LINT_SRC_DIR env var." >&2
    echo "  Tried: $REPO_ROOT/$SRC_DIR" >&2
    exit 1
  fi
fi

# ─── Run lint ─────────────────────────────────────────────────────────
if [ "$LINT_ALL" = true ]; then
  echo "Running oxlint on all files in $(basename "$SRC_PATH")/ ..."
  # shellcheck disable=SC2086
  "$OXLINT_BIN" $OXLINT_ARGS "$SRC_PATH/"
else
  # Get changed files vs base branch
  cd "$REPO_ROOT"

  PATTERN=$(echo "$FILE_EXTENSIONS" | sed 's/,/|/g')
  PATTERN="\\.(${PATTERN})$"

  FILES=$(git diff --name-only --diff-filter=d "${BASE_BRANCH}...HEAD" 2>/dev/null || true)
  WORKING=$(git diff --name-only --diff-filter=d HEAD 2>/dev/null || true)
  STAGED=$(git diff --name-only --diff-filter=d --cached 2>/dev/null || true)

  ALL_FILES=$(printf '%s\n%s\n%s' "$FILES" "$WORKING" "$STAGED" | sort -u | grep -E "$PATTERN" || true)

  # Filter to files that exist and are under src. Array (not a space-joined
  # string) so filenames containing spaces survive; path-PREFIX match (not
  # substring) so e.g. `resources/x.ts` isn't linted when SRC_REL is `src`.
  SRC_REL=$(realpath --relative-to="$REPO_ROOT" "$SRC_PATH" 2>/dev/null || echo "$SRC_DIR")
  VALID_FILES=()
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if [[ "$f" == "$SRC_REL/"* ]] && [ -f "$REPO_ROOT/$f" ]; then
      VALID_FILES+=("$REPO_ROOT/$f")
    fi
  done <<< "$ALL_FILES"

  if [ ${#VALID_FILES[@]} -eq 0 ]; then
    echo "No changed .$FILE_EXTENSIONS files vs $BASE_BRANCH. Nothing to lint."
    exit 0
  fi

  echo "Running oxlint on ${#VALID_FILES[@]} changed file(s)..."

  # shellcheck disable=SC2086
  "$OXLINT_BIN" $OXLINT_ARGS "${VALID_FILES[@]}"
fi
