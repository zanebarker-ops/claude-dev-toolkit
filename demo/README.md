# Demo materials

This folder contains everything you need to give the **production-grade Claude Code** demo to a technical audience.

## What's here

| Path | Purpose |
|---|---|
| `slides/` | Slidev presentation (~30 slides, 5 acts + take-home). Run `npm install && npm run dev`. |
| `runbook.md` | Live demo script — exact commands to type, what to show, fallbacks for every step. |
| `talking-points.md` | Full narrator script + anticipated Q&A. |
| `diagrams/` | 5 Mermaid source diagrams referenced from the slides. |
| `case-studies/` | 3 sanitized RCAs used as story beats during the talk. |
| `routines/` | 5 copy-paste-ready Claude Routine prompt templates (the headline). |
| `asciinema/` | Pre-recorded fallback casts for live segments that may break. |
| `images/` | Screenshots / posters / thumbnails. |

## Recommended run order to prepare

1. Read `talking-points.md` start to finish — understand the arc
2. Run `slides/` locally with `npm run dev`, click through the deck
3. Read `runbook.md` and rehearse the live demos in a test repo
4. Record the asciinema fallbacks (commands in the runbook)
5. The day of the talk: run pre-flight from `runbook.md`

## The deck arc (60 min, 5 acts)

| Act | Time | Beat |
|---|---|---|
| 1. The setup | 12 min | CLAUDE.md, hooks, hookify, MCPs |
| 2. The workflow | 15 min | issue → bead → worktree → confidence gate → PR |
| 3. The agents | 10 min | orchestrator + 26 specialists, model economics |
| 4. **Claude Routines** | 15 min | cron agents that verify outcomes, not code (the headline) |
| 5. Take-home | 3 min | the toolkit |

## Live deck

Once `.github/workflows/deploy-slides.yml` runs on `master`, the deck is live at:

**https://zanebarker-ops.github.io/claude-dev-toolkit/**

## Customizing

- **Audience**: the deck is written for an external technical group with mixed Claude Code familiarity. For an internal audience that already knows Claude Code, skim Act 1 and lean harder into Act 4.
- **Length**: at 30 slides it runs ~60 min. To cut to 30 min, drop Acts 2 and 3 to a single overview slide each and keep all of Act 4.
- **Stack details**: the slides reference specific stack choices (Vercel, Supabase, Postgres, n8n). Edit `slides/slides.md` to swap in your stack.

## Sanitization rules used in this folder

- Real GitHub issue numbers → `GH-XXXX`
- Internal URLs → `<your-prod-url>` placeholders
- Database project IDs → `<project-id>`
- Employee emails → `developer@example.com`

If you spot a real ID or URL, file an issue.
