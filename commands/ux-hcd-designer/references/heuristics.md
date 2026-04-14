# Nielsen's 10 Usability Heuristics

## 1. Visibility of System Status
The design should always keep users informed about what is going on, through appropriate feedback within a reasonable amount of time.

**Good:** Progress bars, loading spinners, "Saved" confirmations, step indicators
**Failure:** Silent form submission, no loading state, unclear processing status

**Design questions:** Does the user know what's happening? Is feedback immediate? Are transitions smooth?

## 2. Match Between System and Real World
The design should speak the users' language. Use words, phrases, and concepts familiar to the user, rather than internal jargon.

**Good:** "Shopping cart" (not "order aggregation"), natural date formats, familiar icons
**Failure:** Technical error codes, internal terminology, unfamiliar metaphors

**Design questions:** Would a non-technical user understand this? Does the language match the domain?

## 3. User Control and Freedom
Users often perform actions by mistake. They need a clearly marked "emergency exit" to leave the unwanted action without having to go through an extended process.

**Good:** Undo, cancel, back button, close (X), "are you sure?" for destructive actions
**Failure:** No way to cancel, irreversible actions without warning, trapped in a flow

**Design questions:** Can the user undo this? Can they exit at any point? Is the exit obvious?

## 4. Consistency and Standards
Users should not have to wonder whether different words, situations, or actions mean the same thing. Follow platform and industry conventions.

**Good:** Consistent button styles, predictable navigation, standard icons
**Failure:** Different styles for same action, inconsistent terminology, novel patterns for common tasks

**Design questions:** Does this follow platform conventions? Is terminology consistent throughout?

## 5. Error Prevention
Good error messages are important, but the best designs carefully prevent problems from occurring in the first place.

**Good:** Inline validation, disabled submit until valid, confirmation dialogs, constraints
**Failure:** Allowing invalid input, no confirmation on destructive actions, ambiguous options

**Design questions:** Can we prevent the error entirely? Are constraints communicated upfront?

## 6. Recognition Rather Than Recall
Minimize the user's memory load by making elements, actions, and options visible. The user should not have to remember information from one part of the interface to another.

**Good:** Visible navigation, autocomplete, recent items, contextual help
**Failure:** Hidden menus, memorizing codes, no search, no breadcrumbs

**Design questions:** Can the user see what they need? Do they need to remember anything?

## 7. Flexibility and Efficiency of Use
Shortcuts — hidden from novice users — can speed up the interaction for the expert user so that the design can cater to both inexperienced and experienced users.

**Good:** Keyboard shortcuts, customizable dashboards, batch actions, saved preferences
**Failure:** No shortcuts, one-size-fits-all, forced linear processes

**Design questions:** Can experts go faster? Can novices still complete the task?

## 8. Aesthetic and Minimalist Design
Interfaces should not contain information that is irrelevant or rarely needed. Every extra unit of information competes with the relevant information and diminishes its relative visibility.

**Good:** Clean layouts, progressive disclosure, focused content, clear hierarchy
**Failure:** Cluttered screens, too many options at once, decorative-only elements

**Design questions:** Does every element serve a purpose? Can anything be removed?

## 9. Help Users Recognize, Diagnose, and Recover from Errors
Error messages should be expressed in plain language (no error codes), precisely indicate the problem, and constructively suggest a solution.

**Good:** "Email is already registered. Try signing in instead." with a link
**Failure:** "Error 500", "Invalid input", technical stack traces

**Design questions:** Does the error explain what went wrong? Does it suggest a fix?

## 10. Help and Documentation
Even though it is better if the system can be used without documentation, it may be necessary to provide help and documentation. Such information should be easy to search, focused on the user's task, and list concrete steps.

**Good:** Contextual tooltips, searchable help, task-oriented docs, onboarding tours
**Failure:** No help, outdated docs, help hidden in settings, PDF-only manuals

**Design questions:** Can the user find help in context? Is the help task-oriented?

---

## Severity Rating Scale

| Rating | Description |
|--------|-------------|
| 0 | Not a usability problem |
| 1 | Cosmetic problem — fix only if extra time |
| 2 | Minor problem — low priority |
| 3 | Major problem — important to fix, high priority |
| 4 | Usability catastrophe — must fix before release |
