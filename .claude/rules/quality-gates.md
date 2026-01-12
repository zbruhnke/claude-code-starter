# Quality Gates

Standards for code quality that apply to all implementation work.

## Code Completeness

### No TODOs or Stubs

Code must be complete. Never leave:

```
❌ // TODO: implement this
❌ // FIXME: handle edge case
❌ // HACK: temporary solution
❌ function stub() { return null; }
❌ throw new Error('Not implemented');
❌ pass  # Python placeholder
```

If you write a TODO, you must implement it before finishing.

### Every Code Path

- Trace execution from entry to exit
- Handle all branches (if/else, switch cases)
- Handle all error conditions
- No dead code or unreachable branches

## Test Requirements

### Coverage Standards

- All new functions must have tests
- Test happy path AND error cases
- Test edge cases (null, empty, boundaries)
- Tests must pass before code is considered complete

### Test Quality

- Tests should fail when code is broken
- Tests should pass when code is correct
- No skipped or pending tests without documented reason
- No flaky tests

## Code Review Standards

### Blockers (Must Fix)

These must be resolved before code is complete:

- Security vulnerabilities
- Logic errors that cause incorrect behavior
- Data loss or corruption risks
- Breaking changes to public APIs
- Missing error handling for critical paths

### Warnings (Should Fix)

Address these unless explicitly accepted:

- Performance issues in hot paths
- Missing validation on external input
- Inconsistent error handling
- Code that's hard to maintain
- Missing documentation for complex logic

## Code Clarity

### Readability Over Brevity

- Explicit is better than clever
- Three clear lines beat one confusing line
- Names should reveal intent
- Avoid nested ternaries

### Consistency

- Follow patterns in CLAUDE.md
- Match surrounding code style
- Use project conventions, not personal preferences

### Simplicity

- No unnecessary abstraction
- No premature optimization
- Remove dead code
- Consolidate duplicate logic

## Definition of Done

Code is "done" when ALL of these are true:

1. **Functional**: Does what the spec requires
2. **Complete**: No TODOs, stubs, or placeholders
3. **Tested**: Comprehensive tests passing
4. **Reviewed**: No blockers, warnings addressed
5. **Clear**: Simplified, readable, follows conventions
6. **Traced**: Every code path verified

## When Quality Gates Fail

1. **Don't panic** - failures are feedback
2. **Read the feedback** - understand what's wrong
3. **Fix the issue** - don't work around it
4. **Re-verify** - run the gate again
5. **Repeat** - until it passes

Never mark work as complete with failing quality gates.
