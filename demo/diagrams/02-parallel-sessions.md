# Diagram 2 — 15 Parallel Sessions Without Collision

How a single developer can have 15 Claude Code sessions running concurrently, each on a different feature, without merge conflicts, lost work, or "which session is editing this file?" chaos.

```mermaid
flowchart LR
    subgraph TMUX[tmux server — survives VS Code crashes]
      direction TB
      S1[Session 1<br/>GH-3301] --> W1[Worktree<br/>~/repos/x-worktrees/GH-3301]
      S2[Session 2<br/>GH-3302] --> W2[Worktree<br/>~/repos/x-worktrees/GH-3302]
      S3[Session 3<br/>GH-3303] --> W3[Worktree<br/>~/repos/x-worktrees/GH-3303]
      Sdots[…12 more…] --> Wdots[…12 more worktrees…]
    end

    W1 --> COORD[(.claude/coordination/state.json<br/>file locks · heartbeats · audit log)]
    W2 --> COORD
    W3 --> COORD
    Wdots --> COORD

    COORD --> BEADS[(.beads/issues.jsonl<br/>persistent memory<br/>committed to git)]

    HOOK[check-cross-worktree.sh<br/>blocks Edit/Write outside CWD] -.intercepts.-> W1
    HOOK -.intercepts.-> W2
    HOOK -.intercepts.-> W3

    REC[wsl-crash-recovery.sh<br/>per-PPID state, prunes >24h] -.recovers.-> TMUX

    classDef session fill:#cfe2ff,stroke:#084298,color:#000
    classDef worktree fill:#d1e7dd,stroke:#0f5132,color:#000
    classDef shared fill:#fff3cd,stroke:#664d03,color:#000
    classDef hook fill:#f8d7da,stroke:#842029,color:#000
    class S1,S2,S3,Sdots session
    class W1,W2,W3,Wdots worktree
    class COORD,BEADS shared
    class HOOK,REC hook
```

**Why this works:**

| Mechanism | What it prevents |
|---|---|
| **Worktree per feature** | Branch conflicts. Each session has its own working tree, own `.git/` index. |
| **`check-cross-worktree.sh` hook** | A session in worktree A from accidentally editing a file in worktree B. Hook returns exit 2; the model sees the error and corrects course. |
| **`state.json` file locks** | Two sessions editing the same shared file (e.g., `database.ts`). Soft locks with stale-cleanup at 30 min idle. |
| **Beads (`bd`)** | Lost context. Each session writes its task into `.beads/issues.jsonl`, committed to git, readable from any worktree. |
| **tmux** | VS Code crashes killing your work. Sessions run in tmux server independent of any IDE. |
| **`wsl-crash-recovery.sh`** | WSL2 crashes (the OS layer below tmux). On next session start, the hook detects stale state files and prints continuation prompts you copy-paste back. |

**Scale answer for the demo:** with WSL on `~/repos/` (ext4, not `/mnt/c/`), `git status` across 15 worktrees runs in <2 seconds total. On NTFS via 9P bridge, it would take 60+ seconds. **Filesystem choice is what makes 15 sessions feasible.**
