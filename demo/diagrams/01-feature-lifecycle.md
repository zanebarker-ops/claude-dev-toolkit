# Diagram 1 — Feature Lifecycle

The path a single feature takes from "user files an issue" to "merged in production." Every step is enforced by a hook, a hookify rule, or a non-negotiable workflow rule.

```mermaid
flowchart TD
    A[Issue filed on project board] --> B[bd create — persistent memory]
    B --> C[git worktree add — isolated workspace]
    C --> D{Confidence Gate<br/>≥ 8/10?}
    D -- No --> E[Ask clarifying questions<br/>requirements, scope, security, edge cases]
    E --> D
    D -- Yes --> F[Write code in worktree]
    F --> G[Hooks fire on every tool call]
    G --> H{Hook gates pass?}
    H -- block --> F
    H -- allow --> I[Lint + typecheck<br/>scripts/lint-worktree.sh]
    I --> J[Push branch — Vercel preview deploys]
    J --> K[Before/after screenshots]
    K --> L[/security-auditor — MANDATORY/]
    L --> M[/vote-for-pr — 5 reviewer agents/]
    M --> N{All approve?}
    N -- No --> F
    N -- Yes --> O[gh pr create → target dev]
    O --> P[CI gate: check-vercel-before-pr]
    P --> Q[Human review + merge]
    Q --> R[bd close — sync via git]
    R --> S[Scheduled cloud routine<br/>verifies prod deployment]

    classDef gate fill:#fff3cd,stroke:#856404,color:#000
    classDef block fill:#f8d7da,stroke:#721c24,color:#000
    classDef green fill:#d4edda,stroke:#155724,color:#000
    class D,H,N gate
    class L,M,P block
    class B,C,F,J,Q,R,S green
```

**Key beats for the demo:**

1. **Issue → bead → worktree are non-negotiable.** A `UserPromptSubmit` hook detects new tasks and reminds the operator to create all three before any code touches disk.
2. **The Confidence Gate is the most underrated step.** Forcing the orchestrator to reach 8/10 confidence *before* writing code prevents 60% of throwaway implementations.
3. **Hooks intercept tool calls in real time.** A `PreToolUse:Edit` hook can block a write to `.env` files. A `PreToolUse:Bash` hook can block `git push origin main`.
4. **`/security-auditor` is the only mandatory agent.** Everything else is right-sized by the orchestrator.
5. **The loop closes with a scheduled cloud routine.** A separate Claude agent runs on cron 24-72 hours post-merge to verify the fix actually shipped to prod (catches silent failures).
