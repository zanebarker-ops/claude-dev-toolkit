#!/bin/bash
# Claude Code Hook: Security checks before git commit
# Validates migrations have RLS and sensitive keys aren't in client code
#
# Customize the checks below for your project's tech stack.
#
# Exit codes:
#   0 - Allow the tool call
#   2 - Block the tool call (stderr sent to Claude as feedback)

# Read the tool input from stdin
INPUT=$(cat)

# Extract the command from JSON input
COMMAND=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | sed 's/"command":"//;s/"$//')

# Check if this is a git commit command
if echo "$COMMAND" | grep -q "git commit"; then
  SECURITY_ERRORS=""

  # Verify we're in a git repo
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$REPO_ROOT" ]; then
    exit 0
  fi

  echo "Running security checks before commit..." >&2

  # ===== CHECK 1: Migrations without RLS =====
  # Get staged migration files
  STAGED_MIGRATIONS=$(git diff --cached --name-only | grep -E "migrations/.*\.sql$" || true)

  if [ -n "$STAGED_MIGRATIONS" ]; then
    echo "Checking migrations for RLS..." >&2

    for FILE in $STAGED_MIGRATIONS; do
      if [ -f "$FILE" ]; then
        # Check if file creates a table
        if grep -qi "CREATE TABLE" "$FILE"; then
          # Check if RLS is enabled
          if ! grep -qi "ENABLE ROW LEVEL SECURITY" "$FILE"; then
            SECURITY_ERRORS="${SECURITY_ERRORS}\n❌ Migration missing RLS: $FILE"
            SECURITY_ERRORS="${SECURITY_ERRORS}\n   Tables created without 'ENABLE ROW LEVEL SECURITY'"
          fi
        fi
      fi
    done
  fi

  # ===== CHECK 2: Service/secret keys in client code =====
  # Adjust the path patterns to match your project's client code directories
  STAGED_CLIENT=$(git diff --cached --name-only | grep -E "(src/app/\(|src/components/)" | grep -v "src/app/api/" || true)

  if [ -n "$STAGED_CLIENT" ]; then
    echo "Checking for secret keys in client code..." >&2

    for FILE in $STAGED_CLIENT; do
      if [ -f "$FILE" ]; then
        # Check for common secret key patterns (customize for your stack)
        if grep -qiE "service_role|SERVICE_ROLE|_SECRET_KEY|_PRIVATE_KEY" "$FILE"; then
          SECURITY_ERRORS="${SECURITY_ERRORS}\n❌ Secret key in client code: $FILE"
          SECURITY_ERRORS="${SECURITY_ERRORS}\n   Secret keys must ONLY be used in server-side/API code"
        fi
      fi
    done
  fi

  # ===== CHECK 3: API routes without auth =====
  # Adjust the path pattern and auth check to match your project
  STAGED_API=$(git diff --cached --name-only | grep -E "src/app/api/.*route\.(ts|js)$" || true)

  if [ -n "$STAGED_API" ]; then
    echo "Checking API routes for authentication..." >&2

    for FILE in $STAGED_API; do
      if [ -f "$FILE" ]; then
        # Check for common auth patterns (customize for your auth library)
        # Common patterns: getUser, getSession, verifyToken, requireAuth, authenticate
        if ! grep -qiE "getUser|getSession|verifyToken|requireAuth|authenticate|auth\.verify" "$FILE"; then
          SECURITY_ERRORS="${SECURITY_ERRORS}\n⚠️  API route may lack auth check: $FILE"
          SECURITY_ERRORS="${SECURITY_ERRORS}\n   Consider adding authentication verification"
        fi
      fi
    done
  fi

  # ===== OUTPUT RESULTS =====
  if [ -n "$SECURITY_ERRORS" ]; then
    echo "" >&2
    echo "========================================" >&2
    echo "  ⛔ SECURITY BLOCK: Issues Found" >&2
    echo "========================================" >&2
    echo -e "$SECURITY_ERRORS" >&2
    echo "" >&2
    echo "Fix the issues above before committing." >&2
    echo "Run /security-auditor for full audit." >&2
    echo "" >&2
    exit 2
  fi

  echo "Security checks passed." >&2
fi

exit 0
