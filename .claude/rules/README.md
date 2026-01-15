# Rules

Reference documentation for code conventions and standards.

**These files are NOT automatically loaded or enforced by Claude Code.** They exist as documentation that you can point Claude to when relevant.

## Usage

Reference a rule in your prompt when you need Claude to follow it:

```
Follow the patterns in .claude/rules/testing.md
```

Or include in CLAUDE.md to always apply:

```markdown
## Standards

Follow the conventions in:
- .claude/rules/code-style.md
- .claude/rules/testing.md
```

## Files

- `code-style.md` - Naming conventions, code organization, comments
- `git.md` - Commit messages, branch naming, PR guidelines
- `quality-gates.md` - Definition of done, test requirements, completeness
- `security.md` - Input validation, secrets handling, dependencies
- `security-model.md` - What this config protects (and what it doesn't)
- `testing.md` - Test structure, naming, mocking patterns
