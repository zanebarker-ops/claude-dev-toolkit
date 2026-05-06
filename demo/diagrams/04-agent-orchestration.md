# Diagram 4 — Agent Orchestration

The orchestrator (Opus 4.6 or Opus 4.7) is a router, not a worker. It reads the task, picks the right specialists, parallelizes when safe, and skips agents that aren't needed.

This replaced an older pipeline that *always* ran 8 agents in sequence. CSS fix? 8 agents. Typo? 8 agents. Burning Opus quota for no reason.

```mermaid
flowchart TD
    TASK[/start-task &quot;...&quot;] --> ORCH{{Opus orchestrator<br/>reads task, picks agents}}

    ORCH -->|small fix| DIRECT[Direct edit, no agents]
    ORCH -->|bug 1-3 files| DBG[/debug + /security-auditor only if auth/]
    ORCH -->|small feature| MID[3-5 specialists in parallel]
    ORCH -->|large feature| PRP[/generate-prp first, then specialists]

    MID --> ARCH[/software-architect<br/>schema, API design]
    MID --> BE[/backend-developer<br/>API routes, Supabase]
    MID --> FE[/frontend-developer<br/>React components]
    MID --> TEST[/test-automation<br/>E2E, unit]
    MID --> DOCS[/documentation-writer<br/>ADRs, README]

    ARCH --> SEC[/security-auditor<br/>MANDATORY before PR]
    BE --> SEC
    FE --> SEC
    TEST --> SEC
    DOCS --> SEC

    SEC --> VOTE[/vote-for-pr — 5 reviewers/]
    VOTE --> CR[code-reviewer]
    VOTE --> SF[silent-failure-hunter]
    VOTE --> PT[pr-test-analyzer]
    VOTE --> CA[comment-analyzer]
    VOTE --> TD[type-design-analyzer]

    CR --> CONS{Consensus?}
    SF --> CONS
    PT --> CONS
    CA --> CONS
    TD --> CONS

    CONS -- approve --> PR[Open PR]
    CONS -- block --> MID

    classDef orch fill:#fff3cd,stroke:#664d03,color:#000
    classDef gate fill:#f8d7da,stroke:#842029,color:#000
    classDef agent fill:#cfe2ff,stroke:#084298,color:#000
    class ORCH,CONS orch
    class SEC gate
    class ARCH,BE,FE,TEST,DOCS,CR,SF,PT,CA,TD,DBG agent
```

**The economics:**

| Task type | Old pipeline | New orchestration | Savings |
|---|---|---|---|
| 1-line typo fix | 8 agents (all sequential) | 0 agents (direct edit) | ~95% |
| Bug fix, 1-3 files | 8 agents | 1-2 agents (`/debug`) | ~75% |
| Small feature, 3-7 files | 8 agents (sequential) | 4-5 agents (parallel) | ~40% wall-clock |
| Large feature, 8+ files | 8 agents (sequential) | `/generate-prp` + specialists per plan | Better quality |

**Model selection rules** (committed in `templates/model-selection.md`):

- **Opus 4.7**: orchestration, complex implementations, security audits, architecture decisions
- **Sonnet 4.6**: routine code review, simple fixes, doc writing, PRP authoring
- **Haiku 4.5**: triage, classification, summarization

Per-PRP `Recommended Model` field forces the choice. No more wasting 200/wk Opus quota on linting fixes.

**Non-negotiable: `/security-auditor` runs before any PR touching auth, RLS, user data, or payments.** Output must be `✅ SECURITY APPROVED` or all `❌ SECURITY BLOCK` items fixed. No exceptions.
