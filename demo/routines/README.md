# Claude Routines — Templates

These are **autonomous Claude agents that run on cron**, in the cloud, with no human in the loop. They watch production. They verify deploys. They catch silent failures. They file GitHub issues automatically when something is wrong.

Each `.md` file in this directory is a **prompt template** you can paste into a scheduled-agent platform (Anthropic Routines, GitHub Actions running Claude Code in headless mode, a self-hosted scheduler — any of them work).

## Why routines beat tests + monitoring

| Tool | Catches | Misses |
|---|---|---|
| **Unit tests** | Logic regressions inside a function | Schema drift, deploy issues, env mismatches, lambda lifecycle |
| **E2E tests** | Happy-path UI regressions | Silent backends — webhooks dropped, emails not sent, alerts swallowed |
| **APM (Sentry, Datadog)** | Errors that throw or log | Silent failures — 200 returned, but the work didn't happen |
| **Synthetic monitoring** | Endpoints up | Whether the endpoint *did the thing* it was supposed to do |
| **Claude routine** | "Does the user-visible signal match what we shipped?" | Tasks that need millisecond response time |

A routine asks the question a smart engineer would ask if they had unlimited time and zero distraction: *"After we shipped this, did it actually work in prod, end-to-end, the way we intended?"*

## How to use these templates

1. Pick a routine that matches a class of bug you've seen
2. Customize the placeholders (`<your-org>`, `<production-url>`, `<channel-name>`)
3. Schedule it on whatever cron platform you're using
4. Wire its output to a Slack channel, GitHub issue, or PagerDuty escalation

## Templates

| File | Purpose | Schedule | Severity |
|---|---|---|---|
| `01-post-merge-verify.md` | After any merge with `auth` or `signup` label, verify outcomes match expectations | 24 hours after merge | High |
| `02-schema-doc-reconcile.md` | Detect column renames or removals that left orphaned references in code | Within 1 hour of every migration | High |
| `03-cron-auth-audit.md` | Verify every cron route returns 401 on bad auth and 200 on correct auth | Weekly | Medium |
| `04-dependabot-triage.md` | Cross-reference Dependabot alerts vs. pnpm overrides; classify orphaned patches | Quarterly | Medium |
| `05-routine-registry-self-audit.md` | Verify the routine registry is in sync with the live scheduler | Weekly | Low |
