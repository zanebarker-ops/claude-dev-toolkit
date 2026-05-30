#!/usr/bin/env bash
# worktree-down.sh — tear down a per-worktree sandbox: stop+remove the container,
# then remove the git worktree (which fires the toolkit's post-worktree-cleanup
# hook to close the GH issue and sync remaining worktrees).
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

# ── 1. Stop + remove the container ────────────────────────────────────────────
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  docker rm -f "$CONTAINER" >/dev/null
  echo "✓ Container removed: $CONTAINER"
else
  echo "• No container named $CONTAINER"
fi

# ── 2. Remove the worktree (fires post-worktree-cleanup.sh) ───────────────────
if [ -d "$WT_PATH" ]; then
  RM_FLAGS=()
  [ "$FORCE" = 1 ] && RM_FLAGS=(--force)
  git -C "$MAIN_REPO" worktree remove "${RM_FLAGS[@]}" "$WT_PATH"
  echo "✓ Worktree removed: $WT_PATH"
else
  echo "• No worktree at $WT_PATH"
fi
git -C "$MAIN_REPO" worktree prune

# ── 3. Optionally delete the local feature branch ─────────────────────────────
if [ "$KEEP_BRANCH" = 0 ] && git -C "$MAIN_REPO" show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  git -C "$MAIN_REPO" branch -D "$BRANCH" && echo "✓ Local branch deleted: $BRANCH"
fi
