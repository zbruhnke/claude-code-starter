# .claude Directory

Claude Code configuration directory for this project.

## Structure

```
.claude/
├── settings.json              # Team-shared permissions, hooks, env vars
├── settings.local.json        # Personal overrides (gitignored)
├── agents/                    # Specialized subagents
│   ├── code-reviewer.md       # Thorough code reviews (read-only)
│   ├── researcher.md          # Codebase exploration (read-only)
│   └── test-writer.md         # Generate comprehensive tests
├── hooks/                     # Automation scripts
│   ├── auto-format.sh         # Post-edit formatting
│   ├── pre-commit-review.sh   # Review before commits
│   └── validate-bash.sh       # Block dangerous commands
├── rules/                     # Reference documentation (NOT auto-loaded)
│   ├── code-style.md
│   ├── git.md
│   ├── security.md
│   ├── security-model.md
│   └── testing.md
└── skills/                    # Custom slash commands
    ├── code-review/SKILL.md
    ├── explain-code/SKILL.md
    ├── generate-tests/SKILL.md
    ├── install-precommit/SKILL.md
    ├── refactor-code/SKILL.md
    └── review-mr/SKILL.md
```

## settings.json

Project-level settings shared with the team. Controls permissions and hooks.

```json
{
  "permissions": {
    "allow": ["Bash(npm run:*)"],
    "deny": ["Read(.env)", "Bash(rm -rf /)"]
  },
  "hooks": {
    "PreToolUse": [{ "matcher": "Bash", "hooks": [...] }],
    "PostToolUse": [{ "matcher": "Edit|Write", "hooks": [...] }]
  }
}
```

## agents/

Specialized subagents with focused capabilities and tool restrictions.

**Usage**: "Use the code-reviewer agent to review my changes"

## skills/

Custom slash commands. Each skill is a directory containing `SKILL.md` with YAML frontmatter.

**Usage**: `/review-mr` or `/code-review src/`

## hooks/

Shell scripts triggered by Claude Code events. Receive JSON on stdin.

- **PreToolUse**: Runs before tool execution (exit 2 to block)
- **PostToolUse**: Runs after tool succeeds

## rules/

Reference documentation. **NOT automatically loaded** into Claude's context.
Include critical rules directly in CLAUDE.md instead.
