#!/bin/bash
# Claude Code Hook: Remind to update database.md after schema edits
# Type: PostToolUse
# Purpose: Reminds to update database documentation after modifying schema files
#
# Exit codes:
#   0 - Allow (reminder sent via stdout)
#
# Patterns detected:
#   - **/migrations/**/*.sql
#   - **/schema.ts
#   - **/supabase/**/*.sql
#   - **/prisma/schema.prisma

# Get the tool input from stdin (Claude Code passes JSON)
INPUT=$(cat)

# Extract file path from the tool call
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

# If not a schema file, no reminder needed
if [ "$IS_SCHEMA_FILE" = false ]; then
  exit 0
fi

# Send reminder
echo ""
echo "============================================================"
echo "  DATABASE SCHEMA CHANGE DETECTED"
echo "============================================================"
echo ""
echo "  File modified: $FILE_PATH"
echo ""
echo "  REMINDER: Update .claude/database.md with your changes!"
echo ""
echo "  Checklist:"
echo "    [ ] Add new tables to Table Inventory"
echo "    [ ] Update Entity Relationships diagram"
echo "    [ ] Document RLS policies (if applicable)"
echo "    [ ] Add any new functions to Key Functions"
echo "============================================================"
echo ""

exit 0
