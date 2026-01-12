# Skills - Custom Commands

Skills are reusable instruction sets that Claude applies when your request semantically matches the skill's description. They're invoked automatically based on what you ask for, not via explicit slash commands.

## Directory Structure

```
.claude/skills/
├── code-review/
│   └── SKILL.md
├── explain-code/
│   └── SKILL.md
└── generate-tests/
    └── SKILL.md
```

## Skill File Format

Skills use YAML frontmatter followed by instructions:

```markdown
---
name: code-review
description: Review code changes for quality, security, and best practices
tools: Read, Grep, Glob, Bash
model: opus
---

You are an expert code reviewer. When activated:

1. First, understand what changed (git diff or file read)
2. Check for:
   - Security issues (injection, auth bypass, data exposure)
   - Performance problems (N+1 queries, memory leaks)
   - Code style violations
   - Missing error handling
   - Missing tests

3. Format your review as:
   ## Summary
   [One paragraph overview]

   ## Issues
   - [Critical/Warning/Info] Description

   ## Suggestions
   - Improvement ideas
```

## Available Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Identifier for the skill |
| `description` | Yes | When to use this skill (used for semantic matching) |
| `tools` | Yes | Comma-separated list of allowed tools |
| `model` | Yes | `sonnet` (fast), `opus` (thorough), `haiku` (quick tasks) |

## Using Skills

Skills are invoked via semantic matching - describe what you want, and Claude applies the relevant skill:

```
"Review my staged changes"              # Triggers code-review skill
"Explain how src/utils.py works"        # Triggers explain-code skill
"Generate tests for UserService"        # Triggers generate-tests skill
"Review this merge request"             # Triggers review-mr skill
```

## Included Skills

| Skill | Description | Model |
|-------|-------------|-------|
| `code-review` | Review code for quality, security, and best practices | opus |
| `explain-code` | Explain how code works in detail | opus |
| `generate-tests` | Generate comprehensive tests for code | opus |
| `refactor-code` | Improve code without changing behavior | opus |
| `review-mr` | Review merge/pull requests | opus |
| `install-precommit` | Install the pre-commit review hook | haiku |
| `wiggum` | Autonomous implementation loop from spec/PRD | opus |
| `refresh-claude` | Update CLAUDE.md with recent changes | opus |

## Creating Your Own Skill

1. Create directory: `.claude/skills/my-skill/`
2. Create `SKILL.md` with YAML frontmatter
3. Define `name`, `description`, `tools`, and `model`
4. Write instructions below the frontmatter

### Example: Custom Skill

```markdown
---
name: security-audit
description: Audit code for security vulnerabilities
tools: Read, Grep, Glob
model: opus
---

You are a security auditor. When activated:

1. Search for common vulnerability patterns
2. Check for:
   - SQL injection
   - XSS vulnerabilities
   - Authentication bypasses
   - Insecure deserialization
   - Hardcoded secrets

3. Report findings with severity levels and remediation steps.
```

## Tips

- Keep skill descriptions clear and specific for better semantic matching
- Use `opus` for complex analysis, `haiku` for simple tasks
- Limit tools to only what the skill needs
- Include output format instructions for consistent results
