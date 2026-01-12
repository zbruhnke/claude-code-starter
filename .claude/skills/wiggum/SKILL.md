---
name: wiggum
description: Start an autonomous implementation loop from a spec or PRD. Enters plan mode for user approval, iterates until complete with quality gates enforced, commits incrementally, and maintains documentation and changelog.
tools: Read, Grep, Glob, Edit, Write, Bash, Task
user-invocable: true
---

# Wiggum Loop - Autonomous Implementation

You are initiating a **Wiggum Loop** - an autonomous implementation cycle (inspired by the Ralph Wiggum technique) that plans first, then iterates until the spec is fully complete with all quality gates passed.

## Quick Start

**Step 1: Get the Spec**

If the user provided a spec/PRD, proceed to planning. If not:

```
I'll start a Wiggum Loop for autonomous implementation.

Please provide:
1. **Spec/PRD**: What should I build? (paste or describe)
2. **Success criteria**: How will we know it's done?
3. **Constraints**: Any limits on scope or approach?
```

**Step 2: Enter Plan Mode**

Before writing any code, enter plan mode:
1. Use the EnterPlanMode tool
2. Explore the codebase
3. Design the implementation approach
4. Present the plan via ExitPlanMode
5. Wait for user approval

## The Wiggum Loop Process

```
┌────────────────────────────────────────────────────────────────┐
│  /wiggum "<spec>"                                              │
│                                                                │
│  0. PLAN     → Enter plan mode, get user approval              │
│  1. PARSE    → Extract requirements from spec                  │
│  2. CHUNK    → Break into implementable pieces                 │
│  3. BUILD    → Implement iteratively                           │
│  4. DECIDE   → Document ADRs for significant choices           │
│  5. TEST     → test-writer ensures coverage                    │
│  6. REVIEW   → code-reviewer checks quality                    │
│  7. SIMPLIFY → code-simplifier refines clarity                 │
│  8. DOCUMENT → documentation-writer updates docs               │
│  9. COMMIT   → Atomic commit for the chunk                     │
│  10. REPEAT  → Loop until ALL gates pass                       │
│  11. CHANGELOG → Update CHANGELOG.md                           │
│  12. VERIFY  → Final verification pass                         │
│  13. COMPLETE → Only when truly done                           │
└────────────────────────────────────────────────────────────────┘
```

## Phase 0: Plan First

**This is mandatory.** Before writing any code:

1. **Enter plan mode** using the EnterPlanMode tool
2. **Explore the codebase** to understand existing patterns
3. **Design the approach** based on the spec
4. **Present the plan** to the user via ExitPlanMode
5. **Wait for approval** before proceeding

```markdown
## Wiggum Loop - Planning

### Spec Summary
[Key requirements extracted]

### Implementation Approach
[How you'll build it]

### Chunks
1. [Chunk 1] - [what it does]
2. [Chunk 2] - [what it does]

### Potential Decisions (ADRs)
[Choices that may need documenting]

Entering plan mode for user approval...
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
- Potential ADRs needed

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

    3. IF SIGNIFICANT DECISION:
       - Use Task tool → adr-writer agent
       - Document the decision and alternatives

    4. WRITE TESTS
       - Use Task tool → test-writer agent
       - "Write comprehensive tests for [code]"
       - Tests MUST pass before continuing

    5. CODE REVIEW
       - Use Task tool → code-reviewer agent
       - "Review [code] for issues"
       - Fix ALL blockers before continuing

    6. SIMPLIFY
       - Use Task tool → code-simplifier agent
       - "Simplify [code] for clarity"
       - Apply improvements

    7. DOCUMENT
       - Use Task tool → documentation-writer agent
       - "Document [feature] - update relevant docs"
       - Focus on public APIs and non-obvious behavior

    8. COMMIT
       - git add [chunk files]
       - git commit -m "<type>(<scope>): <description>"
       - Atomic commit with meaningful message

    9. VERIFY CHUNK
       - All tests pass?
       - No blockers from review?
       - Code is simplified?
       - Docs are updated?
       → If NO to any: loop back to step 1
       → If YES to all: mark chunk complete
```

## Invoking Specialized Agents

Use the Task tool to invoke agents:

