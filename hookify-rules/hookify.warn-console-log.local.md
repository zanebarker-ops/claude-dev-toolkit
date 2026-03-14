---
name: warn-console-log
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: src/.*\.(ts|tsx)$
  - field: new_text
    operator: regex_match
    pattern: console\.(log|debug|info)\(
---

⚠️ **Console.log detected in production code!**

**Reminder:** Remove debugging statements before committing.

**Allowed alternatives:**
- `console.error()` - for actual errors
- `console.warn()` - for warnings
- Structured logging via a logger utility

**If intentional:** Consider using a proper logging library or remove before PR.
