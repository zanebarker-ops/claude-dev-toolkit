# Case Study 2 — The Welcome Email That Wasn't

**Issue: GH-XXXX (welcome email regression)**
**Severity: High — onboarding completion impact**
**Detected by: schema-doc reconciliation routine, 2 months post-incident**
**Time to fix: 45 minutes**

## The bug

A migration in production renamed the column `families.welcome_email_sent` to `families.onboarding_state` (a JSONB blob with multiple flags). The migration ran clean. The dashboard queries against `onboarding_state` worked. Tests passed.

What nobody noticed: the **welcome-email cron route** was still querying:

```ts
const { data } = await supabase
  .from('families')
  .select('id, email')
  .eq('welcome_email_sent', false);
```

PostgreSQL does what PostgreSQL does. It evaluated `welcome_email_sent` as an unknown identifier, but because the column had been *renamed* (not dropped) — wait, actually the migration *did* drop the column. So the query failed with `column "welcome_email_sent" does not exist`.

But Supabase's REST layer wraps the error in a 200 response with `{ "data": null, "error": {...} }`. The handler did:

```ts
const { data } = await supabase.from('families').select(...).eq(...);
if (data && data.length > 0) {
  // send emails
}
```

`data` was `null`, so `data && data.length > 0` was `false`. **Loop body skipped. Cron returned 200. No emails sent. No alerts. For 2 months.**

## How the routine caught it

A schema-doc reconciliation routine fires weekly. It does this:
1. Query the live Postgres `information_schema.columns` for table `families`
2. Compare against the canonical schema doc at `docs/reference/database/schema.md`
3. For every column in the schema doc that doesn't exist live, grep the codebase for references
4. For every reference, file a GH issue with the file path and line

It found 1 reference: the welcome-email cron, querying `welcome_email_sent` on a column that hadn't existed for 60 days.

## What the human did wrong

The original PR that renamed the column had this on the checklist:
- [x] Migration runs clean
- [x] Dashboard queries updated
- [x] Tests pass
- [ ] **Grep for old column name across codebase**

The unchecked item is what would have caught this. But the PR was merged anyway because the reviewer *thought* the grep had been done.

## What the safety net does about that

After GH-XXXX, two changes:

1. **`/security-auditor` now blocks PRs that include a column rename without a verified codebase grep.** It runs `grep -r 'old_column_name' apps/` and fails the audit if any results come back outside the migration file.
2. **The schema-doc reconciliation routine got upgraded** from "weekly" to "fires within 1 hour of every migration merge."

## The narrator beat

> "Two months. Every single new family signed up to SafeGamer. Zero of them got a welcome email. The metric we look at — `families.created_at` — went up. The metric we *should* have looked at — `welcome_emails_sent` — wasn't being tracked. The fix wasn't more vigilance. The fix was a routine that audits schema-vs-code drift on every merge. Now this class of bug can't survive past lunch."

## What the demo audience should take away

1. **Supabase's data-or-error pattern is a footgun for silent failures.** `data` is `null` on error, and `data && data.length > 0` evaluates the same way as "no rows found."
2. **Migrations break code at runtime, not compile time.** TypeScript types come from a generated file (`database.types.ts`) that has to be regenerated after every migration. If the regeneration is forgotten, `select('welcome_email_sent')` is still typed correctly *and* fails at runtime.
3. **The fix isn't more discipline. The fix is more automation.** Discipline doesn't scale. A routine does.
