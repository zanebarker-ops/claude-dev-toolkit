# orchestration/ — multi-vendor review loop

Repo-shared, checked-in configs for the multi-vendor binding review loop
(Claude + OpenAI Codex). The lead Claude session runs your existing workflow
end-to-end, then Codex performs ONE final binding review on the complete PR
before merge.

**High-level docs:** [`docs/multi-agent-orchestration.md`](../docs/multi-agent-orchestration.md)

## Layout

| Path | Purpose |
|---|---|
| `hooks/pre-agent-loop-cap.sh` | PreToolUse(Agent) — denies past-cap retries on a task |
| `hooks/pre-codex-budget-cap.sh` | PreToolUse(Bash) — denies Codex calls past tier cap or budget cap |
| `hooks/post-codex-debit.sh` | PostToolUse(Bash) — debits cost ledger + increments attempt count |
| `hooks/post-sb-commit-update.sh` | PostToolUse(Bash) — robust pass/fail recording for `sb-commit.sh`-style scripts |
| `lib/state-helper.sh` | flock-guarded atomic writes against `.orchestration/state.json` |
| `lib/codex-pricing.json` | Token-rate data for cost computation (gpt-5.5 placeholder; verify before binding mode) |
| `lib/mock-codex-companion.sh` | Drop-in mock for local testing without burning API tokens |
| `scripts/codex-review-prompt.sh` | Emits the pre-flight verdict (SKIP / REDO / PROMPT) for the lead to consume |
| `scripts/dynamic-round-cap.sh` | Recommends a Codex review-round cap based on diff size |
| `scripts/hello-world.sh` | End-to-end acceptance test (no live Claude/Codex calls) |
| `scripts/escalate.sh` | Tier-ladder advancement helper |
| `verify/` | Race tests + regression tests for the helper library and scripts |

## Configuration (all opt-in via env vars)

| Env var | Default | Purpose |
|---|---|---|
| `CDT_USE_CODEX_REVIEW` | `shadow` | `off` skips entirely; `shadow` non-binding; `binding-dev` binds for dev PRs; `binding-all` binds everywhere |
| `CDT_CODEX_CAP_CENTS` | `10` | Monthly Codex spend cap in cents. Production target: `5000` ($50/mo) |
| `CDT_CODEX_TIER_CAP` | `1` | Per-task cap on Codex attempts. Prevents one task burning the monthly budget |
| `CDT_TASK_ID` | unset | Sentinel for orchestration-tagged tool calls (or use `T-NN` in the prompt) |
| `CDT_REQUIRED_REVIEWERS` | empty (skip check) | Space-separated agent names whose `Reviewed-By:` trailers MUST be on HEAD before Codex review. E.g. `"bug-finder code-reviewer security-auditor"` |
| `CDT_SCHEMA_GLOBS` | empty (skip check) | Bash glob patterns identifying schema-changing files. E.g. `"**/migrations/*.sql"` |
| `CDT_SCHEMA_IGNORE_GLOBS` | empty | Glob patterns to EXCLUDE from schema check. E.g. `"**/migrations/archive/*.sql"` |
| `CDT_REFARCH_DOC_PATHS` | empty | Doc paths that MUST be in the diff when a schema-changing file is present. E.g. `"docs/architecture.md docs/api.md"` |

## Runtime state

All runtime state — `state.json`, lock file, cost ledger — lives at
`<repo-root>/.orchestration/`. Add it to `.gitignore`:

```
echo '.orchestration/' >> .gitignore
```

## Installation

See [`docs/multi-agent-orchestration.md`](../docs/multi-agent-orchestration.md) for the full activation walkthrough (wire hooks into `.claude/settings.json`, set env vars, validate with `hello-world.sh`).

## Quick verification

```bash
# Should pass 15/15 assertions in <1s with no live API calls
bash orchestration/scripts/hello-world.sh

# Race-condition tests (zero lost updates under concurrency)
bash orchestration/verify/test-state-race.sh
bash orchestration/verify/test-first-writer-race.sh
```
