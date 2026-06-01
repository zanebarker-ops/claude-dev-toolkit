#!/bin/bash
# install.sh - Install Claude Dev Toolkit into a target project
#
# Usage:
#   ./install.sh /path/to/your-project
#   ./install.sh .                        # Current directory
#
# What it does:
#   1. Copies hooks     -> .claude/hooks/
#   2. Copies commands  -> .claude/commands/
#   3. Creates settings -> .claude/settings.json (from template, won't overwrite)
#   4. Copies oxlintrc  -> .oxlintrc.json (won't overwrite)
#   5. Copies scripts   -> scripts/ (lint, deploy check, session manager)
#   6. Copies hookify rules -> .claude/ (won't overwrite)
#   7. Copies templates -> .claude/templates/ (reference docs)
#   8. Copies PR review toolkit -> .claude/plugins/pr-review-toolkit/
#   9. Optionally generates CLAUDE.md from template

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1"; }
section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

TOOLKIT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-.}"
TARGET="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"

if [ ! -d "$TARGET" ]; then
  error "Target directory not found: $TARGET"
  exit 1
fi

PROJECT_NAME=$(basename "$TARGET")

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Claude Dev Toolkit Installer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Toolkit:  $TOOLKIT_DIR"
echo "  Target:   $TARGET"
echo "  Project:  $PROJECT_NAME"
echo ""

section "Creating directories"
for dir in .claude/hooks .claude/commands .claude/plugins .claude/templates scripts; do
  mkdir -p "$TARGET/$dir"
  info "$dir/"
done

section "Installing hooks"
# Copy only the hook files (skip README); set executable bit for direct
# invocation by Claude Code (settings.json invokes them as .claude/hooks/foo.sh).
cp "$TOOLKIT_DIR/hooks/"*.sh "$TARGET/.claude/hooks/"
chmod +x "$TARGET/.claude/hooks/"*.sh
hook_count=$(find "$TARGET/.claude/hooks/" -maxdepth 1 -type f ! -name "README.md" | wc -l)
info "Hooks installed to .claude/hooks/ ($hook_count files, all executable)"

section "Installing agent commands"
# cp without -r fails on subdirectories (e.g. commands/ux-hcd-designer/).
# Copy top-level .md files first, then any reference subdirs separately.
cp "$TOOLKIT_DIR/commands/"*.md "$TARGET/.claude/commands/"
for d in "$TOOLKIT_DIR/commands/"*/; do
  [ -d "$d" ] && cp -r "$d" "$TARGET/.claude/commands/"
done
cmd_count=$(find "$TARGET/.claude/commands/" -maxdepth 1 -name "*.md" | wc -l)
info "Commands installed to .claude/commands/ ($cmd_count files)"

section "Installing hookify rules"
RULES_COPIED=0
for rule in "$TOOLKIT_DIR/hookify-rules/"*; do
  dest="$TARGET/.claude/$(basename "$rule")"
  if [ -f "$dest" ]; then
    warn "Skipped (exists): $(basename "$rule")"
  else
    cp "$rule" "$dest"
    info "$(basename "$rule")"
    RULES_COPIED=$((RULES_COPIED + 1))
  fi
done
info "$RULES_COPIED hookify rules installed"

section "Installing PR review toolkit"
cp -r "$TOOLKIT_DIR/plugins/pr-review-toolkit" "$TARGET/.claude/plugins/"
info "PR review toolkit installed to .claude/plugins/pr-review-toolkit/"

section "Installing settings"
SETTINGS_SKIPPED=0
if [ -f "$TARGET/.claude/settings.json" ]; then
  SETTINGS_SKIPPED=1
  cp "$TOOLKIT_DIR/config/settings.json.template" "$TARGET/.claude/templates/"
  error "Did NOT touch existing .claude/settings.json"
  warn "  ┌─────────────────────────────────────────────────────────────────┐"
  warn "  │  ENFORCEMENT IS NOT WIRED.                                       │"
  warn "  │  The hook FILES were installed, but none are registered, so NO  │"
  warn "  │  hooks will run until you merge the 'hooks' block from:          │"
  warn "  │    .claude/templates/settings.json.template                      │"
  warn "  │  into your existing .claude/settings.json.                       │"
  warn "  └─────────────────────────────────────────────────────────────────┘"
else
  cp "$TOOLKIT_DIR/config/settings.json.template" "$TARGET/.claude/settings.json"
  info "Created .claude/settings.json (hooks wired)"
fi

section "Installing lint config"
if [ -f "$TARGET/.oxlintrc.json" ]; then
  warn "Skipped .oxlintrc.json (already exists)"
else
  cp "$TOOLKIT_DIR/config/.oxlintrc.json" "$TARGET/.oxlintrc.json"
  info "Created .oxlintrc.json"
fi

section "Installing scripts"
for script in lint-changed.sh check-deploy.sh claude-session.sh migrate-to-ext4.sh doctor.sh; do
  if [ -f "$TARGET/scripts/$script" ]; then
    warn "Skipped scripts/$script (already exists)"
  else
    cp "$TOOLKIT_DIR/scripts/$script" "$TARGET/scripts/$script"
    chmod +x "$TARGET/scripts/$script"
    info "scripts/$script"
  fi
