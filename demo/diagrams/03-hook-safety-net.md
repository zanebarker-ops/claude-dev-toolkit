# Diagram 3 — The Hook Safety Net

Hooks are scripts that fire on Claude Code events: `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`. They turn policy documents into enforcement.

The model is the worker. The hooks are the guardrails.

```mermaid
flowchart TB
    USER[User prompt] --> SUBMIT[UserPromptSubmit hooks]
    SUBMIT --> CRASH[wsl-crash-recovery.sh<br/>show continuation prompts]
    SUBMIT --> SETUP[task-setup-workflow.sh<br/>remind: issue+bead+worktree]
    SUBMIT --> REVIEW[agent-review-reminder.sh<br/>nudge security-auditor]
    SUBMIT --> MODEL[Claude model decides next tool call]

    MODEL --> PREEDIT[PreToolUse:Edit/Write hooks]
    PREEDIT --> CW[check-worktree.sh<br/>block edits in main repo]
    PREEDIT --> CCW[check-cross-worktree.sh<br/>block edits outside CWD worktree]
    PREEDIT --> DBI[database-context-injector.sh<br/>inject schema on .sql edits]

    MODEL --> PREBASH[PreToolUse:Bash hooks]
    PREBASH --> BMD[block-direct-main-dev<br/>hookify rule]
    PREBASH --> GIT[gitleaks-scan.sh<br/>secret scanning on commits]
    PREBASH --> VC[check-vercel-before-pr.sh<br/>block PR until preview is green]

    MODEL --> PREREAD[PreToolUse:Read hooks]
    PREREAD --> ENV[block-env-read.sh<br/>refuse credential leaks]

    MODEL --> POST[PostToolUse hooks]
    POST --> PWC[post-worktree-cleanup.sh<br/>cleanup on git worktree remove]
    POST --> DUR[database-update-reminder.sh<br/>nudge doc updates after schema changes]

    MODEL --> STOP[Stop hooks]
    STOP --> QA[qa-review-prompt.sh<br/>final QA gate before turn ends]

    classDef hook fill:#f8d7da,stroke:#842029,color:#000
    classDef event fill:#cfe2ff,stroke:#084298,color:#000
    classDef model fill:#fff3cd,stroke:#664d03,color:#000
    class SUBMIT,PREEDIT,PREBASH,PREREAD,POST,STOP event
    class CRASH,SETUP,REVIEW,CW,CCW,DBI,BMD,GIT,VC,ENV,PWC,DUR,QA hook
    class MODEL model
```

**The two superpowers of hooks:**

1. **Block (exit 2)** — Stops the tool call. The model sees the stderr message and adjusts. Use for hard rules: don't edit `.env`, don't push to `main`, don't read credentials.
2. **Inform (exit 0 + stderr)** — Tool call proceeds, but the model is given context. Use for soft rules: warn about RLS on `CREATE TABLE`, remind about doc updates after schema changes.

**Demo moment**: in the live walkthrough, type `Read .env` into Claude Code. Watch `block-env-read.sh` refuse the operation in real time. The model immediately apologizes and pivots. *That's* the safety net.
