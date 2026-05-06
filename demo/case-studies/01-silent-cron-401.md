# Case Study 1 — The Silent Cron 401

**Issue: GH-XXXX (cron auth)**
**Severity: High — silent revenue loss**
**Detected by: scheduled cloud routine, 5 days post-merge**
**Time to fix: 90 minutes (15 to diagnose, 60 to fix 6 routes, 15 to verify)**

## The bug

A new Vercel Cron route — trial-drip emails on Day 1, 3, 7, 11, 14 — was shipped with a broken auth pattern. The route handler did this:

```ts
// BROKEN
export async function GET(req: Request) {
  const auth = req.headers.get('authorization');
  if (!auth) return new Response('Unauthorized', { status: 401 });
  // ... process trial drips
}
```

Vercel Cron sends `Authorization: Bearer ${CRON_SECRET}`. So the `if (!auth)` check passed — `auth` was a non-empty string. **But the secret was never validated.** Any request with any `Authorization` header would be processed. And conversely, when the secret was rotated, the check still let real requests through but the *legitimate* cron requests were the only ones that ever hit the route.

So why was nothing being sent? Because earlier in the cron handler chain, a different middleware was returning a hard 401 on missing user session — and Vercel Cron requests don't have user sessions. **The route returned 401 every single firing for 5 days. Zero retention emails sent. Zero alerts fired. Zero customer reports.**

## How a human would have caught this

They wouldn't have. The route returned 401, which is a "client error" — not a 5xx. Error monitors don't page on 401s. The cron logs in Vercel showed "200 OK from middleware, 401 from handler" — which looks normal at a glance. Nobody was reading the logs daily.

## How the scheduled routine caught it

A weekly Claude agent — `cron-auth-audit` — runs this exact procedure:

1. Query Vercel for all routes matching `app/api/cron/**`
2. For each route, send a `GET` with `Authorization: Bearer wrong-token`
3. Verify the response is `401`
4. **Then** send a `GET` with the correct `Bearer ${CRON_SECRET}`
5. Verify the response is `200`

Step 5 failed for 6 routes. The agent opened a GH issue with:
- The 6 affected routes
- The exact stderr from each failing call
- A suggested fix (extract a `verifyCronAuth()` helper)
- A link to the existing `verifyCronAuth()` in another route that *did* work

A human triaged in 5 minutes, accepted the fix, and the orchestrator dispatched `/security-auditor` + `/backend-developer` + `/test-automation` in parallel. PR open in 30 minutes. Merged 60 minutes later.

## What the demo audience should take away

1. **Silent failures are the worst class of bugs.** They don't page. They don't 5xx. They just quietly stop working.
2. **Type safety doesn't save you here.** TypeScript was perfectly happy with the broken code.
3. **Tests don't save you either.** A unit test for the route would have used a fake Authorization header, gotten a 200, and passed.
4. **Only an end-to-end probe against the deployed route catches it.** And only an *autonomous* probe is cheap enough to run weekly on every cron route.
5. **The fix template was already in the codebase.** A working `verifyCronAuth()` existed. The agent's value-add was correlating "broken pattern in 6 places" with "working pattern in 1 place" — pattern-matching at scale.

## The narrator beat

> "Five days. Zero emails. Zero alerts. Zero human eyes. The only thing that found this was a Claude agent on cron, doing the world's most boring smoke test once a week. And it found it because we were *forced* to write the test once, in the form of a routine, and then it ran forever."
