#!/bin/bash
# migrate-to-ext4.sh - Move repos from NTFS (/mnt/c/) to WSL-native ext4 (~/repos/)
#
# Usage:
#   scripts/migrate-to-ext4.sh /mnt/c/repos/my-project ~/repos/my-project
#   scripts/migrate-to-ext4.sh --all /mnt/c/repos/github ~/repos
#   scripts/migrate-to-ext4.sh --check                                  # Dry run
#
# Why: Files on /mnt/c/ cross the 9P protocol bridge (WSL <-> NTFS), making
# git, npm, and Claude Code 5-10x slower. Moving to ~/repos/ (ext4) eliminates
# the bridge entirely. VS Code still works via the WSL extension.

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1" >&2; }
section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# Directories to exclude from rsync (regeneratable artifacts)
EXCLUDES=(
  'node_modules'
  '.next'
  '.turbo'
  'dist'
  '.cache'
  '__pycache__'
  '.venv'
  'target'         # Rust
  'vendor'         # Go (if using vendor mode)
)

build_exclude_args() {
  local args=""
  for exc in "${EXCLUDES[@]}"; do
    args="$args --exclude=$exc"
  done
  echo "$args"
}

check_disk_space() {
  local src="$1"
  local dest_mount
  dest_mount=$(df --output=target "$HOME" | tail -1)

  local src_size
  src_size=$(du -sm "$src" --exclude='node_modules' --exclude='.next' --exclude='.turbo' --exclude='dist' 2>/dev/null | awk '{print $1}')
  local dest_avail
  dest_avail=$(df -BM --output=avail "$dest_mount" | tail -1 | tr -d ' M')

  if [ "$src_size" -gt "$dest_avail" ]; then
    error "Not enough space on ext4. Need ${src_size}M, have ${dest_avail}M"
    return 1
  fi
  info "Disk space OK: need ~${src_size}M, have ${dest_avail}M available on ext4"
}

migrate_one() {
  local src="$1"
  local dest="$2"

  if [ ! -d "$src/.git" ]; then
    error "$src is not a git repository"
    return 1
  fi

  if [ -d "$dest" ]; then
    error "$dest already exists. Remove it first or choose a different target."
    return 1
  fi

  local name
  name=$(basename "$src")

  section "Migrating: $name"
  echo "  From: $src"
  echo "  To:   $dest"

  # Step 1: Check disk space
  check_disk_space "$src"

  # Step 2: Document dirty state
  local dirty
  dirty=$(git -C "$src" status --porcelain 2>/dev/null | wc -l)
  local stashes
  stashes=$(git -C "$src" stash list 2>/dev/null | wc -l)
  if [ "$dirty" -gt 0 ] || [ "$stashes" -gt 0 ]; then
    warn "$name has $dirty uncommitted changes and $stashes stashes (they will be preserved)"
  fi

  # Step 3: Copy
  echo ""
  echo "Copying (excluding node_modules, .next, .turbo, dist)..."
  # shellcheck disable=SC2046
  rsync -a --progress $(build_exclude_args) "$src/" "$dest/"
  info "Copy complete"

  # Step 4: Verify
  local orig_branch
  orig_branch=$(git -C "$src" branch --show-current 2>/dev/null || echo "detached")
  local new_branch
  new_branch=$(git -C "$dest" branch --show-current 2>/dev/null || echo "detached")
  local orig_remote
  orig_remote=$(git -C "$src" remote get-url origin 2>/dev/null || echo "none")
  local new_remote
  new_remote=$(git -C "$dest" remote get-url origin 2>/dev/null || echo "none")

  if [ "$orig_branch" != "$new_branch" ]; then
    error "Branch mismatch: src=$orig_branch, dest=$new_branch"
    return 1
  fi
  if [ "$orig_remote" != "$new_remote" ]; then
    error "Remote mismatch: src=$orig_remote, dest=$new_remote"
    return 1
  fi
  info "Verified: branch=$new_branch remote=$new_remote"

  # Step 5: Prune stale worktree registrations
  local pruned
  pruned=$(git -C "$dest" worktree prune 2>&1 || true)
  if [ -n "$pruned" ]; then
    info "Pruned stale worktree registrations"
  fi

  # Step 6: Speed comparison
  section "Speed Comparison: $name"
  echo ""
  echo "--- ext4 (new) ---"
  time git -C "$dest" status > /dev/null 2>&1
  echo ""
  echo "--- NTFS/9P (old) ---"
  time git -C "$src" status > /dev/null 2>&1
  echo ""

  # Step 7: Next steps
  section "Next Steps for $name"
  echo ""
  echo "  1. Reinstall dependencies:"
  echo "     cd $dest && npm install  # or pnpm install, yarn"
  echo ""
  echo "  2. Open in VS Code:"
  echo "     code $dest"
  echo ""
  echo "  3. Create worktree directory:"
  echo "     mkdir -p ${dest}-worktrees"
  echo ""
  echo "  4. Migrate Claude Code project settings (if any):"
  local old_key
  old_key=$(echo "$src" | sed 's|/|-|g; s|^-||')
  local new_key
  new_key=$(echo "$dest" | sed 's|/|-|g; s|^-||')
  echo "     OLD=\"\$HOME/.claude/projects/$old_key\""
  echo "     NEW=\"\$HOME/.claude/projects/$new_key\""
  echo "     [ -d \"\$OLD\" ] && mkdir -p \"\$NEW\" && cp -a \"\$OLD\"/* \"\$NEW\"/"
  echo ""
  echo "  5. After 1-2 weeks stable, clean up old copy:"
  echo "     rm -rf $src"
  echo ""

  info "Migration complete: $name"
}

