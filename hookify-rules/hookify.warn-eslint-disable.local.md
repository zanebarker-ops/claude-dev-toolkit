---
name: warn-eslint-disable
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: \.(ts|tsx|js|jsx)$
  - field: new_text
    operator: regex_match
    pattern: eslint-disable(-next-line)?
---

**eslint-disable comment detected!**

**Do NOT use `eslint-disable` comments as workarounds.**

**Why this is blocked:**
- Disabling lint rules hides real problems instead of fixing them
- This caused broken Vercel deployments (GH-644)
- Future developers won't know why rules were disabled

**How to fix properly:**
1. **Unused variables**: Remove the unused import/variable
2. **Missing types**: Add proper types instead of `any`
3. **Type imports**: Use `import type { X }` for type-only imports
4. **Unused parameters**: Remove or prefix with `_` only if API requires signature

**Example fixes:**

```typescript
// BAD - Don't do this:
// eslint-disable-next-line @typescript-eslint/no-unused-vars
async function getHandler(_request: NextRequest) {

// GOOD - Remove unused parameter:
async function getHandler() {
```

```typescript
// BAD - Don't do this:
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const data: any = await fetch(...)

// GOOD - Add proper types:
interface ApiResponse { ... }
const data: ApiResponse = await fetch(...)
```

**If you genuinely need to disable a rule:** Add a comment explaining WHY, and get tech lead approval.
