# Multi-Vendor Review Loop (Claude + Codex)

A binding-review layer that adds OpenAI **Codex** as an **independent cross-vendor reviewer** of your Claude Code work. The lead Claude session runs your existing workflow end-to-end (planning, implementing, your own review skills), then Codex performs ONE final binding review on the complete PR before merge.

> **Prerequisite reading:** [`docs/primitives.md`](./primitives.md) — covers the four Claude Code primitives (skills, agents, MCPs, workflows) and the soft-vs-hard enforcement model. This doc assumes you understand those.

> **Why this exists:** Same-vendor review has blind spots. When Claude's own review skills (bug-finder, code-reviewer, security-auditor — all the same model, same training, same priors) approve a PR, they tend to miss the same classes of bug. A different vendor with different priors catches those gaps. A single ~65s Codex review on Pro plan is enough to surface real bugs that same-vendor reviews missed.

## Table of contents

- [How it works](#how-it-works)
- [The kill switch](#the-kill-switch)
- [Install](#install)
- [Configuration](#configuration)
- [Usage walkthrough](#usage-walkthrough)
- [Files reference](#files-reference)
- [Troubleshooting](#troubleshooting)
- [Cost model](#cost-model)
- [FAQ](#faq)

## How it works

```
┌── planning ────────────────────────────────────────────────────────┐
│ Claude drafts plan                                                 │
│ Codex available for consultation (NOT a gate — collaborative)      │
│ Claude finalizes plan                                              │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌── implementation (your existing flow, unchanged) ──────────────────┐
│ Claude implements code                                             │
│ Claude runs your review skills (bug-finder, code-reviewer, etc.)   │
│ Claude updates documentation                                       │
│ Claude marks "PR ready"                                            │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌── final gate (single Codex review, pre-merge) ─────────────────────┐
│ Codex reviews the complete PR (code + Claude-review trailers)      │
│   APPROVE → merge                                                  │
│   REDO    → back to Claude with feedback (cap N rounds)            │
│   beyond cap → human escalation                                    │
└────────────────────────────────────────────────────────────────────┘
```

**Three key properties:**

1. **Claude is the worker** and runs ALL its existing review agents before signaling "PR ready"
2. **Codex is the binding reviewer** at exactly one point — after Claude completes everything. No mid-implementation interruptions.
3. **The verdict has teeth.** Hook-enforced budget caps + per-task tier caps + a `--require-clean-tree` flag prevent the gate from being silently bypassed.

## The kill switch

Everything is governed by `CDT_USE_CODEX_REVIEW`:

| Value | Behavior |
|---|---|
| `off` | `codex-review-prompt.sh` emits `SKIP` immediately. Existing flow runs untouched. |
| `shadow` (DEFAULT) | Pre-flight runs and Codex is called, but the verdict is LOGGED and **non-binding** — lead may still merge. |
| `binding-dev` | Codex's REDO **blocks merge** for PRs targeting your dev branch. Use `--require-clean-tree` to prevent local-edit bypass. |
| `binding-all` | Codex's REDO blocks merge for all PRs. |

**Recommended rollout:** ship in `shadow` for 5–10 PRs to calibrate the noise floor, then flip to `binding-dev`, then `binding-all`. Activation is per-developer (in your shell rc), not repo-wide — no commit needed to flip.

## Install

### Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- [`@openai/codex`](https://www.npmjs.com/package/@openai/codex) CLI: `npm i -g @openai/codex`
- Codex auth: `codex login --device-auth` (WSL-friendly device-flow; opens a URL on any device, you enter a code)
- `jq` and `bash` (standard on Linux/macOS)
- A git repo (the gate operates on `git log` / `git diff`)

### One-time setup (copy the toolkit into your project)

`claude-dev-toolkit`'s `install.sh` does NOT yet copy the `orchestration/`
tree into target projects (planned follow-up). For now, copy it manually:

```bash
# From the root of your project:
cp -r /path/to/claude-dev-toolkit/orchestration .

# Add the runtime state directory to .gitignore (configs stay checked in;
# state — ledger, locks, review log — is per-worktree and gitignored)
echo '.orchestration/' >> .gitignore

# Verify the install — should pass 15/15 in <1s with no live API calls.
# (The script uses an isolated temp dir for state; safe to run in any project,
#  including one where the hooks are already producing real telemetry.)
bash orchestration/scripts/hello-world.sh
```

### Wire the hooks into Claude Code

Edit `.claude/settings.json` in your project to register the 4 orchestration hooks. The simplest path: add the entries to your existing `PreToolUse` / `PostToolUse` arrays (don't replace — append). Example skeleton:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "orchestration/hooks/pre-codex-budget-cap.sh", "timeout": 5 }
        ]
      },
      {
        "matcher": "Agent",
        "hooks": [
          { "type": "command", "command": "orchestration/hooks/pre-agent-loop-cap.sh", "timeout": 5 }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "orchestration/hooks/post-codex-debit.sh", "timeout": 10 },
          { "type": "command", "command": "orchestration/hooks/post-sb-commit-update.sh", "timeout": 5 }
        ]
      }
    ]
  }
}
```

All four hooks **early-reject non-orchestration commands** (no `T-NN` task tag or no `codex`/`sb-commit` invocation → no-op `{}` in <5ms). Ordinary workflow is unaffected.

After editing `.claude/settings.json`, **restart your Claude Code session** so the new hooks load.

### Configure your project's policies

The pre-flight checks (Reviewed-By trailers + ref-arch docs on schema change) are **opt-in via env vars**. Add to your shell rc (`~/.bashrc` / `~/.zshrc`) or your project's `.envrc` (if you use direnv):

```bash
# Kill switch — start in shadow mode for calibration.
export CDT_USE_CODEX_REVIEW=shadow

# Budget guards (sensible defaults). Pro plan covers usage; these are runaway-guards.
export CDT_CODEX_CAP_CENTS=5000      # $50/mo cap. Spike default is 10 cents.
export CDT_CODEX_TIER_CAP=1          # Per-task cap on Codex attempts.

# Required Reviewed-By trailers — agent names from YOUR review skills.
# Leave empty (default) to skip the trailer check.
export CDT_REQUIRED_REVIEWERS="bug-finder code-reviewer security-auditor"

# Schema-change → ref-arch doc enforcement (optional).
# Globs identifying schema files (match against `git diff --name-only base...HEAD`).
export CDT_SCHEMA_GLOBS="**/migrations/*.sql"
# Globs to EXCLUDE (e.g. archived migrations).
export CDT_SCHEMA_IGNORE_GLOBS="**/migrations/archive/*.sql"
# Doc paths that MUST be updated when any schema file is in the diff.
export CDT_REFARCH_DOC_PATHS="docs/architecture.md"
```

### Verify the install

```bash
# 1. Verify the hooks fire (in a fresh session, run any Bash command — should be invisible)
ls

# 2. Verify the pre-flight script works
bash orchestration/scripts/codex-review-prompt.sh --base main

# 3. Run the full verification suite (all 7 scripts in <2s)
for t in orchestration/scripts/hello-world.sh \
         orchestration/verify/test-state-race.sh \
         orchestration/verify/test-first-writer-race.sh \
         orchestration/verify/test-task-id-scoping.sh \
         orchestration/verify/test-review-log.sh \
         orchestration/verify/test-ndjson-debit.sh \
         orchestration/verify/test-codex-review-prompt.sh; do
  bash "$t" >/dev/null 2>&1 && echo "PASS  $t" || echo "FAIL  $t"
done
```

## Configuration

See `orchestration/README.md` for the complete env-var reference. Key vars:

| Env var | Required | Default | What it does |
|---|---|---|---|
| `CDT_USE_CODEX_REVIEW` | No | `shadow` | Kill switch (`off` / `shadow` / `binding-dev` / `binding-all`) |
| `CDT_CODEX_CAP_CENTS` | No | `10` | Monthly Codex spend ceiling (runaway guard) |
| `CDT_CODEX_TIER_CAP` | No | `1` | Per-task Codex attempt cap |
| `CDT_REQUIRED_REVIEWERS` | No | empty | Space-separated agent names whose `Reviewed-By:` trailers must be on HEAD |
| `CDT_SCHEMA_GLOBS` | No | empty | Schema-file glob patterns (triggers ref-arch doc check) |
| `CDT_SCHEMA_IGNORE_GLOBS` | No | empty | Schema-file globs to EXCLUDE |
| `CDT_REFARCH_DOC_PATHS` | No | empty | Required doc paths when schema files are in diff |

## Usage walkthrough

The lead Claude session, after marking "PR ready":

```bash
# 1. Get pre-flight verdict
out="$(orchestration/scripts/codex-review-prompt.sh \
        --base main \
        [--require-clean-tree])"          # binding mode → always add --require-clean-tree

verdict="$(echo "$out" | jq -r .verdict)"

case "$verdict" in
  SKIP)
    # CDT_USE_CODEX_REVIEW=off — no Codex review.
    echo "Codex review skipped (kill switch off)"
    ;;
  REDO)
    # Pre-flight failed (trailers, ref-arch doc, or dirty tree).
    reason="$(echo "$out" | jq -r .reason)"
    echo "Pre-flight REDO: $reason"
    exit 1
    ;;
  PROMPT)
    # Pre-flight passed. Pipe the prompt to codex review.
    prompt="$(echo "$out" | jq -r .prompt)"
    codex review --commit "$(git rev-parse HEAD)" "$prompt"
    # Lead reads codex's output and applies the binding rule per CDT_USE_CODEX_REVIEW.
    ;;
esac
```

## Files reference

```
orchestration/
├── README.md                           orientation
├── hooks/
│   ├── pre-agent-loop-cap.sh           PreToolUse(Agent) — per-task loop cap
│   ├── pre-codex-budget-cap.sh         PreToolUse(Bash)  — Codex budget/tier cap
│   ├── post-codex-debit.sh             PostToolUse(Bash) — ledger + attempts
│   └── post-sb-commit-update.sh        PostToolUse(Bash) — sb-commit.sh pass/fail
├── lib/
│   ├── state-helper.sh                 flock-guarded atomic state.json writer
│   ├── codex-pricing.json              gpt-5.5 token rates (verify before binding)
│   └── mock-codex-companion.sh         drop-in mock for local testing
├── scripts/
│   ├── codex-review-prompt.sh          THE gate — emits PROMPT / REDO / SKIP verdict
│   ├── dynamic-round-cap.sh            recommends review-round cap from diff size
│   ├── hello-world.sh                  end-to-end acceptance (no live API)
│   └── escalate.sh                     tier-ladder helper
└── verify/
    ├── test-state-race.sh              200 concurrent writes, zero lost updates
    ├── test-first-writer-race.sh       race against missing state.json
    ├── test-task-id-scoping.sh         compound-command tid extraction
    ├── test-review-log.sh              review_log[] schema + dynamic-round-cap
    ├── test-ndjson-debit.sh            real Codex NDJSON parsing
    └── test-codex-review-prompt.sh     14 cases for the gate script
```

## Troubleshooting

### "Codex says REDO and my trailers ARE on the commit"

The trailer check uses `git log -1 --format='%(trailers:key=Reviewed-By,valueonly=true)' HEAD`. Things to verify:

1. The trailers are on HEAD, not on a parent commit. Use `git log -1` to confirm.
2. The trailer key is exactly `Reviewed-By` (case-sensitive). `reviewed-by` won't match.
3. The trailer values match what's in `CDT_REQUIRED_REVIEWERS`. Whole-line match (no prefix/suffix).
4. If you **squash-merged** an earlier PR, the squash body must include the trailers — otherwise the merge commit on your default branch carries no trailers.

### "Codex CLI auth keeps failing on WSL"

Use `--device-auth` instead of the default OAuth flow:

```bash
codex login --device-auth
```

The default flow starts a local OAuth server on port 1455 with a browser callback, which is unreliable on WSL. Device-auth prints a URL + code; you open the URL on any device, enter the code, the CLI polls until done.

### "How do I know the orchestration hooks are actually firing?"

The hooks early-reject on non-orchestration commands so they're invisible during normal work. To verify they're loaded, intentionally trigger one:

```bash
# This Bash command contains "codex" — the budget hook will run, see no real
# codex invocation, allow the call, and exit silently. If you DON'T see a hook
# error, the hooks are loaded correctly.
echo "this is a fake codex test"

# Check the state file got created:
cat .orchestration/state.json | jq .
```

### "I want to disable the gate for one PR without touching env"

Set the kill switch inline for that command:

```bash
CDT_USE_CODEX_REVIEW=off orchestration/scripts/codex-review-prompt.sh --base main
```

## Cost model

- **OpenAI Pro plan** covers `codex review` usage within plan limits at **zero marginal cost**.
- **Fallback:** `OPENAI_API_KEY` for usage beyond plan limits.
- **Per-review:** ~7k tokens per review × ~2 reviews per PR (PROMPT + REDO-fix re-review) = ~14k tokens per PR.
- **Latency:** 30–60 seconds per review (sometimes faster for small diffs, occasionally longer for greenfield code).
- **Runaway guard:** `CDT_CODEX_CAP_CENTS=5000` ($50/mo) hard-stops new spending Codex calls if the ledger trips the cap.

## FAQ

**Q: Do I have to use OpenAI Codex? Can I use Gemini / another vendor instead?**
A: The system is wired specifically to `codex review`. For a different vendor you'd need to (a) wrap that vendor's CLI to emit the same verdict shape and (b) rename `CDT_*_CODEX_*` env vars. The architecture (pre-flight + binding gate + state ledger) is vendor-agnostic; the specific CLI integration isn't.

**Q: Will this slow down my workflow?**
A: Hook overhead on ordinary calls is <5ms (early-reject branches). The Codex review itself takes 30–60s per round and only fires when the lead explicitly invokes it pre-PR — not on every commit.

**Q: What if my project uses something other than `bug-finder` / `code-reviewer` / `security-auditor` as review skills?**
A: Set `CDT_REQUIRED_REVIEWERS` to your agent names. The trailer check is fully parameterized.

**Q: Can I gate other types of changes (not just schema → docs)?**
A: Currently the only enforced cross-check is "schema-glob → ref-arch doc." Extending the script with more checks is straightforward — patches welcome.

**Q: What's the design background?**
A: The pattern is an independent-cross-vendor-review loop. The lead does all implementation + its own review agents; the second-vendor reviewer runs only at the very end as a binding gate. Single decision point per PR; lower latency; the second vendor reviews the *complete* artifact (including the first vendor's review trailers) rather than partial states.

---

## See also

- [`docs/primitives.md`](./primitives.md) — Skills · Agents · MCPs · Workflows + enforcement model
- [`orchestration/README.md`](../orchestration/README.md) — file-by-file reference for the shipped scripts
- [`hooks/README.md`](../hooks/README.md) — hook catalog this loop builds on top of
