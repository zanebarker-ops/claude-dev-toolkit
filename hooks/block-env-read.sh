#!/bin/bash
# Claude Code Hook: Block reading .env files containing secrets
# This runs before Read tool calls to prevent Claude from seeing
# sensitive credentials (API secrets, service keys, etc.)
#
# Exit codes:
#   0 - Allow the read (not an .env file)
#   2 - Block the read (.env file with secrets)

# Read JSON input from stdin
INPUT=$(cat)

# Extract file_path from the JSON tool input. Use POSIX sed (BRE) so this works
# on both GNU and BSD/macOS grep+sed. The previous `grep -oP '...\K...'` relied
# on PCRE, which errors on macOS's default grep — yielding an empty match and
# silently ALLOWING the read, defeating the guardrail (fail-open).
TARGET_FILE=$(printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

if [ -z "$TARGET_FILE" ]; then
  # Fail CLOSED: if the payload carries a file_path we couldn't parse, block
  # rather than allow — a parser miss must never become a guardrail bypass.
  if printf '%s' "$INPUT" | grep -q '"file_path"'; then
    echo "BLOCKED: block-env-read could not parse file_path; failing closed." >&2
    exit 2
  fi
  exit 0  # No file path in this tool call, allow
fi

# Get just the filename
BASENAME=$(basename "$TARGET_FILE")

# Block .env and every .env.* variant (.env.local, .env.production, .env.test,
# ...) EXCEPT documented placeholder files (.env.example, .env.sample,
# .env.template, .env.docker.example, etc.), which contain no real secrets.
case "$BASENAME" in
  *.example|*.sample|*.template)
    exit 0  # Placeholder file, allow
    ;;
  .env|.env.*)
    echo "" >&2
    echo "========================================" >&2
    echo "  BLOCKED: Cannot read .env file" >&2
    echo "========================================" >&2
    echo "" >&2
    echo "  File: $TARGET_FILE" >&2
    echo "" >&2
    echo "  .env files contain sensitive credentials" >&2
    echo "  (API keys, service keys, secrets, etc.)" >&2
    echo "  that Claude should never see." >&2
    echo "" >&2
    echo "  Allowed: .env.example, .env.sample, .env.template" >&2
    echo "" >&2
    exit 2
    ;;
  *)
    exit 0  # Not a secrets .env file, allow
    ;;
esac
