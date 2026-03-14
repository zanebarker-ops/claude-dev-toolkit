#!/bin/bash
# check-deploy.sh - Check CI/CD preview deployment status via GitHub Deployments API
#
# Polls the GitHub Deployments API until the deployment succeeds or times out.
# Works with Vercel, Netlify, or any CI/CD that reports via GitHub Deployments.
#
# Usage:
#   scripts/check-deploy.sh [SHA]
#   SHA defaults to HEAD if not provided.
#
# On success, writes a marker file that check-ci-before-pr.sh uses to gate PRs:
#   /tmp/<project-name>-ci-verified-<SHA>

set -euo pipefail

SHA="${1:-$(git rev-parse HEAD 2>/dev/null)}"
if [ -z "$SHA" ]; then
  echo "ERROR: Not in a git repository and no SHA provided" >&2
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
PROJECT_NAME=$(basename "$REPO_ROOT" 2>/dev/null || echo "project")
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)

if [ -z "$REPO" ]; then
  echo "ERROR: Could not determine GitHub repo. Run: gh auth login" >&2
  exit 1
fi

SHORT_SHA="${SHA:0:8}"
MARKER_FILE="/tmp/${PROJECT_NAME}-ci-verified-${SHA}"
MAX_ATTEMPTS=30  # 5 minutes (30 * 10s)
POLL_INTERVAL=10

echo "Checking deployment for ${SHORT_SHA} in ${REPO}..."
echo "  Marker file: ${MARKER_FILE}"
echo ""

for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  # Get deployments for this SHA
  DEPLOYMENTS=$(gh api "repos/${REPO}/deployments?sha=${SHA}&per_page=5" 2>/dev/null || echo "[]")
  DEPLOY_COUNT=$(echo "$DEPLOYMENTS" | grep -c '"id"' || echo "0")

  if [ "$DEPLOY_COUNT" -eq 0 ]; then
    echo "  [$i/$MAX_ATTEMPTS] No deployments found yet... waiting ${POLL_INTERVAL}s"
    sleep $POLL_INTERVAL
    continue
  fi

  # Check the latest deployment status
  DEPLOY_ID=$(echo "$DEPLOYMENTS" | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')
  STATUSES=$(gh api "repos/${REPO}/deployments/${DEPLOY_ID}/statuses?per_page=1" 2>/dev/null || echo "[]")
  STATE=$(echo "$STATUSES" | grep -o '"state":"[^"]*"' | head -1 | sed 's/"state":"//;s/"//')
  URL=$(echo "$STATUSES" | grep -o '"environment_url":"[^"]*"' | head -1 | sed 's/"environment_url":"//;s/"//')

  case "$STATE" in
    success)
      echo ""
      echo "  Deployment SUCCEEDED!"
      [ -n "$URL" ] && echo "  Preview URL: $URL"
      touch "$MARKER_FILE"
      echo "  Marker written: $MARKER_FILE"
      exit 0
      ;;
    failure|error)
      echo ""
      echo "  Deployment FAILED (state: $STATE)"
      [ -n "$URL" ] && echo "  URL: $URL"
      exit 1
      ;;
    *)
      echo "  [$i/$MAX_ATTEMPTS] Status: $STATE ... waiting ${POLL_INTERVAL}s"
      sleep $POLL_INTERVAL
      ;;
  esac
done

echo ""
echo "  TIMEOUT: Deployment did not complete in $((MAX_ATTEMPTS * POLL_INTERVAL))s"
exit 1
