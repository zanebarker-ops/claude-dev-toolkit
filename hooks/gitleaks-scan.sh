#!/usr/bin/env bash
# Claude Code hook: scan for secrets before git commit
# Triggers on: PreToolUse -> Bash (git commit)
#
# Requires: gitleaks (https://github.com/gitleaks/gitleaks)
# Install: brew install gitleaks / go install github.com/gitleaks/gitleaks/v8@latest

set -euo pipefail

# Only run on git commit commands
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('input',{}).get('command',''))" 2>/dev/null || echo "")

if ! echo "$COMMAND" | grep -qE "git\s+commit"; then
  exit 0
fi

if ! command -v gitleaks &>/dev/null; then
  exit 0
fi

# Find repo root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$REPO_ROOT" ]; then
  exit 0
fi

# Look for gitleaks config
CONFIG=""
if [ -f "$REPO_ROOT/.gitleaks.toml" ]; then
  CONFIG="$REPO_ROOT/.gitleaks.toml"
fi

CONFIG_FLAG=""
if [ -n "$CONFIG" ]; then
  CONFIG_FLAG="--config $CONFIG"
fi

# Scan staged files
# shellcheck disable=SC2086
RESULT=$(gitleaks protect --staged $CONFIG_FLAG 2>&1) || {
  echo "========================================" >&2
  echo "  BLOCKED: Secrets detected in staged files" >&2
  echo "========================================" >&2
  echo "" >&2
  echo "$RESULT" >&2
  echo "" >&2
  echo "  Remove the secret, then try again." >&2
  echo "  Use .gitleaks.toml to allowlist false positives." >&2
  echo "" >&2
  exit 2
}

exit 0
