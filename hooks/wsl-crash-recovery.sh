#!/bin/bash
# Claude Code Hook: WSL Crash Recovery
# Runs on UserPromptSubmit to:
#   1. Detect stale state from crashed previous sessions -> output continuation prompts
#   2. Save current session state for future crash detection
#
# State file: ~/.claude/crash-recovery-state.json
# Keyed by PPID so multiple parallel sessions don't clobber each other.
#
# Exit codes:
#   0 - Continue (stdout is shown to user as context)

STATE_FILE="$HOME/.claude/crash-recovery-state.json"
SHOWN_MARKER="/tmp/claude-crash-recovery-shown"

CURRENT_PPID="$PPID"

# --- PHASE 1: Crash Detection (only on first hook invocation per session) ---

ALREADY_SHOWN=false

if [ -f "$SHOWN_MARKER" ]; then
  MARKER_PPID=$(cat "$SHOWN_MARKER" 2>/dev/null)
  if [ "$MARKER_PPID" = "$CURRENT_PPID" ]; then
    ALREADY_SHOWN=true
  else
    rm -f "$SHOWN_MARKER"
  fi
fi

if [ "$ALREADY_SHOWN" = false ] && [ -f "$STATE_FILE" ] && command -v jq >/dev/null 2>&1; then
  NOW=$(date +%s)
  SESSION_KEYS=$(jq -r 'keys[]' "$STATE_FILE" 2>/dev/null)

  FOUND_STALE=false
  while IFS= read -r KEY; do
    [ -z "$KEY" ] && continue
    [ "$KEY" = "$CURRENT_PPID" ] && continue

    SAVED_TIMESTAMP=$(jq -r --arg k "$KEY" '.[$k].timestamp // empty' "$STATE_FILE" 2>/dev/null)
    [ -z "$SAVED_TIMESTAMP" ] && continue

    SAVED_EPOCH=$(date -d "$SAVED_TIMESTAMP" +%s 2>/dev/null)
    [ -z "$SAVED_EPOCH" ] && continue

    STATE_AGE_SECONDS=$((NOW - SAVED_EPOCH))

    # If state is between 30 seconds and 24 hours old, it's a crash candidate
    if [ "$STATE_AGE_SECONDS" -gt 30 ] && [ "$STATE_AGE_SECONDS" -lt 86400 ]; then
      SAVED_WORKTREE=$(jq -r --arg k "$KEY" '.[$k].worktree // empty' "$STATE_FILE" 2>/dev/null)
      SAVED_BRANCH=$(jq -r --arg k "$KEY" '.[$k].branch // empty' "$STATE_FILE" 2>/dev/null)
      SAVED_TASK=$(jq -r --arg k "$KEY" '.[$k].task // empty' "$STATE_FILE" 2>/dev/null)
      SAVED_GIT_STATUS=$(jq -r --arg k "$KEY" '.[$k].git_status // empty' "$STATE_FILE" 2>/dev/null)
      SAVED_ISSUE=$(jq -r --arg k "$KEY" '.[$k].issue // empty' "$STATE_FILE" 2>/dev/null)
      SAVED_LAST_COMMIT=$(jq -r --arg k "$KEY" '.[$k].last_commit // empty' "$STATE_FILE" 2>/dev/null)

      [ -z "$SAVED_BRANCH" ] && continue

      MINS_AGO=$((STATE_AGE_SECONDS / 60))
      if [ "$MINS_AGO" -lt 60 ]; then
        TIME_AGO="${MINS_AGO} minutes ago"
      else
        HOURS_AGO=$((MINS_AGO / 60))
        TIME_AGO="${HOURS_AGO} hours ago"
      fi

      if [ "$FOUND_STALE" = false ]; then
        echo ""
        echo "========================================================"
        echo "  WSL CRASH DETECTED - Previous session(s) did not exit"
        echo "  cleanly. Continuation prompt(s) below:"
        echo "========================================================"
        FOUND_STALE=true
      fi

      echo ""
      echo "--- SESSION: ${SAVED_BRANCH} (crashed ~${TIME_AGO}) ---"
      echo ""
      echo "Continue my previous task from the crashed session."
      [ -n "$SAVED_ISSUE" ]       && echo "Issue: $SAVED_ISSUE"
      [ -n "$SAVED_WORKTREE" ]    && echo "Worktree: $SAVED_WORKTREE"
      [ -n "$SAVED_BRANCH" ]      && echo "Branch: $SAVED_BRANCH"
      [ -n "$SAVED_TASK" ]        && echo "Task: $SAVED_TASK"
      [ -n "$SAVED_LAST_COMMIT" ] && echo "Last commit: $SAVED_LAST_COMMIT"
      echo ""
      if [ -n "$SAVED_GIT_STATUS" ] && [ "$SAVED_GIT_STATUS" != "clean" ]; then
        echo "There were uncommitted changes:"
        echo "$SAVED_GIT_STATUS"
        echo ""
      fi
      echo "Please: cd into the worktree, check git status, review any uncommitted changes, and continue where we left off."
      echo ""
    fi
  done <<< "$SESSION_KEYS"

  if [ "$FOUND_STALE" = true ]; then
    echo "--- END OF RECOVERY PROMPTS ---"
    echo ""
  fi

  echo "$CURRENT_PPID" > "$SHOWN_MARKER"
