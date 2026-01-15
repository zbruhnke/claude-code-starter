---
description: Explore and understand this codebase quickly. Use when starting work on a new project or unfamiliar area.
---

# Project Onboarding

Your task is to help the user understand this codebase: $ARGUMENTS

## Quick Start

1. **Read CLAUDE.md** to understand project overview, conventions, and key commands
2. **Identify the tech stack** from package.json, requirements.txt, go.mod, Cargo.toml, etc.
3. **Map the directory structure** - summarize what each major directory contains
4. **Find entry points** - main files, app bootstrapping, API routes
5. **Locate key configuration** - environment, build, deployment

## Output Format

```
## Project: [name]

**Stack**: [languages, frameworks, key dependencies]

**Structure**:
- src/         → [purpose]
- tests/       → [purpose]
- [other dirs]

**Entry Points**:
- [file]: [what it does]

**Key Files**:
- [file]: [what it does]

**Commands**:
- [command]: [what it does]

**Getting Started**:
1. [step 1]
2. [step 2]
```

## Guidelines

- Keep the overview concise (aim for 1-2 pages)
- Focus on "where to start" not "everything to know"
- Highlight anything unusual or project-specific
- Note any missing documentation or setup issues

If no specific area is specified, provide a general project overview.
