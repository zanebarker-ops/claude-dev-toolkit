# SaaS Agent Team Generator - Master Prompt

Use this prompt to generate a complete multi-agent development and business operations system for any SaaS platform.

---

## Instructions

**Copy this entire prompt and replace the placeholders in the BUSINESS CONTEXT section with your specific information. Then run it to generate all agents, workflows, and orchestration systems.**

---

# GENERATE COMPLETE AGENT TEAM FOR SAAS PLATFORM

You are an expert AI system architect. Your task is to generate a comprehensive multi-agent system for a SaaS platform, including:

1. **Development Agents** (9 agents for coding, testing, deployment)
2. **Business Operations Agents** (5 agents for customer success, marketing, analytics)
3. **Orchestration Workflows** (Agent coordination and execution)
4. **Claude Hooks** (5 event-driven automation hooks)
5. **Git Flow Setup** (Branching strategy and worktrees)
6. **Foundational Files** (README, .gitignore, .env.example, configs, CI/CD, Docker)
7. **Documentation** (CLAUDE.md, workflows, conventions)

Generate all agents as slash commands in `.claude/commands/` directory, all hooks in `.claude/hooks/`, and all foundational files in appropriate locations - all optimized for the specific business context provided below.

---

## BUSINESS CONTEXT

**Replace these placeholders with your specific information:**

### Company Information

```yaml
company:
  name: "[YOUR_COMPANY_NAME]"
  product: "[DESCRIBE YOUR PRODUCT IN 1-2 SENTENCES]"
  tagline: "[YOUR TAGLINE]"

industry:
  vertical: "[YOUR INDUSTRY - e.g., HealthTech, EdTech, FinTech, DevTools, etc.]"
  regulatory_environment: "[Any compliance requirements - e.g., HIPAA, COPPA, GDPR, SOC2, or None]"

target_market:
  primary_persona: "[PRIMARY CUSTOMER - job title/role, company type, key pain point]"
  # Example: "CTOs at Series A-B SaaS startups managing 10-50 engineers"

  geography: "[Target markets - e.g., United States, Global, EU]"

  company_size: "[B2B: SMB/Mid-Market/Enterprise] or [B2C: describe demographic]"

business_model:
  revenue_streams:
    - type: "[e.g., Freemium + Subscriptions, Usage-Based, Per-Seat, etc.]"
      pricing: "[e.g., $0-$500/month, $10/user/month]"

  pricing_tiers:
    - name: "[Tier 1 Name, e.g., Free]"
      price: "[Price]"
      features: "[Key features and limits]"

    - name: "[Tier 2 Name, e.g., Pro]"
      price: "[Price]"
      features: "[Key features]"

    - name: "[Tier 3 Name, e.g., Enterprise]"
      price: "[Price]"
      features: "[Key features]"
```

### Services/Products Offered

```yaml
services:
  - name: "[Core Feature 1]"
    price: "[Included/Price]"
    description: "[What it does]"
    target: "[Who uses it]"

  - name: "[Core Feature 2]"
    price: "[Included/Price]"
    description: "[What it does]"
    target: "[Who uses it]"

products:
  - name: "[Product/Report/Tool 1]"
    type: "[ACCESS/DOWNLOADABLE/API]"
    price: "[Free/Paid]"
    description: "[What it is]"
```

### Technical Stack

```yaml
tech_stack:
  frontend:
    framework: "[e.g., Next.js 14, Remix, SvelteKit, React + Vite]"
    language: "[TypeScript/JavaScript]"
    styling: "[Tailwind CSS, CSS Modules, etc.]"
    ui_library: "[shadcn/ui, Radix, MUI, Ant Design, etc.]"

  backend:
    framework: "[Next.js API Routes, Express, Fastify, Django, Rails, etc.]"
    language: "[TypeScript, Python, Ruby, Go, etc.]"

  database:
    type: "[PostgreSQL, MySQL, MongoDB, etc.]"
    provider: "[Supabase, PlanetScale, Neon, RDS, etc.]"

  authentication:
    provider: "[Supabase Auth, Auth0, NextAuth, Clerk, etc.]"

  payments:
    provider: "[Stripe, LemonSqueezy, Paddle, etc.]"

  email:
    provider: "[Resend, SendGrid, Postmark, SES, etc.]"

  hosting:
    app: "[Vercel, Netlify, Railway, Fly.io, AWS, etc.]"
    automation: "[Railway, Fly.io, etc. - for background workers/n8n]"

  monitoring:
    error_tracking: "[Sentry, Datadog, built-in, etc.]"
    analytics: "[Vercel Analytics, PostHog, Mixpanel, etc.]"

  automation:
    workflow_engine: "[n8n, Trigger.dev, custom workers, etc.]"
    ai_analysis: "[OpenAI, Anthropic, etc. - if applicable]"
```

### Brand Voice & Positioning

