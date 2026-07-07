# worktree.Dockerfile — reference base image for a per-worktree Claude sandbox.
#
# This image is the box Claude Code runs *inside* (one container per worktree).
# It carries the toolchain + Claude CLI; the worktree's source is bind-mounted in
# at run time (see docker/worktree-up.sh), never COPYed into the image.
#
# Customize the "project toolchain" layer for your stack (pnpm, python, go, etc.).
# Keep secrets OUT of this file — they are passed at `docker run` time only.

FROM node:20-bookworm-slim

# ── System tools the toolkit + git workflow rely on ───────────────────────────
# git: worktree operations.  gh: PR/issue automation.  ripgrep: fast search.
# curl -o (not `| dd`): inside `sh -c` there is no pipefail, so a failed
# download through a pipe would write an empty keyring and only blow up at the
# second apt-get update with a misleading signature error.
RUN apt-get update && apt-get install -y --no-install-recommends \
      git ca-certificates curl gnupg ripgrep less openssh-client jq \
 && curl -fsSL -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
      https://cli.github.com/packages/githubcli-archive-keyring.gpg \
 && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# ── Claude Code CLI + the linter the toolkit's hooks call ─────────────────────
RUN npm install -g @anthropic-ai/claude-code oxlint

# ── Project toolchain (CUSTOMIZE ME) ──────────────────────────────────────────
# Add the runtimes/package managers your project needs, e.g.:
#   RUN corepack enable && corepack prepare pnpm@latest --activate
#   RUN apt-get update && apt-get install -y python3 python3-pip && rm -rf /var/lib/apt/lists/*

# ── Entrypoint + non-root user ────────────────────────────────────────────────
# Trust bind-mounted worktrees at the SYSTEM level (/etc/gitconfig) at build
# time. Doing this in the entrypoint instead (git config --global) breaks when
# ~/.gitconfig is a read-only bind mount: git can't rename its lockfile over
# the mount and the container dies before Claude ever starts.
#
# Reuse the base image's `node` user (UID 1000) rather than adding a new one:
# a fresh useradd would get UID 1001, which mismatches the typical Linux host
# UID (1000) and makes every bind-mounted worktree file read-only in practice.
COPY entrypoint.sh /usr/local/bin/cdt-entrypoint
RUN chmod +x /usr/local/bin/cdt-entrypoint \
 && git config --system --add safe.directory '*'

USER node
WORKDIR /home/node

# entrypoint trusts the mounted worktree, verifies git resolved, then runs Claude
ENTRYPOINT ["/usr/local/bin/cdt-entrypoint"]
