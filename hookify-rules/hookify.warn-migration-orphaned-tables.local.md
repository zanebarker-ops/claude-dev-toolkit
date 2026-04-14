---
name: warn-migration-orphaned-tables
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: migrations/.*\.sql$
  - field: new_text
    operator: regex_match
    pattern: CREATE\s+TABLE
---

**CREATE TABLE detected — verify no duplicate tables exist!**

Before creating a new table, check that you're not duplicating an existing concept.

**Common anti-patterns:**
1. Creating `subscriptions_v2` instead of migrating `subscriptions`
2. Creating `billing_new` instead of altering `billing`
3. Forgetting to drop old tables after data migration

**Checklist:**
1. Search for similar table names in existing migrations
2. Search for code references to any table with a similar name
3. If replacing an existing table:
   - Migrate data in the same PR
   - Drop the old table in the same migration
   - Update all code references
4. Document in migration header:
   ```sql
   -- REPLACES: old_table_name (created in migration XXX)
   -- REASON: [why replacing instead of altering]
   ```

**Rule:** If you're creating a table for a concept that already exists, you're doing it wrong. Migrate, don't duplicate.
