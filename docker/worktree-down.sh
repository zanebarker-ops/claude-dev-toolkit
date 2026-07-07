#!/usr/bin/env bash
# worktree-down.sh — tear down a per-worktree sandbox: stop+remove the container,
# then remove the git worktree.
#
# NOTE: the toolkit's post-worktree-cleanup.sh is a Claude Code PostToolUse hook —
# it only fires when CLAUDE runs `git worktree remove` through the Bash tool.
# This script runs on the host shell, so no hook fires automatically; instead it
# invokes the cleanup script directly if the project has it installed.
#
# Usage:
#   docker/worktree-down.sh GH-123-dark-mode
#   docker/worktree-down.sh GH-123-dark-mode --keep-branch   # don't delete the local branch
#
# Note: removing a worktree with uncommitted changes will fail by design — commit
# or push first. Use --force only if you are certain you want to discard work.
set -euo pipefail

NAME="${1:-}"
if [ -z "$NAME" ]; then
  echo "usage: worktree-down.sh GH-<issue>-<kebab-desc> [--keep-branch] [--force]" >&2
  exit 2
fi
shift
# Same naming convention as worktree-up.sh — rejects malformed names (e.g. with
# `/` or `..`) that would compute an out-of-tree WT_PATH/branch/container name.
if ! printf '%s' "$NAME" | grep -qE '^GH-[0-9]+-[a-z0-9][a-z0-9-]*$'; then
  echo "Invalid name: '$NAME'. Expected GH-<issue>-<kebab-desc>, e.g. GH-123-dark-mode" >&2
  exit 2
fi
KEEP_BRANCH=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --keep-branch) KEEP_BRANCH=1 ;;
    --force)       FORCE=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

MAIN_REPO="$(git worktree list --porcelain | head -1 | sed 's/^worktree //')"
MAIN_REPO="$(cd "$MAIN_REPO" && pwd)"
PROJECT="$(basename "$MAIN_REPO")"
WORKTREES_DIR="$(dirname "$MAIN_REPO")/${PROJECT}-worktrees"
WT_PATH="${WORKTREES_DIR}/${NAME}"
CONTAINER="cdt-${PROJECT}-${NAME}"
BRANCH="feature/${NAME}"

# ── 1. Refuse to destroy anything while the worktree is dirty ─────────────────
# The container (session state, shell history) is removed before the worktree,
# so the dirty check must run FIRST — otherwise `git worktree remove` fails as
# promised, but only after the container is already gone.
if [ "$FORCE" = 0 ] && [ -d "$WT_PATH" ] && [ -n "$(git -C "$WT_PATH" status --porcelain 2>/dev/null)" ]; then
  echo "✗ Worktree has uncommitted changes: $WT_PATH" >&2
  echo "  Commit/push them first, or pass --force to discard them." >&2
  exit 1
fi

# ── 2. Stop + remove the container ────────────────────────────────────────────
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  docker rm -f "$CONTAINER" >/dev/null
  echo "✓ Container removed: $CONTAINER"
else
  echo "• No container named $CONTAINER"
fi

# ── 3. Remove the worktree ────────────────────────────────────────────────────
if [ -d "$WT_PATH" ]; then
  RM_FLAGS=()
  [ "$FORCE" = 1 ] && RM_FLAGS=(--force)
  git -C "$MAIN_REPO" worktree remove ${RM_FLAGS[@]+"${RM_FLAGS[@]}"} "$WT_PATH"
  echo "✓ Worktree removed: $WT_PATH"
else
  echo "• No worktree at $WT_PATH"
fi
git -C "$MAIN_REPO" worktree prune

# ── 4. Optionally delete the local feature branch ─────────────────────────────
if [ "$KEEP_BRANCH" = 0 ] && git -C "$MAIN_REPO" show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  # -d refuses to drop unmerged work; only --force escalates to -D.
  DEL_FLAG="-d"
  [ "$FORCE" = 1 ] && DEL_FLAG="-D"
  if git -C "$MAIN_REPO" branch "$DEL_FLAG" "$BRANCH" 2>/dev/null; then
    echo "✓ Local branch deleted: $BRANCH"
  else
    echo "• Branch $BRANCH is not fully merged — kept. Delete with --force or:" >&2
    echo "    git -C \"$MAIN_REPO\" branch -D $BRANCH" >&2
  fi
fi

# ── 5. Run the toolkit's post-worktree cleanup (close GH issue, sync others) ──
CLEANUP_HOOK="$MAIN_REPO/.claude/hooks/post-worktree-cleanup.sh"
if [ -x "$CLEANUP_HOOK" ]; then
  printf '{"tool_input":{"command":"git worktree remove %s"}}' "$WT_PATH" \
    | (cd "$MAIN_REPO" && "$CLEANUP_HOOK") || true
else
  echo "• Reminder: close the GitHub issue for ${NAME} (no cleanup hook installed)."
fi
