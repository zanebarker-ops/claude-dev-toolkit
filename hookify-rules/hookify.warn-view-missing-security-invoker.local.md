---
name: warn-view-missing-security-invoker
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: \.sql$
  - field: new_text
    operator: regex_match
    pattern: CREATE\s+(OR\s+REPLACE\s+)?VIEW
  - field: new_text
    operator: not_contains
    pattern: security_invoker
---

**SECURITY WARNING: Missing `security_invoker = on` in view creation!**

**Security Incident GH-996:** Views created via Supabase migrations default to `security_invoker=false` (SECURITY DEFINER), which **bypasses RLS**.

**MANDATORY:** All views MUST include explicit `security_invoker = on`:

```sql
-- CORRECT
CREATE VIEW my_view
WITH (security_invoker = on) AS
SELECT ...;

-- WRONG - bypasses RLS when run via migrations
CREATE VIEW my_view AS
SELECT ...;
```

**Why this matters:**
- PostgreSQL views default differently based on execution context
- Supabase migrations run as database owner (superuser)
- Superuser-created views default to SECURITY DEFINER (bypasses RLS)
- This can expose ALL data to ANY authenticated user

**Previous incidents:** GH-232, GH-471, GH-848, GH-996

See `docs/reference/standards/security.md` for full documentation.
