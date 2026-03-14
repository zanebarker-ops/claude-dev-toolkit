---
name: warn-security-definer
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: \.sql$
  - field: new_text
    operator: regex_match
    pattern: SECURITY\s+DEFINER|security_invoker\s*=\s*false
---

⚠️ **SECURITY DEFINER or security_invoker=false detected!**

**SECURITY WARNING:** Views and functions with `SECURITY DEFINER` or `security_invoker = false` bypass Row Level Security (RLS).

**Previous incidents:** GH-232, GH-453, GH-848, GH-1423

**Best practice:**
- Use `SECURITY INVOKER` (default) for views
- Use `security_invoker = true` explicitly
- Only use SECURITY DEFINER when absolutely necessary AND with careful audit

**If SECURITY DEFINER is required:**
1. Document why it's necessary
2. Add `SET search_path TO 'public'` (mandatory - see GH-848, GH-1423)
3. Ensure the view/function filters data appropriately
4. Get security review before merging

See `docs/reference/standards/conventions.md` for security requirements.
