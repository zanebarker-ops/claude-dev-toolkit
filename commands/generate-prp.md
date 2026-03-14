# Generate PRP (Product Requirements Plan)

You are creating a comprehensive implementation plan for a feature. This plan will be used by another Claude session to implement the feature with full context.

## Your Task

Create a PRP document in the `PRPs/` folder that contains EVERYTHING needed to implement this feature in one pass.

## Step 1: Understand the Request

Read the user's feature request carefully. If they provided an `INITIAL.md` file, read it first.

Ask clarifying questions if:
- The scope is unclear
- There are multiple valid approaches
- You need to know about edge cases
- Integration points are ambiguous

## Step 2: Research the Codebase

Before writing anything, gather context:

### 2.1 Check Existing Patterns
```
Search for similar implementations:
- Glob for related components: **/*{keyword}*.tsx
- Grep for similar functionality
- Read existing pages/components that do similar things
```

### 2.2 Review Project Documentation
Read these files for context:
- `@.claude/CLAUDE.md` - Project overview
- `@docs/reference/standards/conventions.md` - Coding standards
- `@docs/reference/architecture/` - Architecture patterns
- Any relevant system documentation

### 2.3 Check Examples Folder
Review `examples/` for canonical patterns to follow.

### 2.4 Identify Integration Points
- **Database**: What tables/access control policies are needed?
- **Background Jobs**: Any workflow triggers needed?
- **API Routes**: New endpoints required?
- **Components**: Existing UI components to use?

## Step 3: Write the PRP

Create a file: `PRPs/{feature-name}-prp.md`

Use this structure:

```markdown
# PRP: {Feature Name}

## Overview
{2-3 sentence summary of what we're building}

## Related GitHub Issue
{Link to issue if applicable}

---

## Context & Documentation

### Project-Specific Context
- Auth handling: [how auth is done in this project]
- Database access: [how DB queries are made]
- Theme/styling: [design system to follow]

### Relevant Documentation
{Links to any external docs, API references, library guides}

### Existing Code to Reference
{List specific files that show patterns to follow}
- `src/app/{similar-page}/page.tsx`
- `src/components/{similar-component}.tsx`

### Code Examples
{Paste or reference specific code patterns from examples/ folder}

---

## Implementation Plan

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `path/to/file.tsx` | Create | Description |
| `path/to/existing.tsx` | Modify | What changes |

### Step-by-Step Implementation

#### Step 1: {Name}
{Detailed description}
{Pseudocode or code snippet}

#### Step 2: {Name}
{Detailed description}
{Pseudocode or code snippet}

{Continue for all steps...}

---

## Database Changes (if any)

### New Tables
```sql
-- Table definition
```

### Access Control Policies
```sql
-- Policy definitions
```

### Migrations
{How to apply these changes}

---

## Validation Gates

These commands MUST pass before the feature is complete:

```bash
# Type checking
npx tsc --noEmit

# Linting
npm run lint

# Build
npm run build

# Tests (if applicable)
npm run test
```

### Manual Verification
- [ ] Feature works as expected in browser
- [ ] No console errors
- [ ] Responsive on mobile
- [ ] Dark/light theme looks correct

---

## Error Handling & Edge Cases

| Scenario | How to Handle |
|----------|---------------|
| {Edge case 1} | {Solution} |
| {Edge case 2} | {Solution} |

---

## Checklist

- [ ] All files created/modified as specified
- [ ] Follows project conventions
- [ ] Uses existing UI components where possible
- [ ] Access control policies in place for any new tables
- [ ] Validation gates pass
- [ ] Manual verification complete

---

## Confidence Score

{1-10 score on likelihood of one-pass implementation success}

**Reasoning:** {Why this score}
```

## Step 4: Save and Report

1. Save the PRP to `PRPs/{feature-name}-prp.md`
2. Tell the user the PRP is ready
3. Summarize what you included
4. Report your confidence score
5. Ask if they want to proceed with `/execute-prp {feature-name}`

## Important Reminders

- **Be thorough**: The executing Claude only sees what's in the PRP
- **Include code**: Pseudocode and snippets are valuable
- **Reference examples**: Point to `examples/` folder patterns
- **Think about access control**: Every DB query needs proper policies
- **Don't assume**: If unsure, research or ask

$ARGUMENTS