migrate_all() {
  local src_dir="$1"
  local dest_dir="$2"

  if [ ! -d "$src_dir" ]; then
    error "Source directory not found: $src_dir"
    exit 1
  fi

  mkdir -p "$dest_dir"

  local count=0
  local failed=0

  for repo in "$src_dir"/*/; do
    [ -d "$repo/.git" ] || continue
    local name
    name=$(basename "$repo")

    if [ -d "$dest_dir/$name" ]; then
      warn "Skipping $name — already exists at $dest_dir/$name"
      continue
    fi

    if migrate_one "$repo" "$dest_dir/$name"; then
      count=$((count + 1))
    else
      failed=$((failed + 1))
    fi
  done

  echo ""
  section "Bulk Migration Summary"
  info "Migrated: $count repos"
  [ "$failed" -gt 0 ] && error "Failed: $failed repos"
  echo ""
}

# --- Main ---

if [ $# -eq 0 ]; then
  echo "Usage:"
  echo "  scripts/migrate-to-ext4.sh <source> <destination>"
  echo "  scripts/migrate-to-ext4.sh --all <source-dir> <dest-dir>"
  echo "  scripts/migrate-to-ext4.sh --check <source>"
  echo ""
  echo "Examples:"
  echo "  scripts/migrate-to-ext4.sh /mnt/c/repos/my-project ~/repos/my-project"
  echo "  scripts/migrate-to-ext4.sh --all /mnt/c/repos/github ~/repos"
  echo "  scripts/migrate-to-ext4.sh --check /mnt/c/repos/my-project"
  exit 0
fi

case "${1:-}" in
  --all)
    [ $# -lt 3 ] && { error "Usage: migrate-to-ext4.sh --all <source-dir> <dest-dir>"; exit 1; }
    migrate_all "$2" "$3"
    ;;
  --check)
    [ $# -lt 2 ] && { error "Usage: migrate-to-ext4.sh --check <source>"; exit 1; }
    src="$2"
    if [ ! -d "$src/.git" ]; then
      error "$src is not a git repository"
      exit 1
    fi
    check_disk_space "$src"
    dirty=$(git -C "$src" status --porcelain 2>/dev/null | wc -l)
    stashes=$(git -C "$src" stash list 2>/dev/null | wc -l)
    branch=$(git -C "$src" branch --show-current 2>/dev/null || echo "detached")
    remote=$(git -C "$src" remote get-url origin 2>/dev/null || echo "none")
    echo ""
    echo "  Repo:     $(basename "$src")"
    echo "  Branch:   $branch"
    echo "  Remote:   $remote"
    echo "  Dirty:    $dirty files"
    echo "  Stashes:  $stashes"
    echo ""
    info "Ready to migrate"
    ;;
  *)
    [ $# -lt 2 ] && { error "Usage: migrate-to-ext4.sh <source> <destination>"; exit 1; }
    migrate_one "$1" "$2"
    ;;
esac
