# Project Overview

<!--
  INSTRUCTIONS: Replace this section with a brief description of your project.
  Keep it to 2-3 sentences. Claude reads this at session start (changes require restart).

  Example:
  E-commerce platform built with Next.js and Stripe. Handles product catalog,
  user authentication, shopping cart, and checkout. Production traffic ~10k DAU.
-->

[Describe what this project does and its key purpose]

## Tech Stack

<!--
  INSTRUCTIONS: List your core technologies. Be specific about versions
  if they matter for compatibility.
-->

- **Framework**: [e.g., Next.js 14, Rails 7, FastAPI]
- **Language**: [e.g., TypeScript 5.x, Python 3.11]
- **Database**: [e.g., PostgreSQL, MongoDB, SQLite]
- **Deployment**: [e.g., Vercel, AWS, Docker]

## Architecture

<!--
  INSTRUCTIONS: Briefly describe how the codebase is organized.
  Focus on the main directories and their purposes.
-->

```
src/
├── app/          # [Purpose]
├── components/   # [Purpose]
├── lib/          # [Purpose]
└── api/          # [Purpose]
```

## Common Commands

<!--
  INSTRUCTIONS: List the commands Claude should use.
  These are critical - Claude will reference these constantly.
-->

```bash
# Development
npm run dev          # Start development server

# Testing
npm test             # Run all tests
npm test -- --watch  # Watch mode

# Building
npm run build        # Production build
npm run lint         # Run linter
npm run typecheck    # Check types
```

## Code Conventions

<!--
  INSTRUCTIONS: Be specific about your style preferences.
  Claude will follow these exactly.
-->

- [e.g., Use named exports, not default exports]
- [e.g., Prefer `async/await` over `.then()` chains]
- [e.g., Components use PascalCase, utilities use camelCase]
- [e.g., All functions must have JSDoc comments]

## Important Patterns

<!--
  INSTRUCTIONS: Document patterns Claude should follow when writing code.
  Include examples if the pattern isn't obvious.
-->

### [Pattern Name]

```typescript
// Example of the pattern
```

## Do Not

<!--
  INSTRUCTIONS: Explicit things Claude should avoid.
  Be specific - if Claude keeps making a mistake, add it here.
-->

- [ ] Never use `any` type - use `unknown` and narrow
- [ ] Don't commit `.env` files
- [ ] Don't modify files in `generated/` - they're auto-generated
- [ ] Never use `console.log` in production code - use the logger

## Current Focus

<!--
  INSTRUCTIONS: Optional but useful. What are you actively working on?
  This helps Claude understand the context of your requests.
  Update this as your focus changes.
-->

- [ ] [Current feature or task]
- [ ] [Another active workstream]

---

<!--
  TIP: Keep this file under 500 lines. If it grows too large, Claude's
  context window gets eaten up before you even start working.

  Move detailed documentation to separate files in /docs and reference
  them here when needed.
-->
