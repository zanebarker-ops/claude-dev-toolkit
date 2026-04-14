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

section "Installing hooks (18 files)"
cp "$TOOLKIT_DIR/hooks/"* "$TARGET/.claude/hooks/"
info "Hooks installed to .claude/hooks/"

section "Installing agent commands (26 files)"
cp "$TOOLKIT_DIR/commands/"* "$TARGET/.claude/commands/"
info "Commands installed to .claude/commands/"

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
if [ -f "$TARGET/.claude/settings.json" ]; then
  warn "Skipped .claude/settings.json (already exists)"
  warn "  Review template at: .claude/templates/settings.json.template"
  cp "$TOOLKIT_DIR/config/settings.json.template" "$TARGET/.claude/templates/"
else
  cp "$TOOLKIT_DIR/config/settings.json.template" "$TARGET/.claude/settings.json"
  info "Created .claude/settings.json"
fi

section "Installing lint config"
if [ -f "$TARGET/.oxlintrc.json" ]; then
  warn "Skipped .oxlintrc.json (already exists)"
else
  cp "$TOOLKIT_DIR/config/.oxlintrc.json" "$TARGET/.oxlintrc.json"
  info "Created .oxlintrc.json"
fi

section "Installing scripts"
for script in lint-changed.sh check-deploy.sh claude-session.sh migrate-to-ext4.sh; do
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

section "Checking prerequisites"
command -v oxlint &>/dev/null && info "oxlint installed" || warn "oxlint not found. Install: npm install -g oxlint"
command -v claude &>/dev/null && info "Claude Code CLI installed" || warn "Claude Code CLI not found. Install: npm install -g @anthropic-ai/claude-code"
command -v gh &>/dev/null && info "GitHub CLI installed" || warn "GitHub CLI not found. Install: https://cli.github.com"
command -v tmux &>/dev/null && info "tmux installed" || warn "tmux not found. Install: sudo apt install tmux"
command -v gitleaks &>/dev/null && info "gitleaks installed" || warn "gitleaks not found (optional). Install: brew install gitleaks"
command -v jq &>/dev/null && info "jq installed" || warn "jq not found (needed for crash recovery). Install: sudo apt install jq"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Installation complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Next steps:"
echo "    1. Edit CLAUDE.md with your project details"
echo "    2. Review .claude/settings.json hook configuration"
echo "    3. Customize .claude/commands/ agent prompts (replace [YOUR_PRODUCT])"
echo "    4. Customize .oxlintrc.json rules if needed"
echo "    5. Set LINT_BASE_BRANCH if your base branch is not dev:"
echo "       export LINT_BASE_BRANCH=main"
echo "    6. Start a crash-proof session:"
echo "       ./scripts/claude-session.sh"
echo ""
