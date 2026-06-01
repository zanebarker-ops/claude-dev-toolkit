#!/usr/bin/env bash
# doctor.sh — report what toolkit enforcement is ACTUALLY active on THIS machine.
#
# Run it from a project that has the toolkit installed (so it can inspect
# .claude/), or from anywhere to just check tools + platform. It never changes
# anything — it only reports. Because hooks fail OPEN when their tool is missing,
# a clean install can still have inactive enforcement; this surfaces that.
#
# Usage:  scripts/doctor.sh        (or ./doctor.sh from wherever it lives)
set -u

# ── Colors (degrade gracefully if not a TTY) ──────────────────────────────────
if [ -t 1 ]; then
  G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; B='\033[0;34m'; DIM='\033[2m'; NC='\033[0m'
else
  G=''; Y=''; R=''; B=''; DIM=''; NC=''
fi
ok()   { printf "  ${G}✓ ACTIVE${NC}   %s\n" "$1"; }
off()  { printf "  ${Y}⚠ OFF${NC}      %s\n" "$1"; }
bad()  { printf "  ${R}✗ BROKEN${NC}   %s\n" "$1"; }
note() { printf "  ${DIM}· %s${NC}\n" "$1"; }
head() { printf "\n${B}%s${NC}\n" "$1"; }

have() { command -v "$1" >/dev/null 2>&1; }

WARN=0; CRIT=0

printf "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${B}  Claude Dev Toolkit — doctor (what's actually active here)${NC}\n"
printf "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# ── Platform ──────────────────────────────────────────────────────────────────
head "Platform"
OS="$(uname -s 2>/dev/null || echo unknown)"
case "$OS" in
  Linux*)  ok "Linux — bash hooks run natively" ;;
  Darwin*) ok "macOS — bash hooks run natively" ;;
  MINGW*|MSYS*|CYGWIN*)
    off "Native Windows ($OS) — whether Claude Code runs the .sh hooks here is NOT guaranteed."
    note "For reliable enforcement run the toolkit inside WSL2."
    WARN=$((WARN+1)) ;;
  *) off "Unknown platform ($OS) — assuming POSIX shell"; WARN=$((WARN+1)) ;;
esac
if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then note "Running inside WSL — good (supported path on Windows)."; fi

# ── Core (without these, nothing works) ───────────────────────────────────────
head "Core requirements"
have bash  && ok "bash — hooks can execute"            || { bad "bash MISSING — NO hooks can run";          CRIT=$((CRIT+1)); }
have git   && ok "git — worktree workflow available"   || { bad "git MISSING — workflow inoperable";         CRIT=$((CRIT+1)); }
have claude&& ok "claude — Claude Code CLI present"     || { bad "claude MISSING — the toolkit cannot run";   CRIT=$((CRIT+1)); }

# ── Enforcement tools (fail OPEN when missing) ────────────────────────────────
head "Enforcement tools (hooks fail open / degrade when missing)"
have oxlint   && ok "oxlint — pre-commit lint gate works"            || { off "oxlint MISSING — lint gate INACTIVE (fails open). npm i -g oxlint"; WARN=$((WARN+1)); }
have gitleaks && ok "gitleaks — secret-scan gate works"              || { off "gitleaks MISSING — secret scan INACTIVE (fails open). brew install gitleaks"; WARN=$((WARN+1)); }
have python3  && ok "python3 — secret-scan/PR hooks can parse input" || { off "python3 MISSING — gitleaks-scan & warn-pr-to-main skip"; WARN=$((WARN+1)); }
have jq       && ok "jq — crash recovery works"                      || { off "jq MISSING — crash-recovery DEGRADED. brew install jq / apt install jq"; WARN=$((WARN+1)); }
have tmux     && ok "tmux — crash-proof sessions available"          || { off "tmux MISSING — claude-session.sh UNAVAILABLE (no native Windows build; use WSL2)"; WARN=$((WARN+1)); }
have gh       && ok "gh — PR/issue automation works"                 || { off "gh MISSING — PR creation + issue-close on cleanup INACTIVE. https://cli.github.com"; WARN=$((WARN+1)); }
have docker   && ok "docker — Docker-per-worktree available"         || note "docker not found — Docker-per-worktree (optional) unavailable."

# ── Install wiring in the current project ─────────────────────────────────────
head "This project's wiring ($(pwd))"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SETTINGS="$ROOT/.claude/settings.json"
HOOKDIR="$ROOT/.claude/hooks"
if [ ! -d "$ROOT/.claude" ]; then
  note "No .claude/ here — not a toolkit-installed project (or run from the project root)."
else
  if [ -f "$SETTINGS" ]; then
    if grep -q '"hooks"' "$SETTINGS" 2>/dev/null && grep -q '\.claude/hooks/' "$SETTINGS" 2>/dev/null; then
      ok "settings.json present and references hooks — enforcement is WIRED"
    else
      off "settings.json present but does NOT register toolkit hooks — enforcement NOT wired (merge the template's 'hooks' block)"; WARN=$((WARN+1))
    fi
  else
    off "No .claude/settings.json — hooks are NOT wired"; WARN=$((WARN+1))
  fi
  if [ -d "$HOOKDIR" ]; then
    n=$(find "$HOOKDIR" -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
    nx=$(find "$HOOKDIR" -maxdepth 1 -name '*.sh' -perm -u+x 2>/dev/null | wc -l | tr -d ' ')
    ok "hook files present: $n (.sh), $nx executable"
    [ "$n" != "$nx" ] && { off "Some hooks are not executable — run: chmod +x $HOOKDIR/*.sh"; WARN=$((WARN+1)); }
  else
    note "No .claude/hooks/ — hook scripts not installed here."
  fi
fi

# ── Always-true caveat ────────────────────────────────────────────────────────
head "Known by design"
note "Hookify rules (.claude/hookify.*.local.md) are INERT — no loader ships."
note "Only the equivalent shell hooks enforce (block-direct-main, cross-worktree)."

# ── Summary ───────────────────────────────────────────────────────────────────
head "Summary"
if [ "$CRIT" -gt 0 ]; then
  printf "  ${R}%s critical problem(s)${NC} and ${Y}%s warning(s)${NC}. The toolkit will not function until the critical items are fixed.\n" "$CRIT" "$WARN"
elif [ "$WARN" -gt 0 ]; then
  printf "  ${Y}%s warning(s)${NC}. Core works, but some enforcement is INACTIVE (see ⚠ above).\n" "$WARN"
else
  printf "  ${G}All checks passed${NC} — full enforcement active on this machine.\n"
fi
printf "  ${DIM}Details: README → 'Platform support & what's actually active'.${NC}\n\n"
exit 0
