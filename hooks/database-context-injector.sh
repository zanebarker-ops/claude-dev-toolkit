#!/bin/bash
# Claude Code Hook: Inject database.md context before schema edits
# Type: PreToolUse
# Purpose: Provides database schema context before modifying migrations or schema files
#
# Exit codes:
#   0 - Allow the tool call (stdout is injected as context)
#   2 - Block the tool call (stderr sent to Claude as feedback)
#
# Patterns detected:
#   - **/migrations/**/*.sql
#   - **/schema.ts
#   - **/supabase/**/*.sql
#   - **/prisma/schema.prisma

# Get the tool input from stdin (Claude Code passes JSON)
INPUT=$(cat)

# Extract file path from the tool call (handles Write, Edit tools)
# Use sed instead of grep -oP for Windows compatibility
FILE_PATH=$(echo "$INPUT" | sed -n 's/.*"file_path"\s*:\s*"\([^"]*\)".*/\1/p' 2>/dev/null | head -1)

# If no file_path, might be in different field
if [ -z "$FILE_PATH" ]; then
  FILE_PATH=$(echo "$INPUT" | sed -n 's/.*"path"\s*:\s*"\([^"]*\)".*/\1/p' 2>/dev/null | head -1)
fi

# Exit early if no file path found
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Normalize path for pattern matching
FILE_PATH_NORMALIZED=$(echo "$FILE_PATH" | sed 's|\\|/|g')

# Check if this is a schema/migration file
IS_SCHEMA_FILE=false

if echo "$FILE_PATH_NORMALIZED" | grep -qE '/migrations/.*\.sql$'; then
  IS_SCHEMA_FILE=true
elif echo "$FILE_PATH_NORMALIZED" | grep -qE '/schema\.(ts|sql)$'; then
  IS_SCHEMA_FILE=true
elif echo "$FILE_PATH_NORMALIZED" | grep -qE '/supabase/.*\.sql$'; then
  IS_SCHEMA_FILE=true
elif echo "$FILE_PATH_NORMALIZED" | grep -qE '/prisma/schema\.prisma$'; then
  IS_SCHEMA_FILE=true
fi

# If not a schema file, allow without context
if [ "$IS_SCHEMA_FILE" = false ]; then
  exit 0
fi

# Find the database.md file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_MD="$SCRIPT_DIR/../database.md"

# Check if database.md exists
if [ ! -f "$DATABASE_MD" ]; then
  echo "NOTE: .claude/database.md not found. Create it to get schema context." >&2
  exit 0
fi

# Inject database context
echo ""
echo "=========================================="
echo "DATABASE SCHEMA CONTEXT (from .claude/database.md)"
echo "=========================================="
echo ""
echo "You are about to modify: $FILE_PATH"
echo ""
echo "Review the schema documentation below before making changes:"
echo ""
cat "$DATABASE_MD"
echo ""
echo "=========================================="
echo "Remember to update .claude/database.md after making schema changes!"
echo "=========================================="
echo ""

exit 0
