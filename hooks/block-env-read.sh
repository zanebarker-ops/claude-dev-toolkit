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

# Extract file_path
TARGET_FILE=$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"\K[^"]+' | head -1)

if [ -z "$TARGET_FILE" ]; then
  exit 0  # No file path, allow
fi

# Get just the filename
BASENAME=$(basename "$TARGET_FILE")

# Block .env files (but allow .env.example, .env.docker.example, etc.)
case "$BASENAME" in
  .env|.env.local|.env.production|.env.development|.env.staging|.env.preview)
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
    echo "  Allowed: .env.example, .env.docker.example" >&2
    echo "" >&2
    exit 2
    ;;
  *)
    exit 0  # Not a secrets .env file, allow
    ;;
esac
