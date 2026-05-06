# Case Study 3 — The Lambda That Forgot to Wait

**Issue: GH-XXXX (signup alert lifecycle)**
**Severity: Medium — internal alert pipeline silently dropping events**
**Detected by: post-merge verification routine, 24 hours post-deploy**
**Time to fix: 2 hours**

## The bug

After a user signs up:
1. The auth provider (NextAuth) creates the `users` row in Postgres
2. A server action fires a Slack webhook to alert the team in `#new-signups`
3. The user is redirected to `/onboarding`

The Slack webhook fires from a server action that runs in a serverless function (Vercel Edge / Lambda). Server actions return a redirect response. The redirect response causes Vercel's runtime to *terminate the function*.

Here's the broken pattern:

```ts
'use server';
export async function signupAction(formData) {
  await createUser(formData);
  void notifySlack(formData);  // fire-and-forget
  redirect('/onboarding');
}
```

The `void` here is a developer trick to say "I don't care about the return value." But `notifySlack` is async, and the lambda terminates on `redirect()` — which throws a redirect error to unwind the stack. **The fetch to Slack got partway through the network handshake, then was killed.**

Result: ~70% of new signups never produced a Slack alert. The team noticed when sales asked "did anyone reach out to that lead?" and there was no Slack notification to thread on.

## How the routine caught it

A post-merge verification routine fires 24 hours after any PR with a `signup` or `auth` label is merged. It does this:
1. Query prod logs (via Axiom MCP) for `event_type:signup_completed` in the last 24 hours
2. Query Slack API for messages in `#new-signups` from the bot in the same time window
3. If signup count is more than 10% higher than message count, file an issue with the diff

The first run after this PR found a 67% gap. Issue filed automatically with:
- Signup events: 18
- Slack messages: 6
- Missing 12 alerts
- Suggested fix: replace `void notifySlack(...)` with `await notifySlack(...)` *before* `redirect()`

## Why this was hard to catch in code review

The reviewer saw `void notifySlack(...)` and thought "fire-and-forget, fine." That's a *correct* pattern for long-running background work — but only when the runtime keeps the process alive. In a serverless function with a redirect response, the runtime does *not*.

This is a class of bug that requires runtime knowledge of:
- Server action return semantics (redirect throws)
- Lambda lifecycle (terminates on redirect)
- `await` vs `void` in async context

A senior engineer might have caught it. Most reviewers would not. **A routine that watches the actual signal — alerts received — catches it every time.**

## The fix

```ts
'use server';
export async function signupAction(formData) {
  await createUser(formData);
  await notifySlack(formData);  // wait for the fetch to complete
  redirect('/onboarding');
}
```

Now `notifySlack` blocks until the fetch resolves. The redirect happens after. The lambda terminates *after* the alert is delivered.

## What the demo audience should take away

1. **Lambda lifecycle is a category of bug your tests can't simulate.** Local dev doesn't terminate the Node process on redirect. Vercel does.
2. **The pattern matters more than the line.** `void promise` is fine in long-running services and dangerous in serverless. The reviewer needs runtime context.
3. **Routines that watch *outcomes* (alerts received, emails sent, jobs completed) catch what code review can't.** The unit of verification should be the user-visible signal, not the function call.

## The narrator beat

> "The reviewer wasn't wrong. The pattern *is* fire-and-forget. It's just that fire-and-forget doesn't work when the runtime kills the process before the fire reaches its destination. Code review can catch syntax. It can catch obvious logic bugs. It cannot catch runtime semantics that depend on the deployment target. That's why we have routines."
