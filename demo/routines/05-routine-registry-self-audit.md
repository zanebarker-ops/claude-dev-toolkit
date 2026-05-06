# Routine: Routine Registry Self-Audit

**Schedule:** Weekly, Sundays 22:00 UTC
**Model:** Haiku (mechanical comparison; cheap)
**Inputs:** The routine registry doc (`docs/reference/systems/claude-scheduled-agents.md`); the live routine API
**Outputs:** Either close the audit, or file a GH issue per drift

## The meta-routine

This is the routine whose only job is to verify that the registry of routines is correct.

When you have many routines running, the registry doc drifts. New routines get added without doc updates. Routines get disabled but stay in the doc. This audit catches drift in both directions.

## Prompt template

```
You are a routine registry self-audit agent. Your job is to verify that the documented
list of scheduled Claude agents matches the actual list running in production.

Step 1 — Read the registry document at docs/reference/systems/claude-scheduled-agents.md.
Parse out every entry: routine name, ID, schedule, status (active/disabled), model.

Step 2 — Query the live routine scheduler API (RemoteTrigger or whichever scheduler is
in use). Get the actual list of routines: ID, schedule, last-fired-at, status.

Step 3 — Cross-reference:

  IN_DOC_NOT_LIVE — routine documented but no live entry. Likely never created or
                    silently deleted.
  LIVE_NOT_IN_DOC — routine running but undocumented. Likely created without
                    registry update.
  STATUS_MISMATCH — routine listed as active in doc but disabled live (or vice versa).
  SCHEDULE_DRIFT  — schedule in doc differs from schedule live (e.g., doc says
                    weekly, live says daily).

Step 4 — Decision tree:
  - All match: close the audit ticket with "PASS — registry in sync" and stop.
  - Any drift: file a single GH issue titled
    "routine registry drift detected — <date>" in <repo>. Body must include a markdown
    table with one row per drift, columns: ID, type-of-drift, doc-says, live-says,
    suggested-fix.

Constraints:
- DO NOT modify the registry document.
- DO NOT modify any routine via the API.
- DO NOT enable or disable any routine.
- This routine's output is information for humans; humans reconcile.
```

## Why this exists

Without it, the registry document drifts immediately. Someone adds a routine in a hurry, doesn't update the doc, and three months later nobody remembers what's running. Three months after that, an incident happens, and the team can't figure out which routine fired (or didn't).

The self-audit routine prevents this. It runs every Sunday night. Drift is caught within a week.

## The narrator beat for the demo

> "Final piece. We have a routine whose entire job is to verify that the registry of routines is accurate. A routine that audits routines. Self-auditing automation. When we drift — add a new routine, forget to update the registry — it files an issue. When we have a routine that's no longer running but is still documented, it files an issue. The system patrols itself."