fi

# --- PHASE 2: Save current session state ---

CUR_DIR=$(pwd)
CUR_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

# Detect worktree
CUR_WORKTREE=""
if [ -f "$CUR_DIR/.git" ] && grep -q "^gitdir:" "$CUR_DIR/.git" 2>/dev/null; then
  CUR_WORKTREE="$CUR_DIR"
elif echo "$CUR_DIR" | grep -q "worktrees"; then
  CUR_WORKTREE="$CUR_DIR"
fi

# Detect issue number from worktree name
CUR_ISSUE=""
if [ -n "$CUR_WORKTREE" ]; then
  CUR_ISSUE=$(basename "$CUR_WORKTREE" | grep -oE 'GH-[0-9]+' | head -1)
fi

# Get task description from branch name
CUR_TASK=""
if [ -n "$CUR_BRANCH" ] && [ "$CUR_BRANCH" != "dev" ] && [ "$CUR_BRANCH" != "main" ] && [ "$CUR_BRANCH" != "master" ]; then
  CUR_TASK=$(echo "$CUR_BRANCH" | sed 's|feature/||;s|-| |g;s|GH [0-9]* ||')
fi

# Git status summary
CUR_STATUS=$(git status --short 2>/dev/null | head -15)
[ -z "$CUR_STATUS" ] && CUR_STATUS="clean"

# Last commit
CUR_LAST_COMMIT=$(git log --oneline -1 2>/dev/null)

# Write/update this session's slot in the state file
mkdir -p "$(dirname "$STATE_FILE")"
if command -v jq >/dev/null 2>&1; then
  NOW=$(date +%s)
  EXISTING="{}"
  [ -f "$STATE_FILE" ] && EXISTING=$(cat "$STATE_FILE" 2>/dev/null || echo "{}")

  echo "$EXISTING" | jq -e 'type == "object"' >/dev/null 2>&1 || EXISTING="{}"

  NEW_ENTRY=$(jq -n \
    --arg worktree "$CUR_WORKTREE" \
    --arg branch "$CUR_BRANCH" \
    --arg task "$CUR_TASK" \
    --arg git_status "$CUR_STATUS" \
    --arg timestamp "$(date -Iseconds)" \
    --arg issue "$CUR_ISSUE" \
    --arg last_commit "$CUR_LAST_COMMIT" \
    --arg cwd "$CUR_DIR" \
    '{
      worktree: $worktree,
      branch: $branch,
      task: $task,
      git_status: $git_status,
      timestamp: $timestamp,
      issue: $issue,
      last_commit: $last_commit,
      cwd: $cwd
    }')

  # Merge: prune stale (>24h) entries, then upsert our PPID slot
  echo "$EXISTING" | jq \
    --argjson entry "$NEW_ENTRY" \
    --arg key "$CURRENT_PPID" \
    --argjson now "$NOW" \
    'to_entries
     | map(select(
         (.value.timestamp // "") != "" and
         (now - (.value.timestamp | fromdateiso8601 // 0)) < 86400
       ))
     | from_entries
     | .[$key] = $entry' > "$STATE_FILE" 2>/dev/null
fi

exit 0
