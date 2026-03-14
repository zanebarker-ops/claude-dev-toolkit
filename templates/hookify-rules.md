# Hookify Rules

This document describes hookify rules that can be configured to enforce coding standards and prevent common mistakes.

## Overview

Hookify uses the [Hookify plugin](https://github.com/anthropics/claude-code/tree/main/plugins/hookify) to create lightweight rules that intercept and respond to specific behaviors during Claude Code sessions.

Rules are markdown files with YAML frontmatter stored in `.claude/hookify.*.local.md`.

## Active Rules

### P0 - Critical (Block)

| Rule | File | Event | Description |
|------|------|-------|-------------|
| **Branch Protection** | `hookify.block-direct-main-dev.local.md` | bash | Blocks direct commits/pushes to `main` or `dev` |
| **Branch Protection (Edit/Write)** | `check-worktree.sh` via `settings.json` | edit, write | Blocks Edit/Write tool calls on `main` or `dev` in main repo |
| **Push Without Lint** | `hookify.block-push-without-lint.local.md` | bash | Blocks `git push` to feature branches without lint/typecheck |
| **Hook Bypass** | `hookify.block-hook-bypass.local.md` | bash | Blocks bypassing git hooks (`--no-verify`, `core.hooksPath`) |
| **Env Protection** | `hookify.block-env-modification.local.md` | file | Blocks modifications to `.env` files |
| **Service Role** | `hookify.block-service-role-client.local.md` | file | Blocks service role keys in client code |
| **RLS Missing** | `hookify.block-rls-missing.local.md` | file | Warns on CREATE TABLE without RLS |
| **CI Deploy Check** | `check-ci-before-pr.sh` via `settings.json` | bash | Blocks `gh pr create` unless CI/CD deployment verified |
| **Supabase Direct Access** | `hookify.block-supabase-direct-access.local.md` | bash | Blocks direct Supabase access via REST API, RPC, or JS client patterns |

### P1 - Important (Warn)

| Rule | File | Event | Description |
|------|------|-------|-------------|
| **PR Lint Check** | `hookify.warn-pr-lint.local.md` | bash | Warns to run lint before `gh pr create` |
| **ESLint Disable** | `hookify.warn-eslint-disable.local.md` | file | Warns on eslint-disable comments |
| **Security Definer** | `hookify.warn-security-definer.local.md` | file | Warns on explicit SECURITY DEFINER in SQL |
| **View Missing Security Invoker** | `hookify.warn-view-missing-security-invoker.local.md` | file | Warns on CREATE VIEW without security_invoker=on |
| **Hardcoded IDs** | `hookify.warn-hardcoded-ids.local.md` | file | Warns on hardcoded user/account IDs |
| **Console.log** | `hookify.warn-console-log.local.md` | file | Warns on console.log in production code |
| **Migration Duplicate Fields** | `hookify.warn-migration-duplicate-fields.local.md` | file | Warns on duplicate field patterns (field2, *_new) |
| **Migration Undocumented** | `hookify.warn-migration-undocumented.local.md` | file | Warns on migrations without proper documentation |

## Rule Details

### Block: Direct Main/Dev Commits

**Trigger:** `git push/commit` to `main` or `dev`, or `git checkout main`

**Why:** CLAUDE.md mandates all work through feature branches and PRs.

**Correct workflow:**
```bash
PROJECT_NAME=$(basename $(git rev-parse --show-toplevel))
git worktree add ../${PROJECT_NAME}-worktrees/GH-###-desc -b feature/GH-###-desc dev
cd ../${PROJECT_NAME}-worktrees/GH-###-desc
# ... work ...
git push -u origin feature/GH-###-desc
gh pr create --base dev
```

---

### Block: .env Modifications

**Trigger:** Edit/Write to `.env`, `.env.local`, `.env.production`

**Why:** Environment files contain sensitive credentials unique to each developer.

**Correct approach:** Provide instructions for user to manually edit. Reference `.env.example` for required variables.

---

### Block: Service Role in Client Code

**Trigger:** `service_role`, `SERVICE_ROLE`, or `createServiceRoleClient` in client-side code paths:
- `src/app/**/*.tsx` (client components)
- `src/components/**/*.tsx`

**Why:** Service role bypasses Row-Level Security — critical security risk in client code.

**Allowed locations:**
- `src/app/api/**/*.ts` (server-side API routes)
- Server components with explicit server directive
- Background job workers

---

### Block: CREATE TABLE Without RLS

**Trigger:** `CREATE TABLE` without a following `ENABLE ROW LEVEL SECURITY` in migration files

**Why:** Every table must have RLS to prevent unauthorized data access.

**Correct pattern:**
```sql
CREATE TABLE feature_table (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id)
);

-- MANDATORY: Enable RLS immediately after creation
ALTER TABLE feature_table ENABLE ROW LEVEL SECURITY;

-- Add access policies
CREATE POLICY "users_select_own" ON feature_table
    FOR SELECT USING (account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    ));
```

---

### Block: Push Without Lint

**Trigger:** `git push` to feature branches without lint/typecheck markers

**Why:** Prevents broken builds from reaching CI/CD. Build failures on preview deployments block PR creation.

**Correct workflow:**
```bash
scripts/lint-worktree.sh eslint      # Or: npm run lint
scripts/lint-worktree.sh typecheck   # Or: npx tsc --noEmit
# Both must pass with zero errors
git push -u origin feature/GH-###-description
```

---

### Block: CI/CD Deploy Check Before PR

**Trigger:** `gh pr create`

**Why:** PRs must only be created after the CI/CD preview deployment succeeds. Creates a marker file `/tmp/${PROJECT_NAME}-ci-verified-${SHA}` when deployment passes.

**Correct workflow:**
```bash
git push -u origin feature/GH-###-description
scripts/check-ci-deploy.sh $(git rev-parse HEAD)  # Wait for deployment
gh pr create --base dev --title "..." --body "..."
```

---

### Block: Hook Bypass

**Trigger:** `--no-verify`, `core.hooksPath=/dev/null`, or similar hook bypass patterns

**Why:** Hooks enforce critical safety checks. Bypassing them can merge broken or insecure code.

**Exception:** If a hook is causing false positives, fix the hook rather than bypassing it.

---

### Warn: eslint-disable Comments

**Trigger:** `// eslint-disable` or `/* eslint-disable */` in source files

**Why:** Disabling ESLint rules often hides real problems.

**Correct approach:** Fix the underlying issue instead of disabling the rule. If the rule is genuinely wrong for this case, document why with a specific `eslint-disable-next-line` with a comment.

---

### Warn: SECURITY DEFINER in SQL

**Trigger:** `SECURITY DEFINER` in SQL files

**Why:** `SECURITY DEFINER` functions run with elevated privileges and can bypass RLS if not carefully constructed.

**When it's acceptable:**
- Utility functions that need to bypass RLS for specific operations
- Must be documented with a clear explanation of why it's needed
- Must still validate caller permissions explicitly within the function

---

### Warn: Console.log in Production Code

**Trigger:** `console.log(` in `src/` files

**Why:** Debug logs pollute production output and can leak sensitive data.

**Correct approach:** Remove debug logs before committing. Use structured logging for production observability.

---

## Setting Up Hookify

1. Install Hookify plugin for Claude Code
2. Copy rule files to `.claude/` directory
3. Configure `settings.json` to run hooks on appropriate events
4. Test each hook by triggering its condition

## Adding New Rules

To add a new rule:

1. Create `.claude/hookify.[action]-[description].local.md`
2. Add YAML frontmatter with: `trigger`, `event`, `message`
3. Test in a scratch branch before enabling for the team
4. Document in this file

## Disabling Rules

If a rule is causing false positives:

1. Investigate why the rule is triggering incorrectly
2. Fix the rule condition rather than disabling it
3. If temporary disable is needed, note the issue in a comment
4. Create a GitHub issue to properly fix it
