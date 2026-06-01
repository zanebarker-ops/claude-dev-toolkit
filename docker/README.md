# Docker-per-Worktree Sandboxes

One Docker container per git worktree, with **Claude Code running inside the
container**. The container is the isolation boundary — a session can only see and
edit its own worktree.

Full design: [`../docs/docker-worktree-architecture.md`](../docs/docker-worktree-architecture.md).

## Files

| File | Role |
|---|---|
| `worktree.Dockerfile` | Base image: git, gh, ripgrep, Node, Claude Code CLI, oxlint. Customize the toolchain layer for your stack. |
| `entrypoint.sh` | Trusts the mounted worktree, verifies git resolved, launches Claude. |
| `worktree-up.sh` | Create a worktree (off `main`) + start its container. |
| `worktree-down.sh` | Remove the container + the worktree (fires the cleanup hook). |

## Prerequisites

- **Docker** — Docker Desktop (Windows/macOS, WSL2 backend on Windows) or Docker
  Engine (Linux).
- **Bash** — Git Bash or WSL on Windows.
- A repo using the toolkit's layout: `<project>/` with a sibling
  `<project>-worktrees/`.
- Host environment variables:
  ```bash
  export ANTHROPIC_API_KEY=sk-ant-...     # required (Claude)
  export GH_TOKEN=ghp_...                 # optional (authenticated gh)
  ```

## Quickstart

From inside your main repo (or any worktree):

```bash
# Spin up an isolated sandbox for issue GH-123 (Claude launches inside it)
docker/worktree-up.sh GH-123-dark-mode

# …work the issue inside the container; commit/push as normal…

# Need a shell instead of Claude?
docker/worktree-up.sh GH-123-dark-mode -- bash

# When done (after the PR merges): remove container + worktree + local branch
docker/worktree-down.sh GH-123-dark-mode
```

## Configuration

| Env var | Default | Purpose |
|---|---|---|
| `CDT_WT_IMAGE` | `cdt-worktree:latest` | Image tag to build/use. |
| `CDT_BASE_BRANCH` | `main` | Branch the worktree is forked from. |

## Notes

- Secrets are passed at `docker run` time, never baked into the image — don't
  `COPY` a `.env` or token into the Dockerfile.
- On Linux you may hit a UID mismatch on the bind-mounted files; see the
  *Known caveats* section of the architecture doc.
- The first `worktree-up.sh` builds the image (cached thereafter).
