#!/usr/bin/env bash
# cdt-entrypoint — runs as PID 1 inside a per-worktree Claude sandbox container.
#
# Responsibilities:
#   1. Trust the bind-mounted worktree (host/container UID usually differ).
#   2. Verify the worktree's git metadata resolved through the mounts — this is
#      the #1 thing that breaks if worktree-up.sh mounted the wrong paths.
#   3. Hand off to Claude Code (or whatever command was passed).
set -euo pipefail

# A worktree's .git is a FILE pointing at <main>/.git/worktrees/<name>, and the
# files are owned by the host UID. Trust everything we were given so git doesn't
# refuse with "detected dubious ownership".
git config --global --add safe.directory '*'

# Sanity check: are we actually inside a resolvable work tree?
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "✓ git OK — $(git rev-parse --abbrev-ref HEAD) @ $(pwd)" >&2
else
  echo "" >&2
  echo "⚠ Not inside a resolvable git work tree." >&2
  echo "  The worktree's .git pointer did not resolve. Confirm worktree-up.sh" >&2
  echo "  mounted BOTH the worktree dir AND the shared .git at identical" >&2
  echo "  absolute paths. See docs/docker-worktree-architecture.md." >&2
  echo "" >&2
fi

# gh reads GH_TOKEN from the environment automatically; nothing to do here.

# Hand off. Default: launch Claude. Override by passing a command to `docker run`.
if [ "$#" -gt 0 ]; then
  exec "$@"
else
  exec claude --dangerously-skip-permissions
fi
