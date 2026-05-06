# Demo slides

[Slidev](https://sli.dev/) presentation: production-grade Claude Code workflows.

## Run locally

```bash
cd demo/slides
npm install
npm run dev      # opens http://localhost:3030
```

Press `o` to enter overview mode. `Ctrl+Shift+P` for presenter mode (notes + clock + next-slide preview).

## Build static site

```bash
npm run build    # → dist/
```

## Export PDF

```bash
npm run export-pdf    # → dist/slides.pdf
```

## Structure

The deck is a single `slides.md` with ~30 slides across:

1. **Act 1 — Setup** (CLAUDE.md, hooks, hookify, MCPs)
2. **Act 2 — Workflow** (issue → bead → worktree → confidence gate → PR)
3. **Act 3 — Agents** (orchestrator + 26 specialists, model economics)
4. **Act 4 — Claude Routines** (the headline — cron agents that verify outcomes)
5. **Take-home** (the toolkit)

Speaker notes are inline in `slides.md` as HTML comments at the bottom of each slide. The full narrator script with talking points and Q&A is in `../talking-points.md`. The live demo runbook is in `../runbook.md`.

## Customizing

- **Theme:** change `theme: seriph` in the frontmatter to `default` or another installed theme.
- **Background:** edit `background:` URL in frontmatter.
- **Fonts:** edit the `fonts:` block in frontmatter.
- **Custom CSS:** edit `style.css` in this folder.

## Deploying to GitHub Pages

A workflow at `.github/workflows/deploy-slides.yml` builds and deploys on every push to `master`. The slides will be live at:

`https://zanebarker-ops.github.io/claude-dev-toolkit/`