```yaml
brand:
  voice_characteristics:
    - "[Voice trait 1 - e.g., 'Professional and direct']"
    - "[Voice trait 2 - e.g., 'Educational and empowering']"
    - "[Voice trait 3 - e.g., 'Technical but accessible']"

  tone:
    do_use:
      - "[Phrase style or example]"
      - "[Phrase style or example]"

    dont_use:
      - "[What to avoid]"
      - "[What to avoid]"

  positioning:
    primary: "[Your main positioning statement]"
    differentiators:
      - "[Differentiator 1]"
      - "[Differentiator 2]"
      - "[Differentiator 3]"
```

---

## GENERATION INSTRUCTIONS

### Phase 1: Project Setup

Create the following directory structure:

```
.claude/
├── commands/              # Agent slash commands
├── hooks/                 # Event-driven automation hooks
├── worktree-workflow.md   # Git Flow and processes
├── hookify-rules.md       # Hook documentation
├── CLAUDE.md              # Main project instructions
└── prp-templates/         # PRP templates

.github/
└── workflows/             # CI/CD automation

docs/
├── architecture/          # Technical architecture
└── api/                   # API documentation

PRPs/                      # Product Requirement Plans

# Root level files
.gitignore                 # Git ignore patterns
.env.example               # Environment variable template
README.md                  # Project documentation
```

---

### Phase 2: Generate Development Agents

Create these 9 development agents as `.claude/commands/[agent-name].md`:

#### 1. Project Manager (`project-manager.md`)
**Purpose**: Breaks down PRDs into tasks, delegates to agents, tracks progress
**Must include**: 8-phase development workflow, worktree setup commands, task breakdown template, agent delegation guide
**Customize**: Tier features, critical integrations, compliance requirements

#### 2. Software Architect (`software-architect.md`)
**Purpose**: Designs schemas, API contracts, and architecture for features
**Must include**: Table structure template (with RLS), API route template, server action template, architecture diagram template, key tables reference
**Customize**: Tech stack, key entity relationships, integration patterns for your services

#### 3. Backend Developer (`backend-developer.md`)
**Purpose**: Builds API routes, server actions, and integrates third-party services
**Must include**: GET/POST endpoint patterns, server action pattern, subscription tier logic, Stripe webhook pattern, error response standard
**Customize**: Database client imports, auth patterns, specific integrations (payments, email, AI)

#### 4. Frontend Developer (`frontend-developer.md`)
**Purpose**: Builds UI components and pages using the tech stack
**Must include**: Server/client component patterns, form with server action, layout structure, shadcn/ui usage, styling guidelines, accessibility requirements
**Customize**: Tech stack, domain-specific component examples (replace with YOUR entity names)

#### 5. Test Automation Expert (`test-automation.md`)
**Purpose**: Creates unit, integration, E2E, and security tests
**Must include**: Testing pyramid, Vitest unit test pattern, API route test pattern, E2E Playwright pattern, RLS security test, vitest config
**Customize**: Domain-specific test data (use YOUR entity names, not generic examples)

#### 6. Security Auditor (`security-auditor.md`)
**Purpose**: Reviews code for auth issues, RLS gaps, and compliance concerns
**Must include**: Auth checklist, RLS checklist, input validation checklist, compliance requirements for your industry
**Customize**: Compliance regulations (COPPA, HIPAA, GDPR, etc.), specific table access patterns

#### 7. Code Reviewer (`code-reviewer.md`)
**Purpose**: Reviews code quality, patterns, and conventions
**Must include**: Conventional commits, TypeScript best practices, React patterns, API route conventions, error handling patterns
**Customize**: Project-specific conventions, banned patterns, required patterns

#### 8. Bug Finder (`bug-finder.md`)
**Purpose**: Finds bugs, edge cases, and failure modes
**Must include**: Race conditions, null handling, async bugs, RLS bypass risks, subscription tier edge cases
**Customize**: Domain-specific edge cases relevant to YOUR business logic

#### 9. DevOps/Infrastructure (`devops-infrastructure.md`)
**Purpose**: Manages deployments, migrations, and monitoring
**Must include**: Vercel deployment commands, migration procedure, migration template (with RLS), backup strategy, CI/CD pipeline
**Customize**: Hosting URLs, database connection details, automation platform config

---

### Phase 3: Generate Business Operations Agents

Create these 5 business agents as `.claude/commands/[agent-name].md`:

#### 1. Customer Support (`customer-support.md`)
**Purpose**: Handles customer inquiries with empathy and accuracy
**Must include**: Brand voice guidelines, common scenario scripts (login, billing, features, onboarding), escalation guidelines, response template
**Customize**: Product-specific scenarios, actual pricing/features, product name/brand voice

#### 2. Sales/Onboarding (`sales-onboarding.md`)
**Purpose**: Guides prospects through purchase and ensures successful activation
**Must include**: Tier recommendation guide with discovery questions, objection handling scripts, onboarding success guide, upgrade conversation triggers
**Customize**: Actual pricing, tier features, your specific objections, first value moment

