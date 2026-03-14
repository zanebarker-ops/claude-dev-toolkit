#!/bin/bash
# Claude Code Hook: Block `gh pr create` unless CI/CD deployment has been verified
#
# Requires: A verification marker file written by your CI/CD check script.
# The marker file path is: /tmp/<project-name>-ci-verified-<SHA>
#
# To integrate with your CI/CD check script, have it write:
#   touch "/tmp/${PROJECT_NAME}-ci-verified-${SHA}"
# on success.
#
# Exit codes:
#   0 - Allow the tool call
#   2 - Block the tool call (stderr sent to Claude as feedback)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | grep -oP '"command"\s*:\s*"\K[^"]*' | head -1)

# Only intercept gh pr create commands
if ! echo "$COMMAND" | grep -qE 'gh\s+pr\s+create'; then
  exit 0
fi

# Get current commit SHA
SHA=$(git rev-parse HEAD 2>/dev/null)
if [ -z "$SHA" ]; then
  exit 0  # Not in a git repo, allow
fi

# Derive project name from the repo directory name
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME="project"
fi

# Check for verification marker file
MARKER_FILE="/tmp/${PROJECT_NAME}-ci-verified-${SHA}"
if [ -f "$MARKER_FILE" ]; then
  exit 0  # Deployment verified, allow PR creation
fi

# No marker found — block
cat >&2 << BLOCK_MSG

========================================
  BLOCKED: CI/CD deployment not verified
========================================

  Before creating a PR, you MUST verify the CI/CD preview
  deployment succeeded for the current commit (${SHA:0:8}).

  Run your CI/CD check script and ensure it passes.
  The script should write a marker file to:
    $MARKER_FILE

  DO NOT create the PR until CI/CD passes.

BLOCK_MSG
exit 2
