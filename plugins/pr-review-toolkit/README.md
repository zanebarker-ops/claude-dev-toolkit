# PR Review Toolkit for SafeGamer

A comprehensive collection of specialized agents for thorough pull request review, customized for SafeGamer's security requirements and development practices.

## Overview

This plugin bundles 6 expert review agents that each focus on a specific aspect of code quality. Use them individually for targeted reviews or together for comprehensive PR analysis.

Based on [Anthropic's PR Review Toolkit](https://github.com/anthropics/claude-code/tree/main/plugins/pr-review-toolkit) by Daisy, customized for SafeGamer.

## Agents

### 1. code-reviewer
**Focus**: General code review + SafeGamer security compliance

**Analyzes:**
- CLAUDE.md compliance
- Style violations and bugs
- **RLS policies on new tables**
- **Auth middleware on API routes**
- **Service role key exposure**
- Code quality issues

**When to use:**
- After writing or modifying code
- Before committing changes
- Before creating pull requests

**Triggers:**
```
"Review my recent changes"
"Check if everything looks good"
"Review this code before I commit"
```

### 2. silent-failure-hunter
**Focus**: Error handling and silent failures

**Analyzes:**
- Silent failures in catch blocks
- Supabase `{ data, error }` handling
- Inadequate error handling
- Missing error logging

**When to use:**
- After implementing error handling
- When reviewing try/catch blocks
- When working with Supabase queries

**Triggers:**
```
"Review the error handling"
"Check for silent failures"
"Analyze catch blocks in this PR"
```

### 3. pr-test-analyzer
**Focus**: Test coverage quality and completeness

**Analyzes:**
- Behavioral vs line coverage
- Critical gaps in test coverage
- E2E test requirements
- RLS policy testing

**When to use:**
- After creating a PR
- When adding new functionality

**Triggers:**
```
"Check if the tests are thorough"
"Review test coverage for this PR"
"Are there any critical test gaps?"
```

### 4. type-design-analyzer
**Focus**: Type design quality and invariants

**Analyzes:**
- Type encapsulation (rated 1-10)
- Invariant expression (rated 1-10)
- Supabase generated types alignment
- Domain type quality

**When to use:**
- When introducing new types
- During PR creation with data models

**Triggers:**
```
"Review the FriendVerification type design"
"Analyze type design in this PR"
"Check if this type has strong invariants"
```

### 5. comment-analyzer
**Focus**: Code comment accuracy and maintainability

**Analyzes:**
- Comment accuracy vs actual code
- Documentation completeness
- Comment rot and technical debt

**When to use:**
- After adding documentation
- Before finalizing PRs with comment changes

**Triggers:**
```
"Check if the comments are accurate"
"Review the documentation I added"
```

### 6. code-simplifier
**Focus**: Code simplification and refactoring

**Analyzes:**
- Code clarity and readability
- Unnecessary complexity
- JetShip/SafeGamer pattern compliance

**When to use:**
- After passing code review
- When code works but feels complex

**Triggers:**
```
"Simplify this code"
"Make this clearer"
"Refine this implementation"
```

## Usage

### Comprehensive PR Review

```
/pr-review-toolkit:review-pr
```

### Specific Aspects

```
/pr-review-toolkit:review-pr tests errors
/pr-review-toolkit:review-pr security
/pr-review-toolkit:review-pr simplify
```

### Individual Agent via Natural Language

```
"Can you check if the tests cover all edge cases?"
→ Triggers pr-test-analyzer

"Review the error handling in the API routes"
→ Triggers silent-failure-hunter
```

## SafeGamer Security Checks

The code-reviewer agent includes SafeGamer-specific security checks:

1. **RLS Policies**: ALL new tables must have Row Level Security enabled
2. **Auth Middleware**: All API routes must verify authentication
3. **Service Role Key**: Never exposed in client code
4. **Input Validation**: All user input validated at boundaries
5. **Supabase Patterns**: Proper `{ data, error }` handling

## Recommended Workflow

1. Write code → **code-reviewer**
2. Fix issues → **silent-failure-hunter** (if error handling)
3. Add tests → **pr-test-analyzer**
4. Document → **comment-analyzer**
5. Review passes → **code-simplifier** (polish)
6. Create PR

## Installation

This plugin is located at `.claude/plugins/pr-review-toolkit/` in the SafeGamer repository.

## Hooks (Optional)

The plugin includes two optional hooks that remind you to run the PR review before creating PRs:

### 1. Claude Code Hook (Automatic Reminder)

The Claude Code hook shows a reminder when you run `gh pr create` without having run the review first.

**Location:** `hooks/hooks.json` and `hooks/pre-pr-check.sh`

This hook is automatically active when using the plugin.

### 2. Git Pre-Push Hook

Shows a reminder when pushing feature branches.

**Install:**
```bash
cp .claude/hooks/pre-push-review-reminder .git/hooks/pre-push
chmod +x .git/hooks/pre-push
```

### Review Marker

When you run `/pr-review-toolkit:review-pr`, it creates a `.pr-review-completed` marker file. The hooks check for this marker and skip the reminder if the review was completed.

**Note:** Add `.pr-review-completed` to `.gitignore` to avoid committing it.

## License

MIT (based on Anthropic plugin)

## Credits

- Original plugin: Daisy (daisy@anthropic.com)
- SafeGamer customization: SafeGamer Team