#### 3. Marketing Content (`marketing-content.md`)
**Purpose**: Creates brand-consistent marketing content
**Must include**: Blog post template, social media templates (educational, feature highlight), email welcome sequence, website copy templates, ad copy templates, SEO keywords
**Customize**: Brand voice, target audience language, industry keywords, product use cases

#### 4. Data Analyst (`data-analyst.md`)
**Purpose**: Analyzes metrics and generates business reports
**Must include**: Revenue metrics (MRR, churn, LTV), user metrics (activation, retention), SQL query templates, weekly report template, monthly revenue report template
**Customize**: YOUR table names, YOUR pricing (for MRR calculations), YOUR feature names for adoption tracking

#### 5. Knowledge Base (`knowledge-base.md`)
**Purpose**: Authoritative source of truth for product and technical information
**Must include**: Company overview, subscription tiers, core features, technical architecture, key URLs, database tables, domain knowledge, process knowledge, FAQ
**Customize**: Replace ALL placeholder text with actual product information

---

### Phase 4: Generate Orchestration Agent

#### Start Task (`start-task.md`)
**Purpose**: Master orchestrator - coordinates all other agents for any task
**Must include**: Mandatory startup sequence (GH issue → worktree), specialist agent reference table, right-sizing rules, parallelization guide, mandatory completion sequence
**Customize**: Worktree paths, optional Beads/persistent memory integration

---

### Phase 5: Generate Claude Hooks

Create 5 hooks in `.claude/hooks/`:

#### 1. `task-setup-workflow.sh` (UserPromptSubmit)
Triggers on every new prompt. Guides user to:
1. Create GitHub issue (if task involves code changes)
2. Create worktree for the issue
3. Optional: Create persistent memory entry (if memory tool available)

#### 2. `security-check.sh` (PreToolUse - Edit/Write)
Triggers before file edits. Checks for:
- Service role keys in client-side code
- `CREATE TABLE` without RLS enabled
- Hardcoded secrets or credentials
- Auth bypass patterns

#### 3. `enforce-worktree-path.sh` (PreToolUse - Edit/Write)
Triggers before file edits. Ensures edits only happen in worktrees (not directly on dev/main branches). Derives project name dynamically from git root.

#### 4. `agent-review-reminder.sh` (PostToolUse - Bash)
Triggers after git push. Reminds to:
- Wait for CI/CD to pass
- Run security audit before PR creation

#### 5. `database-update-reminder.sh` (PostToolUse - Edit/Write)
Triggers after SQL/migration file edits. Reminds to:
- Verify RLS policies are included
- Apply migration to staging before production
- Update schema documentation

---

### Phase 6: Generate Foundational Files

Create these infrastructure files:

#### CLAUDE.md (Project Instructions)
**Critical sections to include:**
1. Database location (cloud vs local)
2. Primary codebase path
3. Development workflow (CI/CD-first, no local servers)
4. Security requirements (RLS, service role key rules)
5. Branch protection rules (feature branches → PRs)
6. Worktree-first workflow
7. Confidence Gate (8/10 rule)
8. 10 Non-Negotiable Workflow Rules
9. Agent system overview
10. Documentation requirements

#### `.env.example`
Include all required environment variables with comments:
```
# Database
NEXT_PUBLIC_[DB]_URL=
[DB]_SERVICE_ROLE_KEY=    # NEVER expose client-side

# Auth
[AUTH_PROVIDER]_SECRET=

# Payments (use test keys in development)
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=

# Email
[EMAIL_PROVIDER]_API_KEY=

# AI (if applicable)
OPENAI_API_KEY=

# Feature flags (optional)
```

#### README.md
Include:
- Project description and purpose
- Architecture overview
- Quick start guide
- Development workflow summary
- Links to key documentation

#### `docs/reference/standards/conventions.md`
Include:
- Naming conventions
- File structure conventions
- Database conventions (RLS, naming)
- API conventions
- Component conventions

---

### Phase 7: Generate PRP Template

Create `prp-templates/feature-prp-template.md` with:
- Overview section
- Context & documentation section
- Implementation plan (files to create/modify)
- Database changes section (with RLS template)
- Validation gates
- Manual verification checklist
- Error handling & edge cases
- Confidence score

---

## OUTPUT FORMAT

When generating, create each file completely - do not truncate or summarize. Every agent should be:

1. **Immediately usable** - Copy-paste into any project, customize the business context
2. **Comprehensive** - Contains all patterns and examples needed
3. **Project-specific** - References YOUR entity names, tech stack, and domain concepts
4. **Interconnected** - Agents reference each other where appropriate (e.g., security-auditor in project-manager)

Start with CLAUDE.md, then the orchestration agent (start-task.md), then development agents, then business agents, then hooks, then infrastructure files.

---

$ARGUMENTS
