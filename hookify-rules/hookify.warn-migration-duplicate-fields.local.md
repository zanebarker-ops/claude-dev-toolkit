---
name: warn-migration-duplicate-fields
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: migrations/.*\.sql$
  - field: new_text
    operator: regex_match
    pattern: (ADD\s+COLUMN|CREATE\s+TABLE.*\().*(_new|_v2|_2|_old|_temp|_copy)\b
---

⚠️ **Duplicate field pattern detected in migration!**

**SCHEMA DRIFT WARNING:** Your migration contains field names that suggest duplication:
- `*_new`, `*_v2`, `*_2` (e.g., `userId2`, `user_id_new`)
- `*_old`, `*_temp`, `*_copy`

**Why this is problematic:**
This is the #1 pattern AI creates that leads to schema drift. Instead of fixing the existing field, we create a duplicate and leave both in place.

**The correct approach:**

❌ **Don't do this:**
```sql
ALTER TABLE users ADD COLUMN userId2 UUID;
-- (old userId column still exists)
```

✅ **Do this instead:**
```sql
-- Migrate data from old column to new
UPDATE users SET user_id = userId WHERE user_id IS NULL;
-- Drop old column
ALTER TABLE users DROP COLUMN userId;
```

**If you genuinely need a temporary column during migration:**
1. Document why in the migration comment
2. Drop it in the same migration after data is migrated
3. Never commit a migration with both columns

**See:** GH-873 Database Integrity Standards
**Docs:** @docs/reference/architecture/database.md (Migration Anti-Patterns section)
