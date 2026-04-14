---
name: block-credentials-in-client
enabled: true
event: file
action: block
conditions:
  - field: file_path
    operator: regex_match
    pattern: src/app/.*\.(ts|tsx)$|src/components/.*\.(ts|tsx)$|src/pages/.*\.(ts|tsx)$
  - field: new_text
    operator: regex_match
    pattern: service_role|SERVICE_ROLE|createServiceRoleClient|ADMIN_KEY|MASTER_KEY|SECRET_KEY.*=.*['"]
---

**BLOCKED: Credential pattern detected in client-side code!**

Service keys, admin keys, and secrets bypass access control and must NEVER appear in client-side code (components, pages, app routes that render in the browser).

**Allowed locations:**
- `src/app/api/**/*.ts` (API routes — server only)
- Server components with `'use server'` directive
- `src/lib/server/**/*.ts` (server-only utilities)

**Fix:** Use the standard client for browser code. Move privileged operations to API routes.
