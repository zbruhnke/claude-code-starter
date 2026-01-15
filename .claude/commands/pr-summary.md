---
description: Generate a pull request description from current changes. Use before creating a PR.
---

# PR Summary Generator

Generate a comprehensive pull request description for the current branch.

## Process

1. **Get branch context**:
   - Current branch: !`git branch --show-current`
   - Commits since main: !`git log main..HEAD --oneline`

2. **Analyze changes**:
   - Run `git diff main...HEAD --stat` to see changed files
   - Run `git diff main...HEAD` for full diff (summarize, don't include raw)

3. **Generate PR description**:

```markdown
## Summary
[2-3 sentence overview of what this PR does]

## Changes
- [Key change 1]
- [Key change 2]
- [Key change 3]

## Testing
- [ ] [How to test change 1]
- [ ] [How to test change 2]

## Notes
[Any additional context, breaking changes, or follow-up work]
```

## Guidelines

- Focus on the "why" not just the "what"
- Group related changes together
- Call out any breaking changes prominently
- Keep it concise but complete
