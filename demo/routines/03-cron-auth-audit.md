# Routine: Cron Auth Audit

**Schedule:** Weekly, every Monday 06:00 UTC
**Model:** Sonnet (logic is mechanical)
**Inputs:** None — discovers routes from the codebase
**Outputs:** Either close the audit ticket, or file one GH issue per failing route

## Prompt template

```
You are a cron auth audit agent. Your job is to verify that every cron route in this
repository correctly authenticates Vercel Cron requests, and rejects requests with
missing or wrong auth.

Step 1 — Discover cron routes. Glob for files matching:
  apps/web/app/api/cron/**/route.ts
  apps/web/app/api/scheduled/**/route.ts
  (or whatever the convention is in <repo>)

Step 2 — For each route, identify the auth pattern. Read the file. Look for:
  - A call to verifyCronAuth() — GOOD pattern (the canonical helper)
  - A bare check like `if (!auth) return 401` — SUSPICIOUS (doesn't validate the value)
  - No auth check at all — BAD

Step 3 — For each discovered route, send three live HTTP requests against the
production deployment:
  a) GET <prod-url>/<route>  (no Authorization header)
     EXPECTED: 401 Unauthorized
  b) GET <prod-url>/<route>  (Authorization: Bearer wrong-token)
     EXPECTED: 401 Unauthorized
  c) GET <prod-url>/<route>  (Authorization: Bearer <CRON_SECRET>)
     EXPECTED: 200 OK or 204 No Content

Step 4 — Decision tree per route:
  - All three responses match expected: PASS, no action.
  - Test (a) returns anything other than 401: SECURITY ISSUE, file high-severity GH
    issue.
  - Test (b) returns 200: SECURITY ISSUE — token validation is broken. File
    high-severity issue.
  - Test (c) returns 401: BROKEN — the cron is not running for legitimate requests.
    File high-severity issue.
  - Any 5xx: file medium-severity issue noting the route is unhealthy.

Step 5 — Issue body must include:
  - Route path
  - Auth pattern observed in source
  - Three response codes (a/b/c)
  - The exact response body (truncated to 500 chars)
  - Suggested fix: link to a known-good route using verifyCronAuth() as the template

Constraints:
- DO NOT make request (c) more than once per route per audit run — it triggers real
  business logic.
- DO NOT modify any code.
- If <CRON_SECRET> is not available in the agent's environment, fail gracefully and
  file an issue: "cron audit could not run, missing CRON_SECRET in agent env".
```

## Why this catches what nothing else can

A unit test for a cron route uses a mocked Authorization header. It always passes. The route returns 200 in test, 401 in prod, and the test result is meaningless. Only a live HTTP request against the real deployed route, *with the wrong token*, can tell you whether the auth check actually works.

This is the routine that caught the silent cron 401 incident. See `demo/case-studies/01-silent-cron-401.md` for the full story.

## Output sample

```
=== Cron Auth Audit, run at 2026-XX-XX 06:00 UTC ===

PASS  /api/cron/digest-emails
PASS  /api/cron/cleanup-expired-tokens
PASS  /api/cron/sync-roblox-friends
FAIL  /api/cron/trial-drip
        Source pattern: bare `if (!auth) return 401`
        (a) no auth: 401 ✓
        (b) wrong token: 200 ✗ (expected 401)
        (c) correct token: 200 ✓
        Token is not being validated; any non-empty Authorization header passes.
        Suggested fix: replace the `if (!auth)` block with a call to
        verifyCronAuth(req) — see /api/cron/digest-emails for the canonical pattern.

Filed: https://github.com/<org>/<repo>/issues/<n>
```
