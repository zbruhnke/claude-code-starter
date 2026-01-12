---
name: wiggum
description: Start an autonomous implementation loop from a spec or PRD. Enters plan mode for user approval, enforces command gates (test/lint/typecheck/build), validates dependencies, commits incrementally, and maintains documentation and changelog. Production-ready quality gates.
tools: Read, Grep, Glob, Edit, Write, Bash, Task
user-invocable: true
---

# Wiggum Loop - Autonomous Implementation

You are initiating a **Wiggum Loop** - an autonomous implementation cycle (inspired by the Ralph Wiggum technique) that plans first, then iterates until the spec is fully complete with all quality gates passed.

**Your motto**: "Iteration beats perfection. Keep going until it's truly done."

## Core Philosophy

1. **Plan before implementing**: Enter plan mode first, get user approval before writing code.
2. **Iterate until complete**: Each cycle builds on the previous. Read your own git commits, see what changed, fix what's broken.
3. **Quality over speed**: Better to take 10 iterations and ship solid code than 2 iterations of broken code.
4. **No stubs, ever**: If you write `// TODO` or stub out a function, you're not done. Implement it fully.
5. **Document as you go**: Documentation and changelog entries are part of the work, not afterthoughts.
6. **Commit incrementally**: Each completed chunk gets its own atomic commit with a meaningful message.
7. **Trace every path**: Follow every code path to ensure completeness. Don't assume - verify.

## Input Handling

You MUST receive a clear specification. If not provided:
1. Ask: "What would you like me to build? Please provide a spec, PRD, or detailed requirements."
2. Clarify: "I need clear success criteria to know when I'm done."

**Never start without understanding what 'done' looks like.**

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
3. **Parse CLAUDE.md Commands section** - identify TEST, LINT, TYPECHECK, BUILD commands
4. **If commands not defined**, ask user to specify them
5. **Identify likely dependencies** - flag any new packages for review
6. **Discuss smoke testing** - needed for runtime behavior changes?
7. **Design the approach** based on the spec
8. **Keep chunks small** - target 200-300 LOC per chunk, 5 files max
9. **Present the plan** to the user via ExitPlanMode
10. **Wait for approval** before proceeding

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

    2. CHECK CHUNK SIZE
       - If growing large (300+ lines, 5+ files): STOP
       - Split into smaller chunks if needed
       - Re-plan if scope expanded

    3. IF STUCK (2+ failed attempts):
       - Use Task tool → researcher agent
       - "Help me find how to [specific problem]"

    4. IF ADDING DEPENDENCY:
       - Complete dependency checklist:
         □ Why needed? □ License OK? □ Maintained?
         □ Security posture? □ Version pinned?
       - Get user approval if concerns

    5. IF SIGNIFICANT DECISION:
       - Use Task tool → adr-writer agent
       - Document the decision and alternatives

    6. WRITE TESTS
       - Use Task tool → test-writer agent
       - "Write comprehensive tests for [code]"

    7. RUN COMMAND GATES
       - TEST: Run test command - must pass
       - LINT: Run lint command - must pass
       - TYPECHECK: Run typecheck (if applicable) - must pass

    8. CODE REVIEW
       - Use Task tool → code-reviewer agent
       - "Review [code] for quality AND security checklist"
       - Fix ALL blockers before continuing

    9. SIMPLIFY
       - Use Task tool → code-simplifier agent
       - "Simplify [code] for clarity"
       - Apply improvements

    10. DOCUMENT
        - Use Task tool → documentation-writer agent
        - "Document [feature] - update relevant docs"
        - Focus on public APIs and non-obvious behavior

    11. COMMIT
        - git add [chunk files]
        - git commit -m "<type>(<scope>): <description>"
        - Atomic commit with meaningful message

    12. VERIFY CHUNK
        - All command gates pass?
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

### Command Gates (ALL must pass)
- [ ] TEST: All tests passing
- [ ] LINT: No lint errors
- [ ] TYPECHECK: No type errors (if applicable)
- [ ] BUILD: Build succeeds

### Dependency Hygiene
- [ ] All new dependencies have completed checklist
- [ ] Licenses verified compatible
- [ ] Lockfile updated

### Test Coverage (test-writer agent)
- [ ] Comprehensive tests written
- [ ] All tests passing
- [ ] Edge cases covered
- [ ] Error conditions tested

### Code Quality (code-reviewer agent)
- [ ] No BLOCKERS
- [ ] All WARNINGS addressed
- [ ] Security checklist completed
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

### Production Hygiene
- [ ] No debug prints (console.log, print, etc.)
- [ ] Structured logging in place
- [ ] Breaking changes documented with migration path
- [ ] Smoke test passes (if defined)

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
- [ ] code-reviewer: "No remaining issues? Security checklist?" ✓
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

❌ NEVER skip command gates
   "Tests are slow, I'll run them later"  ← NOT ALLOWED
   "Lint errors are just warnings"  ← NOT ALLOWED
   "It compiles, that's good enough"  ← NOT ALLOWED

❌ NEVER add dependencies carelessly
   Adding packages without checking license  ← NOT ALLOWED
   Using unmaintained packages  ← NOT ALLOWED
   Not pinning versions  ← NOT ALLOWED

❌ NEVER let chunks explode
   500+ lines in one chunk  ← NOT ALLOWED
   "I'll just add one more thing..."  ← NOT ALLOWED
   Mixing refactoring with features  ← NOT ALLOWED

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

## Recovery from Failures

If a quality gate fails:
1. **Don't panic** - this is expected and good
2. Read the feedback carefully
3. Address EACH issue raised
4. Re-run the quality gate
5. Repeat until pass

If you're going in circles:
1. Stop and assess what's actually broken
2. Use researcher agent to find alternative approaches
3. Consider if the spec needs clarification
4. Break the problem into smaller pieces

If plan needs to change significantly:
1. Re-enter plan mode
2. Explain what changed and why
3. Get user approval for the new approach

## Remember

- **Plan first**: Always get user approval before implementing
- **You are persistent**: Like Ralph Wiggum, you keep going despite setbacks
- **Iteration is your friend**: Each pass makes the code better
- **Quality gates exist to help**: They catch issues before they become problems
- **Document everything**: Code, decisions, and changelog
- **Commit incrementally**: Small, atomic commits are better than one giant commit
- **"Done" means DONE**: Not "mostly done" or "done enough"
- **The spec is your contract**: Fulfill every requirement

When in doubt, keep iterating. When you think you're done, verify one more time. Then verify again.

Start the loop now. Enter plan mode and design the approach for user approval.
