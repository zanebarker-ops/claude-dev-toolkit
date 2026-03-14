# Execute PRP (Product Requirements Plan)

You are implementing a feature using a pre-generated PRP document. The PRP contains all the context you need.

## Your Task

Execute the implementation plan in the PRP with precision, following every specification exactly.

## Step 1: Load the PRP

Read the PRP file: `PRPs/$ARGUMENTS-prp.md`

If the file doesn't exist, list available PRPs:
```bash
ls PRPs/
```

Then ask the user which one to execute.

## Step 2: Gather Additional Context

Even though the PRP should be comprehensive, quickly verify:

1. **Read referenced files** - Any existing code mentioned in the PRP
2. **Check examples/** - Review patterns referenced in the PRP
3. **Verify current state** - Make sure nothing has changed since PRP creation

If you discover the codebase has changed significantly since the PRP was created, STOP and inform the user. The PRP may need regeneration.

## Step 3: Create Task List

Use the TodoWrite tool to create a detailed task list from the PRP's implementation steps.

Break down each step into atomic tasks:
- One task per file creation
- One task per significant modification
- Separate tasks for database changes
- Final tasks for validation

## Step 4: Execute Implementation

Work through each task systematically:

### For Each Task:
1. Mark it as `in_progress`
2. Implement exactly as specified in the PRP
3. If the PRP includes code snippets, use them as the foundation
4. Follow project conventions:
   - Use established patterns for auth/user context (check existing code)
   - Import from established lib paths
   - Use existing UI components where available
5. Mark task as `completed` immediately when done

### If You Encounter Issues:
- **Missing information**: Check if PRP has guidance in "Error Handling" section
- **Code doesn't compile**: Fix the issue, note it for the validation phase
- **Pattern unclear**: Reference `examples/` folder
- **Blocked**: Do NOT skip. Stop and ask the user.

## Step 5: Run Validation Gates

After implementation, run ALL validation commands from the PRP:

```bash
# Standard validation gates (adjust paths for your project)
npx tsc --noEmit
npm run lint
npm run build
```

### If Validation Fails:

1. Read the error carefully
2. Check if PRP mentions this error pattern
3. Fix the issue
4. Re-run validation
5. Repeat until all gates pass

**Do NOT mark the feature complete until all validation gates pass.**

## Step 6: Manual Verification Checklist

Go through the PRP's manual verification checklist:

- [ ] Feature works as expected
- [ ] No console errors in browser
- [ ] Responsive design works
- [ ] Dark/light theme displays correctly
- [ ] All edge cases handled

## Step 7: Complete

Once all validation gates pass and manual checklist is verified:

1. Mark all todos as completed
2. Summarize what was implemented
3. List any deviations from the PRP (and why)
4. Report final status

## Important Rules

### DO:
- Follow the PRP exactly as written
- Use TodoWrite to track every step
- Run validation gates before claiming completion
- Ask for help if truly blocked

### DO NOT:
- Skip validation gates
- Improvise when the PRP is clear
- Add features not in the PRP
- Mark tasks complete before they're done
- Guess at missing information

## Output Format

When complete, provide:

```
## Implementation Complete

### Summary
{What was built}

### Files Created/Modified
- `path/to/file.tsx` - {description}
- `path/to/file.tsx` - {description}

### Validation Results
- TypeScript: ✅ Pass
- Linting: ✅ Pass
- Build: ✅ Pass

### Deviations from PRP
{Any changes made and why, or "None"}

### Ready for Review
{Link to relevant files or "Ready to test at [URL]"}
```

$ARGUMENTS
