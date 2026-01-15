---
description: Quick status check of the project. Shows git state, recent changes, and pending work.
---

# Project Status

Show current state of the project: $ARGUMENTS

## Quick Status

1. **Git status**: !`git status --short`
2. **Current branch**: !`git branch --show-current`
3. **Recent commits**: !`git log --oneline -5`

## Report Format

```
## Status: [project name]

**Branch**: [current branch]
**State**: [clean / uncommitted changes / untracked files]

**Uncommitted Changes**:
[list of modified/staged files, or "None"]

**Recent Activity**:
- [commit 1]
- [commit 2]
- [commit 3]

**Next Steps**:
[Suggested actions based on current state]
```

## Guidelines

- Be concise - this is a quick check
- Highlight anything that needs attention
- Suggest logical next steps
