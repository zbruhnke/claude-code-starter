---
name: wiggum
description: Start an autonomous implementation loop from a spec or PRD. Iterates until complete with quality gates enforced by specialized agents.
tools: Read, Grep, Glob, Edit, Write, Bash, Task
model: opus
user_invocable: true
---

# Wiggum Loop - Autonomous Implementation

You are initiating an **Wiggum Loop** - an autonomous implementation cycle (inspired by the Ralph Wiggum technique) that iterates until the spec is fully complete with all quality gates passed.

## Quick Start

If the user provided a spec/PRD, begin immediately. If not:

```
I'll start a Wiggum Loop for autonomous implementation.

Please provide:
1. **Spec/PRD**: What should I build? (paste or describe)
2. **Success criteria**: How will we know it's done?
3. **Constraints**: Any limits on scope, time, or approach?
```

## The Wiggum Loop Process

```
┌────────────────────────────────────────────────────────────┐
│  /wiggum "<spec>"                                      │
│                                                            │
│  1. PARSE    → Extract requirements from spec              │
│  2. PLAN     → Break into implementable chunks             │
│  3. BUILD    → Implement iteratively                       │
│  4. VERIFY   → Quality gates (test, review, simplify)      │
│  5. REPEAT   → Loop until ALL gates pass                   │
│  6. COMPLETE → Only when truly done                        │
└────────────────────────────────────────────────────────────┘
```

## Phase 1: Parse the Spec

Extract and confirm:

```markdown
## Requirements Extracted

### Must Have (Blocking)
- [ ] Requirement 1
- [ ] Requirement 2

### Should Have (Important)
- [ ] Requirement 3

### Nice to Have (Optional)
- [ ] Requirement 4

### Success Criteria
- [ ] Criterion 1
- [ ] Criterion 2

### Out of Scope
- Item explicitly not included
```

**Confirm with user before proceeding.**

## Phase 2: Plan the Implementation

Break down into chunks:

```markdown
## Implementation Plan

### Chunk 1: [Name]
- Files to create/modify
- Dependencies on other chunks
- Estimated complexity: Low/Medium/High

### Chunk 2: [Name]
...
```

## Phase 3: Build (The Loop)

For each chunk, iterate:

```
WHILE chunk not complete:

    1. IMPLEMENT
       - Write the code
       - Follow project conventions (CLAUDE.md)

    2. IF STUCK (2+ failed attempts):
       - Use Task tool → researcher agent
       - "Help me find how to [specific problem]"

    3. WRITE TESTS
       - Use Task tool → test-writer agent
       - "Write comprehensive tests for [code]"
       - Tests MUST pass before continuing

    4. CODE REVIEW
       - Use Task tool → code-reviewer agent
       - "Review [code] for issues"
       - Fix ALL blockers before continuing

    5. SIMPLIFY
       - Use Task tool → code-simplifier agent
       - "Simplify [code] for clarity"
       - Apply improvements

    6. VERIFY CHUNK
       - All tests pass?
       - No blockers from review?
       - Code is simplified?
       → If NO to any: loop back to step 1
       → If YES to all: mark chunk complete
```

## Phase 4: Final Verification

Before declaring complete, run ALL quality gates one final time:

```markdown
## Final Verification Checklist

### Spec Completeness
- [ ] Every Must Have requirement implemented
- [ ] Every Should Have requirement implemented
- [ ] All success criteria met

### Code Completeness
- [ ] NO `// TODO` comments remain
- [ ] NO stub functions
- [ ] NO placeholder implementations
- [ ] Every code path traced and verified

### Test Coverage (test-writer agent)
- [ ] Comprehensive tests written
- [ ] All tests passing
- [ ] Edge cases covered
- [ ] Error conditions tested

### Code Quality (code-reviewer agent)
- [ ] No BLOCKERS
- [ ] All WARNINGS addressed
- [ ] Security review passed
- [ ] Best practices followed

### Code Clarity (code-simplifier agent)
- [ ] Code simplified where possible
- [ ] Follows project conventions
- [ ] Readable and maintainable

### Final Agent Approval
- [ ] test-writer: "Tests are comprehensive" ✓
- [ ] code-reviewer: "No remaining issues" ✓
- [ ] code-simplifier: "Code is clear" ✓
```

## Invoking Specialized Agents

Use the Task tool to invoke agents:

```javascript
// When stuck researching
Task(researcher, "I'm implementing [X] and need to find [Y]")

// For test coverage
Task(test-writer, "Write comprehensive tests for [files]")

// For code review
Task(code-reviewer, "Review [files] for quality and security")

// For simplification
Task(code-simplifier, "Simplify [files] for clarity")
```

## Anti-Patterns (NEVER DO THESE)

```
❌ NEVER leave TODOs
   // TODO: implement later  ← NOT ALLOWED

❌ NEVER stub functions
   function fetch() { return null; }  ← NOT ALLOWED

❌ NEVER skip quality gates
   "Tests can wait"  ← NOT ALLOWED

❌ NEVER stop early
   "Good enough"  ← NOT ALLOWED

❌ NEVER ignore agent feedback
   "That warning isn't important"  ← FIX IT
```

## Progress Reporting

After each iteration, report:

```markdown
## Wiggum Loop - Iteration N

### Completed
- [x] What was finished

### In Progress
- [ ] Current work

### Blocked
- Issue and what's needed

### Quality Gate Status
- Tests: PASS/FAIL
- Review: PASS/FAIL (N blockers)
- Simplify: PASS/FAIL

### Next
- What happens next
```

## Completion Report

When truly done:

```markdown
## Wiggum Loop - COMPLETE ✓

### Spec Fulfillment
| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Req 1 | ✓ | file.ts:10-50 |
| Req 2 | ✓ | file.ts:52-80 |

### Files Created/Modified
- `path/file.ts` - Description
- `path/test.ts` - Tests

### Test Summary
- X tests written
- All passing
- Coverage: X%

### Quality Gates
- test-writer: APPROVED ✓
- code-reviewer: APPROVED ✓
- code-simplifier: APPROVED ✓

### Notes
- Decisions made
- Tradeoffs accepted
- Future considerations
```

## Remember

- **Iterate until truly done** - not "mostly done"
- **Quality gates are mandatory** - not optional
- **Agent feedback must be addressed** - not ignored
- **The spec is your contract** - fulfill every requirement
- **When in doubt, verify again** - better safe than incomplete

Start the loop now. Parse the spec and confirm requirements with the user.
