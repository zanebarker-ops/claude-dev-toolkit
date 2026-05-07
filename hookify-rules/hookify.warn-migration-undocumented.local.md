---
name: warn-migration-undocumented
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: migrations/.*\.sql$
  - field: new_text
    operator: regex_match
    pattern: CREATE\s+TABLE|ALTER\s+TABLE.*ADD|DROP\s+TABLE
  - field: new_text
    operator: not_contains
    pattern: Copyright.*<your-project>
---

⚠️ **Migration missing documentation header!**

**SCHEMA EVOLUTION REQUIREMENT:** All migrations MUST include a header documenting:
1. Copyright notice
2. What changed (table/column/index)
3. Why the change is needed (GH issue reference)
4. Safety considerations
5. Migration dependencies (if any)

**Template:**
```sql
-- Copyright (c) 2026 <your-project>.ai. All rights reserved.
-- [Brief description of what changed] (GH-###)
--
-- CONTEXT:
-- [Why this change is needed]
--
-- VERIFICATION:
-- [How to verify this worked]
--
-- SAFETY:
-- [Any safety checks or rollback considerations]

[Your migration SQL here]
```

**Examples:**
- ✅ See: `20260115000003_drop_orphaned_billing_tables.sql`
- ✅ See: `20260114000004_sync_subscription_tiers.sql`

**Why this matters:**
6 months from now, you'll need to understand why this migration exists and what it affects. Document it now while the context is fresh.

**See:** GH-873 Database Integrity Standards
**Docs:** @docs/reference/standards/workflows.md (Database Migration Rules)
