# Docker-per-Worktree Reference Architecture

> One Docker container per git worktree, with **Claude Code running inside the
> container**. The container is the isolation boundary: a session can only see
> and modify its own worktree.

This document is the reference architecture. The runnable skeleton lives in
[`../docker/`](../docker/): `worktree.Dockerfile`, `entrypoint.sh`,
`worktree-up.sh`, `worktree-down.sh`.

---

## 1. Goals

- **Hard isolation.** Each worktree's work happens in a separate container.
  Claude cannot touch the host, the main repo's working tree, or sibling
  worktrees — not because a hook says so, but because they aren't mounted.
- **Parallelism without collisions.** Run many worktrees at once; each is its
  own container and process tree.
- **Same workflow, stronger walls.** The toolkit's worktree-first, main-only
  branch model is unchanged — the container just enforces the worktree boundary
  structurally.

### Non-goals (this iteration)

- Per-worktree databases / services / port allocation. Containers here are
  **code + runtime + Claude only**. (Layer compose + services on later.)
- Auto-creation via a `git worktree add` hook. Creation is an explicit
  **wrapper command** (`worktree-up.sh`).

These were deliberate decisions — see the [Decision log](#7-decision-log).

---

## 2. The model

```
HOST                                              CONTAINER (one per worktree)
────────────────────────────────────────         ─────────────────────────────
~/repos/myapp/              (main repo, on main)
~/repos/myapp-worktrees/
  GH-123-dark-mode/   ◄───── bind mount ─────►    /…/myapp-worktrees/GH-123-dark-mode  (cwd)
~/repos/myapp/.git/   ◄───── bind mount ─────►    /…/myapp/.git   (shared object store)
                                                  claude  ← runs here
```

`worktree-up.sh GH-123-dark-mode`:
1. On the **host**, `git worktree add` branches `feature/GH-123-dark-mode` from
   `main` into `myapp-worktrees/GH-123-dark-mode`.
2. Builds the image (first run only) and starts a container named
   `cdt-myapp-GH-123-dark-mode`.
3. The container's entrypoint launches `claude` in the worktree directory.

`worktree-down.sh GH-123-dark-mode` removes the container, then the worktree
(which fires the toolkit's existing `post-worktree-cleanup.sh` hook).

---

## 3. The load-bearing detail: how git survives the mount

A git worktree does **not** contain a normal `.git` directory. Its `.git` is a
**file**:

```
$ cat myapp-worktrees/GH-123-dark-mode/.git
gitdir: /home/you/repos/myapp/.git/worktrees/GH-123-dark-mode
```

That is an **absolute path back into the main repo's `.git`**. If git inside the
container can't resolve that path, every git command fails. So:

> **Mount rule:** bind-mount (a) the worktree directory and (b) the shared
> `.git` directory **at identical absolute paths** inside the container.

`worktree-up.sh` does exactly this:

```sh
COMMON_GIT="$(cd "$(git -C "$WT_PATH" rev-parse --git-common-dir)" && pwd)"
docker run ... \
  -v "${WT_PATH}:${WT_PATH}" \          # worktree at its real path
  -v "${COMMON_GIT}:${COMMON_GIT}" \    # shared .git at its real path
  -w "${WT_PATH}" ...
```

Because both paths match the host, the `gitdir:` pointer, the
`worktrees/<name>/commondir` back-reference, and the shared object store all
resolve. Commits write loose objects to the shared `.git/objects` and the
per-worktree refs under `.git/worktrees/<name>/` — both mounted, so commit works.

**Why not mount the whole parent directory?** It's simpler but leaks isolation:
the container would see the main working tree and every sibling worktree. Mounting
only *this* worktree + the shared `.git` keeps the boundary tight while still
letting git function.

---

## 4. Auth & secrets — passed at run time, never baked

Secrets never go in the image. `worktree-up.sh` forwards them to `docker run`:

| What | How | Notes |
|---|---|---|
| `ANTHROPIC_API_KEY` | `-e ANTHROPIC_API_KEY` (pass-through) | Required for Claude. Export it on the host first. |
| `GH_TOKEN` | `-e GH_TOKEN` | `gh` reads it automatically. Optional but needed for PR/issue automation. |
| Git identity | `-v ~/.gitconfig:/home/dev/.gitconfig:ro` | So commits are attributed correctly. |

This matches the toolkit's existing posture (`block-env-read.sh` /
`block-env-modification` rules): credentials are runtime inputs, not artifacts.
Do **not** `COPY` a `.env` or token into the Dockerfile, and don't commit one.

---

## 5. How it composes with the toolkit's hooks

Install the toolkit inside the image (or bake it into the worktree) so hooks run
*inside* the container. Then:

- **`check-worktree.sh`** sees the worktree's `.git` is a *file* → allows edits
  (correct; you're not in the main repo).
- **`check-cross-worktree.sh`** confines edits to the mounted worktree. Since
  nothing else is mounted, cross-worktree mistakes are now *structurally*
  impossible, not just hook-blocked — defense in depth.
- **main-only branch model** is preserved: `worktree-up.sh` branches from `main`,
  and PRs target `main`.

---

## 6. Prerequisites

- **Docker** — Docker Desktop (Windows/macOS) with the WSL2 backend on Windows,
  or Docker Engine on Linux.
- **A git repo** using the toolkit's worktree convention (`<project>/` and a
  sibling `<project>-worktrees/`).
- **Host env:** `ANTHROPIC_API_KEY` exported; `GH_TOKEN` exported if you want
  authenticated `gh`.
- **Bash** to run the wrapper scripts (Git Bash / WSL on Windows).

See [`../docker/README.md`](../docker/README.md) for the copy-paste quickstart.

### Known caveats

- **UID mismatch (Linux hosts).** Bind-mounted files are owned by the host UID;
  the container's `dev` user may differ. The entrypoint runs
  `git config --global --add safe.directory '*'` to avoid git's "dubious
  ownership" refusal. If you hit write-permission errors, run the container with
  `--user "$(id -u):$(id -g)"` (and mount a writable home). Docker Desktop on
  Windows/macOS generally smooths this over via its VM.
- **MCP servers.** Anything Claude reaches over MCP must be reachable from inside
  the container (network or mounted). Interactive-auth MCP servers may need their
  credentials mounted in.

---

## 7. Decision log

| Decision | Chosen | Rejected alternatives & why |
|---|---|---|
| Where Claude runs | **Inside the container** (full sandbox) | *On the host, app-only container* — lighter but no real isolation of Claude; *compose stack with Claude exec-in* — more moving parts than needed now. |
| Creation trigger | **Wrapper command** (`worktree-up.sh`) | *PostToolUse hook on `git worktree add`* — implicit, adds build latency to every worktree add, harder to debug; *`claude-session.sh --docker` flag* — keeps tmux in the loop unnecessarily. |
| Services | **Code/runtime only** | *Per-worktree DB + auto ports* — powerful but needs compose + a port-allocation scheme; deferred until a project needs it. |
| Mount scope | **Worktree + shared `.git` at identical paths** | *Mount the common parent* — simpler but exposes the main tree and sibling worktrees, weakening isolation. |

---

## 8. Extending later

- **Add services:** replace `docker run` with a generated `docker-compose.yml`
  per worktree (app + db + cache), and allocate host ports from the issue number
  (e.g. `3000 + (issue % 1000)`).
- **Auto-trigger:** wrap `git worktree add` with a PostToolUse hook that calls
  `worktree-up.sh` if you prefer implicit creation.
- **Prebuilt images:** push the base image to a registry so first-run builds are
  instant across machines.
