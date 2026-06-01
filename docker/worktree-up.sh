#!/usr/bin/env bash
# worktree-up.sh — create a git worktree (branched from main) AND start a Docker
# container with Claude Code running *inside* it. One container per worktree.
#
# This is the "wrapper command" trigger model: you call this instead of raw
# `git worktree add`. See docs/docker-worktree-architecture.md for the why.
#
# Usage:
#   docker/worktree-up.sh GH-123-dark-mode
#   docker/worktree-up.sh GH-123-dark-mode -- bash      # run a shell instead of Claude
#
# Required env (passed into the container, never baked into the image):
#   ANTHROPIC_API_KEY   — for Claude Code
#   GH_TOKEN            — for gh (PRs/issues); optional but recommended
#
# Optional env:
#   CDT_WT_IMAGE   (default: cdt-worktree:latest)  image tag to build/use
#   CDT_BASE_BRANCH(default: main)                 branch to fork the worktree from
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Args ──────────────────────────────────────────────────────────────────────
NAME="${1:-}"
if [ -z "$NAME" ]; then
  echo "usage: worktree-up.sh GH-<issue>-<kebab-desc> [-- <command>]" >&2
  exit 2
fi
shift
# Anything after a literal `--` is the command to run in the container.
EXTRA_CMD=()
if [ "${1:-}" = "--" ]; then shift; EXTRA_CMD=("$@"); fi

# Enforce the toolkit's worktree naming convention (matches enforce-worktree-path.sh).
if ! printf '%s' "$NAME" | grep -qE '^GH-[0-9]+-[a-z0-9][a-z0-9-]*$'; then
  echo "Invalid name: '$NAME'. Expected GH-<issue>-<kebab-desc>, e.g. GH-123-dark-mode" >&2
  exit 2
fi

IMAGE="${CDT_WT_IMAGE:-cdt-worktree:latest}"
BASE_BRANCH="${CDT_BASE_BRANCH:-main}"

# ── Resolve repo layout (run this from inside the main repo or any worktree) ───
MAIN_REPO="$(git worktree list --porcelain | head -1 | sed 's/^worktree //')"
MAIN_REPO="$(cd "$MAIN_REPO" && pwd)"
PROJECT="$(basename "$MAIN_REPO")"
WORKTREES_DIR="$(dirname "$MAIN_REPO")/${PROJECT}-worktrees"
WT_PATH="${WORKTREES_DIR}/${NAME}"
CONTAINER="cdt-${PROJECT}-${NAME}"

# ── 1. Create the worktree on the HOST, branched from main ────────────────────
if [ -d "$WT_PATH" ]; then
  echo "• Worktree already exists, reusing: $WT_PATH"
else
  git -C "$MAIN_REPO" fetch origin "$BASE_BRANCH" --quiet || true
  git -C "$MAIN_REPO" worktree add "$WT_PATH" -b "feature/${NAME}" "$BASE_BRANCH"
  echo "✓ Worktree created: $WT_PATH (feature/${NAME} off ${BASE_BRANCH})"
fi

# The shared object store / refs live here. For a worktree this is <main>/.git;
# both the worktree dir and this dir must be mounted at IDENTICAL absolute paths
# so the worktree's `.git` gitdir pointer resolves inside the container.
COMMON_GIT="$(cd "$(git -C "$WT_PATH" rev-parse --git-common-dir)" && pwd)"

# ── 2. Build the image if it isn't present ────────────────────────────────────
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "• Building image $IMAGE ..."
  docker build -f "${SCRIPT_DIR}/worktree.Dockerfile" -t "$IMAGE" "$SCRIPT_DIR"
fi

# ── 3. Start (or re-attach) the container ─────────────────────────────────────
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "• Re-attaching existing container: $CONTAINER"
  docker start -ai "$CONTAINER"
  exit $?
fi

# Warn (don't block) on missing auth — Claude/gh will degrade without them.
[ -n "${ANTHROPIC_API_KEY:-}" ] || echo "⚠ ANTHROPIC_API_KEY is not set; Claude won't authenticate." >&2
[ -n "${GH_TOKEN:-}" ]          || echo "⚠ GH_TOKEN is not set; gh PR/issue commands will be unauthenticated." >&2

GITCONFIG_MOUNT=()
[ -f "${HOME}/.gitconfig" ] && GITCONFIG_MOUNT=(-v "${HOME}/.gitconfig:/home/dev/.gitconfig:ro")

echo "✓ Starting container $CONTAINER (Claude runs inside it)"
exec docker run -it --name "$CONTAINER" \
  -v "${WT_PATH}:${WT_PATH}" \
  -v "${COMMON_GIT}:${COMMON_GIT}" \
  -w "${WT_PATH}" \
  -e ANTHROPIC_API_KEY \
  -e GH_TOKEN \
  "${GITCONFIG_MOUNT[@]}" \
  "$IMAGE" "${EXTRA_CMD[@]}"
