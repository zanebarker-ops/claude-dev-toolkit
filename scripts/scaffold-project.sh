#!/bin/bash
# scaffold-project.sh - Create a production-ready monorepo folder structure
#
# Usage:
#   ./scaffold-project.sh /path/to/new-project
#   ./scaffold-project.sh .                        # Current directory
#
# Creates a framework-agnostic full-stack folder structure with
# placeholder README.md files in each directory.

set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}✓${NC} $1"; }
section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }
error()   { echo -e "${RED}✗${NC} $1"; }

TARGET="${1:-.}"

if [ "$TARGET" != "." ] && [ ! -d "$TARGET" ]; then
  mkdir -p "$TARGET"
  info "Created $TARGET"
fi

TARGET="$(cd "$TARGET" && pwd)"
PROJECT_NAME=$(basename "$TARGET")

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Project Scaffold${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Target:   $TARGET"
echo "  Project:  $PROJECT_NAME"
echo ""

readme() {
  local dir="$1"
  local desc="$2"
  mkdir -p "$TARGET/$dir"
  echo "# $(basename "$dir")" > "$TARGET/$dir/README.md"
  echo "" >> "$TARGET/$dir/README.md"
  echo "$desc" >> "$TARGET/$dir/README.md"
  info "$dir/"
}

# ── Frontend ──────────────────────────────────────────────────
section "Frontend (apps/web)"
readme "apps/web/src/components"  "Reusable UI components, organized by feature."
readme "apps/web/src/app"         "Route-level pages and layouts."
readme "apps/web/src/hooks"       "Custom hooks."
readme "apps/web/src/lib"         "Utility functions, constants, and helpers."
readme "apps/web/src/styles"      "Global styles, theme, and design tokens."
readme "apps/web/src/types"       "Shared TypeScript types and interfaces."
readme "apps/web/src/assets"      "Static images, fonts, and icons."
readme "apps/web/public"          "Public static files served at root."

# ── Backend ───────────────────────────────────────────────────
section "Backend (apps/api)"
readme "apps/api/src/routes"      "API route handlers, grouped by resource."
readme "apps/api/src/middleware"   "Auth, validation, rate limiting, error handling."
readme "apps/api/src/services"    "Business logic layer. No direct DB calls in routes."
readme "apps/api/src/models"      "Data models and schemas."
readme "apps/api/src/lib"         "Shared utilities and constants."
readme "apps/api/src/types"       "Backend-specific types."
readme "apps/api/src/jobs"        "Background jobs, cron tasks, and queues."

# ── Shared Packages ───────────────────────────────────────────
section "Shared Packages (packages/shared)"
readme "packages/shared/src/types"     "Types shared between frontend and backend."
readme "packages/shared/src/utils"     "Utility functions used by both apps."
readme "packages/shared/src/constants" "Shared constants, enums, and config values."

# ── Database ──────────────────────────────────────────────────
section "Database"
readme "database/migrations" "Numbered SQL migration files."
readme "database/seeds"      "Seed data for dev/test environments."
readme "database/schemas"    "Table definitions, RLS policies, and functions."

# ── Documentation ─────────────────────────────────────────────
section "Documentation"
readme "docs/architecture" "System design and ADRs (Architecture Decision Records)."
readme "docs/api"          "API endpoint documentation."
readme "docs/guides"       "Developer onboarding, setup, and workflow guides."
readme "docs/runbooks"     "Incident response and deployment procedures."

# ── Scripts ───────────────────────────────────────────────────
section "Scripts"
mkdir -p "$TARGET/scripts"
for script in setup.sh dev.sh lint.sh deploy.sh db-migrate.sh; do
  cat > "$TARGET/scripts/$script" << EOF
#!/bin/bash
# $script — TODO: implement
set -euo pipefail
echo "$script not yet implemented"
EOF
  chmod +x "$TARGET/scripts/$script"
  info "scripts/$script"
done

# ── Infrastructure ────────────────────────────────────────────
section "Infrastructure"
readme "infrastructure/docker" "Dockerfiles and docker-compose."
readme "infrastructure/ci"     "CI/CD pipeline configs (GitHub Actions, etc.)."
readme "infrastructure/iac"    "Infrastructure as code (Terraform, Pulumi, etc.)."

# ── Tests ─────────────────────────────────────────────────────
section "Tests"
readme "tests/e2e"         "End-to-end tests."
readme "tests/integration" "Integration tests."
readme "tests/fixtures"    "Shared test data and fixtures."

# ── Root Files ────────────────────────────────────────────────
section "Root Files"

if [ ! -f "$TARGET/.gitignore" ]; then
  cat > "$TARGET/.gitignore" << 'EOF'
# Dependencies
node_modules/
vendor/
.venv/

# Environment
.env
.env.local
.env.*.local

# Build output
dist/
build/
.next/
out/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log
npm-debug.log*

# Test coverage
coverage/
.nyc_output/
EOF
  info ".gitignore"
fi

if [ ! -f "$TARGET/.env.example" ]; then
  cat > "$TARGET/.env.example" << EOF
# Database
DATABASE_URL=
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# Auth
AUTH_SECRET=

# App
NEXT_PUBLIC_APP_URL=http://localhost:3000
NODE_ENV=development
EOF
  info ".env.example"
fi

if [ ! -f "$TARGET/README.md" ]; then
  cat > "$TARGET/README.md" << EOF
# $PROJECT_NAME

> One-line description of the project.

## Setup

\`\`\`bash
bash scripts/setup.sh
\`\`\`

## Development

\`\`\`bash
bash scripts/dev.sh
\`\`\`

## Project Structure

\`\`\`
apps/web/          Frontend application
apps/api/          Backend API
packages/shared/   Shared types, utils, constants
database/          Migrations, seeds, schemas
docs/              Documentation
scripts/           Dev and deploy scripts
infrastructure/    Docker, CI/CD, IaC
tests/             E2E, integration, fixtures
\`\`\`
EOF
  info "README.md"
fi

if [ ! -f "$TARGET/CLAUDE.md" ]; then
  cat > "$TARGET/CLAUDE.md" << EOF
# CLAUDE.md

Project instructions for Claude Code.

## Project: $PROJECT_NAME

TODO: Add project-specific instructions, conventions, and constraints.

## Tech Stack

TODO: Define your stack (framework, language, database, hosting).

## Conventions

- Use kebab-case for file and folder names
- Business logic goes in \`apps/api/src/services/\`, not in route handlers
- Shared types go in \`packages/shared/src/types/\`
- All SQL changes go through \`database/migrations/\`
EOF
  info "CLAUDE.md"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Scaffold complete! ${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Next steps:"
echo "    cd $TARGET"
echo "    git init"
echo "    git add -A && git commit -m 'chore: initial project scaffold'"
echo ""