done

section "Installing templates"
cp "$TOOLKIT_DIR/templates/"*.md "$TARGET/.claude/templates/" 2>/dev/null || true
cp "$TOOLKIT_DIR/templates/"*.template "$TARGET/.claude/templates/" 2>/dev/null || true
info "Templates installed to .claude/templates/"

section "Installing coordination system"
mkdir -p "$TARGET/.claude/coordination"
if [ ! -f "$TARGET/.claude/coordination/state.json" ]; then
  cp "$TOOLKIT_DIR/templates/coordination/state.json" "$TARGET/.claude/coordination/"
  cp "$TOOLKIT_DIR/templates/coordination/README.md" "$TARGET/.claude/coordination/"
  info "Coordination system installed to .claude/coordination/"
else
  warn "Skipped coordination system (state.json already exists)"
fi

section "Installing UX/HCD designer references"
mkdir -p "$TARGET/.claude/commands/ux-hcd-designer/references"
for ref in heuristics.md research-questions.md vocabulary.md; do
  cp "$TOOLKIT_DIR/commands/ux-hcd-designer/references/$ref" "$TARGET/.claude/commands/ux-hcd-designer/references/"
done
info "UX/HCD references installed"

section "CLAUDE.md"
if [ -f "$TARGET/.claude/CLAUDE.md" ] || [ -f "$TARGET/CLAUDE.md" ]; then
  warn "Skipped CLAUDE.md (already exists)"
  warn "  Template available at: .claude/templates/CLAUDE.md.template"
else
  sed "s/\[YOUR_PROJECT_NAME\]/$PROJECT_NAME/g" \
    "$TOOLKIT_DIR/templates/CLAUDE.md.template" > "$TARGET/CLAUDE.md"
  info "Created CLAUDE.md (customize it for your project!)"
fi

section "Checking prerequisites (and the consequence of each gap)"
# State the CONSEQUENCE of a missing tool, not just its absence — hooks that
# depend on a missing tool fail OPEN (skip silently), so a clean-looking install
# can still have inactive enforcement. See README 'Platform support' section.
command -v claude   &>/dev/null && info "claude   — Claude Code CLI present" || error "claude NOT found → the toolkit cannot run. Install: npm install -g @anthropic-ai/claude-code"
command -v git      &>/dev/null && info "git      — present" || error "git NOT found → ALL hooks and the worktree workflow are inoperable."
command -v bash     &>/dev/null && info "bash     — present (hooks can execute)" || error "bash NOT found → NO hooks will run (all hooks are bash). On Windows, use WSL2/Git Bash."
command -v oxlint   &>/dev/null && info "oxlint   — present (lint gate active)" || warn "oxlint NOT found → pre-commit lint gate is INACTIVE (fails open). Install: npm install -g oxlint"
command -v gitleaks &>/dev/null && info "gitleaks — present (secret scan active)" || warn "gitleaks NOT found → secret-scan gate is INACTIVE (fails open). Install: brew install gitleaks"
command -v jq       &>/dev/null && info "jq       — present (crash recovery active)" || warn "jq NOT found → crash-recovery hook is DEGRADED/INACTIVE. Install: sudo apt install jq | brew install jq"
command -v tmux     &>/dev/null && info "tmux     — present (crash-proof sessions available)" || warn "tmux NOT found → crash-proof sessions (claude-session.sh) UNAVAILABLE. Install: brew install tmux (no native Windows build — use WSL2)"
command -v gh       &>/dev/null && info "gh       — present (PR/issue automation active)" || warn "gh NOT found → PR creation + worktree-cleanup issue closing INACTIVE. Install: https://cli.github.com"
command -v python3  &>/dev/null && info "python3  — present" || warn "python3 NOT found → gitleaks-scan & warn-pr-to-main hooks cannot parse input (skip). Install python3."
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) warn "Native Windows detected → whether Claude Code runs the .sh hooks here is NOT guaranteed. Run the toolkit inside WSL2 for reliable enforcement (see README 'Platform support').";;
esac

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Files installed.${NC}  (Installed ≠ active — see prerequisite report above.)"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
if [ "$SETTINGS_SKIPPED" = "1" ]; then
  error "  ACTION REQUIRED: hooks are NOT wired (existing settings.json left intact)."
  echo  "    Merge the 'hooks' block from .claude/templates/settings.json.template"
  echo  "    into .claude/settings.json, or no enforcement will run."
  echo  ""
fi
echo "  Confirm what's actually active on THIS machine — run the health check:"
echo "       ./scripts/doctor.sh"
echo "  (Also see the README 'Platform support & what's actually active' section.)"
echo ""
echo "  Next steps:"
echo "    1. Edit CLAUDE.md with your project details"
echo "    2. Review .claude/settings.json hook configuration"
echo "    3. Customize .claude/commands/ agent prompts (replace [YOUR_PRODUCT])"
echo "    4. Customize .oxlintrc.json rules if needed"
echo "    5. Set LINT_BASE_BRANCH only if your base branch is not main:"
echo "       export LINT_BASE_BRANCH=master"
echo "    6. Start a crash-proof session:"
echo "       ./scripts/claude-session.sh"
echo ""