```javascript
// When planning (REQUIRED first step)
EnterPlanMode()

// When stuck researching
Task(researcher, "I'm implementing [X] and need to find [Y]")

// When making significant decisions
Task(adr-writer, "Document decision to use [X] for [problem].
  Context: [why needed]. Alternatives: [options]. Consequences: [tradeoffs]")

// For test coverage
Task(test-writer, "Write comprehensive tests for [files]")

// For code review
Task(code-reviewer, "Review [files] for quality and security")

// For simplification
Task(code-simplifier, "Simplify [files] for clarity")

// For documentation
Task(documentation-writer, "Document [feature] - update inline docs, README if needed")

// For changelog (use skill)
Skill(changelog-writer, "Add entries for: [list of changes]")
```

## Incremental Git Commits

After each chunk passes quality gates:

```bash
# Stage chunk files
git add src/feature.ts src/feature.test.ts

# Commit with descriptive message
git commit -m "feat(feature): add user authentication

- Add login/logout functionality
- Create session management
- Add password reset endpoint

Co-Authored-By: Claude <noreply@anthropic.com>"
```

**Commit types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance

## Phase 4: Update Changelog

Before final verification, update CHANGELOG.md:

```markdown
## [Unreleased]

### Added
- User authentication with login/logout
- Password reset via email
- Session management

### Changed
- Updated API error responses for consistency
```

## Phase 5: Final Verification

Before declaring complete, run ALL quality gates one final time:

```markdown
## Final Verification Checklist

### Plan
- [ ] User approved the implementation plan
- [ ] No significant deviations (or re-approved)

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

### Documentation (documentation-writer agent)
- [ ] Public APIs documented
- [ ] README updated if needed
- [ ] Configuration documented
- [ ] Non-obvious behavior explained

### Changelog
- [ ] All changes documented
- [ ] Correct categories used
- [ ] User-focused descriptions

### Git History
- [ ] All changes committed
- [ ] Commits are atomic
- [ ] Messages are meaningful

### ADRs (if applicable)
- [ ] Significant decisions documented
- [ ] Context and consequences explained

### Final Agent Approval
- [ ] test-writer: "Tests are comprehensive" ✓
- [ ] code-reviewer: "No remaining issues" ✓
- [ ] code-simplifier: "Code is clear" ✓
- [ ] documentation-writer: "Docs are complete" ✓
```

## Anti-Patterns (NEVER DO THESE)

```
❌ NEVER skip plan mode
   Start implementing without approval  ← NOT ALLOWED

❌ NEVER leave TODOs
   // TODO: implement later  ← NOT ALLOWED

❌ NEVER stub functions
   function fetch() { return null; }  ← NOT ALLOWED

❌ NEVER skip quality gates
   "Tests can wait"  ← NOT ALLOWED
   "Docs aren't needed"  ← NOT ALLOWED

❌ NEVER stop early
   "Good enough"  ← NOT ALLOWED

❌ NEVER ignore agent feedback
   "That warning isn't important"  ← FIX IT

❌ NEVER make giant commits
   One commit with everything  ← NOT ALLOWED
   "WIP" commits  ← NOT ALLOWED
```

## Progress Reporting

After each iteration, report:

```markdown
## Wiggum Loop - Iteration N

### Completed
- [x] What was finished

### In Progress
- [ ] Current work

### Commits Made
- `abc123` - feat(auth): add login
- `def456` - test(auth): add login tests

### ADRs Created
- ADR-001: Use JWT for authentication

### Blocked
- Issue and what's needed

### Quality Gate Status
- Tests: PASS/FAIL
- Review: PASS/FAIL (N blockers)
- Simplify: PASS/FAIL
- Docs: PASS/FAIL

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

### Commits
- `abc123` - feat(auth): add login
- `def456` - test(auth): add tests
- `ghi789` - docs(auth): update README

### Test Summary
- X tests written
- All passing
- Coverage: X%

### Documentation Updates
- Updated README with auth section
- Added inline docs for AuthService
- Documented configuration options

### Changelog Entries
### Added
- User authentication system

### ADRs Created
- ADR-001: Use JWT over sessions

### Quality Gates
- test-writer: APPROVED ✓
- code-reviewer: APPROVED ✓
- code-simplifier: APPROVED ✓
- documentation-writer: APPROVED ✓

### Notes
- Decisions made
- Tradeoffs accepted
- Future considerations
```

## Remember

- **Plan first** - Always get user approval before implementing
- **Iterate until truly done** - not "mostly done"
- **Quality gates are mandatory** - not optional
- **Agent feedback must be addressed** - not ignored
- **Document as you go** - not as an afterthought
- **Commit incrementally** - not in one big commit
- **The spec is your contract** - fulfill every requirement
- **When in doubt, verify again** - better safe than incomplete

Start the loop now. Enter plan mode and design the approach for user approval.
