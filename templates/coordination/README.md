# Agent Coordination System

This directory contains the multi-agent coordination infrastructure for projects using multiple parallel Claude Code sessions.

## Purpose

When multiple Claude Code sessions work in parallel on different worktrees, they need to:
1. Know what files other agents are editing
2. Avoid conflicts before they happen
3. Communicate status and progress
4. Coordinate on shared files

## Files

- `state.json` - Shared state file tracking all active sessions, file locks, and recent changes
- `README.md` - This file

## How It Works

### Session Registration
When a Claude Code session starts, it MUST:
1. Pull latest from dev to get current state.json
2. Read state.json to see what other agents are doing
3. Register itself with worktree name and planned work
4. Update heartbeat every 5 minutes

### File Locking
Before editing a file, agents MUST:
1. Check if file is in `fileLocks`
2. If locked by another session, WARN and coordinate
3. If not locked, add soft lock before editing
4. Release lock after committing

### Recent Changes Log
After editing a file, agents MUST:
1. Log the change to `recentChanges` array
2. Include file path, worktree, timestamp, and description
3. Keep only last 50 changes (older ones pruned)

### Conflict Detection
Before starting work, agents MUST:
1. Check `recentChanges` for files they plan to edit
2. If recent changes exist, pull latest and rebase
3. If conflicts detected, add to `conflicts` array and resolve

## State File Schema

```json
{
  "version": "1.0",
  "lastUpdated": "ISO timestamp",
  "sessions": {
    "GH-###-description": {
      "worktree": "/path/to/worktree",
      "started": "ISO timestamp",
      "lastHeartbeat": "ISO timestamp",
      "status": "active|idle|completing",
      "currentTask": "Description of current work",
      "plannedFiles": ["path/to/file1.ts", "path/to/file2.ts"]
    }
  },
  "fileLocks": {
    "relative/path/to/file.ts": {
      "lockedBy": "GH-###-description",
      "since": "ISO timestamp",
      "reason": "Why this file is locked"
    }
  },
  "recentChanges": [
    {
      "file": "relative/path/to/file.ts",
      "by": "GH-###-description",
      "at": "ISO timestamp",
      "action": "Description of change"
    }
  ],
  "conflicts": [
    {
      "file": "relative/path/to/file.ts",
      "between": ["GH-111-feature", "GH-222-other"],
      "detected": "ISO timestamp",
      "resolved": false
    }
  ]
}
```

## Rules

1. **NEVER edit a locked file** - Coordinate with the locking session first
2. **ALWAYS register your session** - Other agents need to know you exist
3. **ALWAYS log changes** - Future sessions need to know what changed
4. **ALWAYS check for conflicts** - Before starting work on any file
5. **ALWAYS release locks** - After committing your changes
6. **STALE sessions** - Sessions with heartbeat > 30 minutes are considered stale
