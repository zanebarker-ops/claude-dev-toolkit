# Routine: Post-Merge Outcome Verification

**Schedule:** 24 hours after any merge to `main` with label `auth`, `signup`, `email`, or `payment`
**Model:** Sonnet (sufficient for log analysis + comparison)
**Inputs:** PR number, merge commit SHA, GH labels
**Outputs:** Either close the verification ticket, or open a new GH issue with evidence

## Prompt template

```
You are a post-merge verification agent. A PR with relevant labels was merged 24 hours
ago, and your job is to verify that the user-visible outcome matches the intent of the
PR.

PR: <pr-number>
Merge commit: <sha>
Labels: <labels>
Title: <title>

Step 1 — Read the PR description and identify the user-visible signal that should change.
Examples: "welcome emails sent", "signup alerts in #new-signups", "trial-drip emails on
day 1/3/7", "Slack notification on payment failure". Be specific.

Step 2 — Query production logs (via the Axiom MCP) for events related to that signal in
the last 24 hours. Get a count.

Step 3 — Query the destination of that signal (Slack API, email provider API, Postgres,
whichever applies) for matching deliveries in the same window. Get a count.

Step 4 — Compare. If counts diverge by more than 10%, that is a regression.

Step 5 — Decision tree:
  - If counts match (within 10%): close the verification ticket with "PASS — counts
    aligned" and stop.
  - If counts diverge: open a GH issue titled
    "post-merge regression: <pr-title> (<pr-number>)" in <repo>. Body must include:
      - Expected count (events fired)
      - Actual count (deliveries received)
      - Time window
      - 5 sample event IDs that have no matching delivery
      - Hypothesis (what likely broke)
      - Suggested fix or rollback recommendation
    Tag <oncall-handle>.

Constraints:
- Do NOT modify production data.
- Do NOT retry deliveries — that is the human's call.
- Do NOT touch any file in the repository — your only side effect is filing a GH issue.
- If you cannot reach Axiom or the destination API, file a low-severity issue
  "post-merge verify could not run for <pr>: <reason>" and stop.
```

## Why this catches what tests miss

A unit test mocks the destination. A routine *queries the actual destination*. If the destination silently rejected your message (rate limited, malformed, expired token), the test would never know. The routine sees the count diff and files an issue.

## Real example

This routine fired 24 hours after a payment-failure-alert PR. Expected 14 alerts (1 per failed payment in the window). Slack channel had 0. The routine opened a GH issue. Root cause: the Slack webhook URL had been rotated 3 weeks earlier and the new value was only set in the *frontend* env var, not the cron-job env var. Fix took 5 minutes. Without the routine, the team would have noticed when a customer asked "why didn't anyone follow up on the failed payment?" — probably 2-3 weeks later.
