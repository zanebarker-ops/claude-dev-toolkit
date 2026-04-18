# Scaffold Project Prompt

Paste this prompt into Claude Code in a new empty repo to generate a production-ready folder structure. Framework-agnostic — pick your stack after the skeleton exists.

---

## Prompt

```
Create a production-ready monorepo folder structure for a full-stack web application. Do NOT install any packages or write application code — only create the directories and placeholder README.md files in each folder explaining its purpose.

## Structure Requirements

### `/apps/web/` — Frontend
- `src/components/` — Reusable UI components (organized by feature)
- `src/pages/` or `src/app/` — Route-level pages/layouts
- `src/hooks/` — Custom hooks
- `src/lib/` — Utility functions, constants, helpers
- `src/styles/` — Global styles, theme, design tokens
- `src/types/` — Shared TypeScript types/interfaces
- `src/assets/` — Static images, fonts, icons
- `public/` — Public static files

### `/apps/api/` — Backend
- `src/routes/` — API route handlers (grouped by resource)
- `src/middleware/` — Auth, validation, rate limiting, error handling
- `src/services/` — Business logic layer (NO direct DB calls in routes)
- `src/models/` — Data models / schemas
- `src/lib/` — Shared utilities, constants
- `src/types/` — Backend-specific types
- `src/jobs/` — Background jobs, cron tasks, queues

### `/packages/shared/` — Shared Code
- `src/types/` — Types shared between frontend and backend
- `src/utils/` — Utility functions used by both apps
- `src/constants/` — Shared constants, enums, config values

### `/database/`
- `migrations/` — Numbered SQL migration files
- `seeds/` — Seed data for dev/test environments
- `schemas/` — Table definitions, RLS policies, functions

### `/docs/`
- `architecture/` — System design, ADRs (Architecture Decision Records)
- `api/` — API endpoint documentation
- `guides/` — Developer onboarding, setup, workflows
- `runbooks/` — Incident response, deployment procedures

### `/scripts/`
- `setup.sh` — First-time project setup
- `dev.sh` — Start local dev environment
- `lint.sh` — Run all linters
- `deploy.sh` — Deployment helper
- `db-migrate.sh` — Run database migrations

### `/infrastructure/`
- `docker/` — Dockerfiles, docker-compose
- `ci/` — CI/CD pipeline configs (GitHub Actions, etc.)
- `terraform/` or `iac/` — Infrastructure as code (if applicable)

### `/tests/`
- `e2e/` — End-to-end tests
- `integration/` — Integration tests
- `fixtures/` — Shared test data

### Root files (create these as empty or minimal placeholders)
- `.gitignore`
- `.env.example` — Document ALL required env vars (never commit .env)
- `README.md` — Project name, one-line description, setup instructions placeholder
- `CLAUDE.md` — AI assistant instructions for this project

## Rules
1. Every directory gets a one-line README.md explaining what goes there
2. Do NOT pick a framework — keep it generic so I choose later
3. Do NOT install dependencies
4. Do NOT write application code
5. Use kebab-case for folder names
6. The structure should work for Next.js, SvelteKit, Express, FastAPI, or any stack
```
