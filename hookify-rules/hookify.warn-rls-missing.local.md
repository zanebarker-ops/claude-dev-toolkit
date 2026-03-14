---
name: warn-rls-missing
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: migrations/.*\.sql$|\.sql$
  - field: new_text
    operator: regex_match
    pattern: CREATE\s+TABLE
  - field: new_text
    operator: not_contains
    pattern: ENABLE ROW LEVEL SECURITY
---

⚠️ **CREATE TABLE without RLS detected!**

**SECURITY REQUIREMENT:** All tables MUST have Row Level Security enabled.

Every `CREATE TABLE` statement must be followed by:
```sql
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;
```

And appropriate RLS policies:
```sql
CREATE POLICY "policy_name" ON table_name
  FOR SELECT USING (auth.uid() = user_id);
```

**Previous incidents:** GH-230, GH-232

See `docs/reference/standards/conventions.md` for the mandatory RLS checklist.
