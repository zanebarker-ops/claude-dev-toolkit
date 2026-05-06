# Routine: Schema-Doc Reconciliation

**Schedule:** Within 1 hour of any merge that includes a file matching `**/migrations/*.sql`
**Model:** Sonnet
**Inputs:** Merge commit, list of migrations in the merge
**Outputs:** Either close the verification ticket, or file a GH issue per orphaned reference

## Prompt template

```
You are a schema-drift detection agent. A migration was merged within the last hour.
Your job is to detect any code that references columns or tables that no longer exist
in production after this migration ran.

Migrations in this merge: <list-of-migration-files>
Merge commit: <sha>

Step 1 — For each migration file, parse out the DDL statements. Specifically identify:
  - DROP COLUMN <name> ON <table>
  - DROP TABLE <name>
  - ALTER COLUMN <name> RENAME TO <new-name>
  - DROP INDEX <name>

Step 2 — Connect to the production Postgres read replica (via env var
PROD_PG_READONLY_URL). Verify the live schema reflects each DROP/RENAME by querying
information_schema.columns and information_schema.tables. If any DDL is in the
migration but not in the live schema, the migration may not have run yet — re-queue
yourself for 1 hour and stop.

Step 3 — For each dropped or renamed column/table, run a codebase grep:
  grep -rn '\b<old-name>\b' apps/ packages/ scripts/ --include='*.ts' --include='*.tsx' \
       --include='*.js' --include='*.jsx' --include='*.py'

Step 4 — Filter results: ignore matches inside migration files, archive directories,
documentation, and the agent's own templates.

Step 5 — Decision tree:
  - If no orphaned references: close the verification ticket with "PASS" and stop.
  - For each orphaned reference: open a GH issue titled
    "schema drift: <name> referenced in code, removed by <migration-file>" in <repo>.
    Body must include:
      - File path and line number
      - The exact code snippet (5 lines around the match)
      - The migration file that removed the column/table
      - Suggested fix (rename to <new-name> if it's a rename; remove the reference if
        it's a drop)
    Tag <oncall-handle>. Severity: high if file is in a hot path (cron, API route, page
    component), medium otherwise.

Constraints:
- DO NOT modify any code.
- DO NOT run `git mv` or any other repo-changing command.
- If grep returns more than 50 matches for a single name, the rename is too broad to
  audit automatically — file ONE issue summarizing the count and stop.
```

## Why this catches what code review misses

Code review reviewers grep when they remember to. They forget when the diff is small. They forget when they're tired. The routine doesn't forget. Every migration triggers it. Every match becomes an issue. The reviewer sees the issue *after* merge and fixes it before users notice.

## Real example

A migration renamed `families.welcome_email_sent` to `families.onboarding_state` (a JSONB blob with multiple flags). Tests passed because the test fixtures used the new name. The dashboard query was updated. The cron route was *not* updated. For 2 months, every new family signed up but never got a welcome email — the cron's query against the old column name returned `null`, and the handler interpreted `null` as "no families to email."

Had this routine been running at the time, it would have fired 30 minutes after the migration, grepped the codebase for `welcome_email_sent`, found the cron route, and filed an issue before the first family was missed.
