# Claude Code Starter

A starter template for setting up Claude Code in any project.

## This Repository

This is a template repo - clone it and run `./setup.sh` to configure Claude Code for your project.

## Code Style

When working in this repo:
- Write clear, readable code
- Use descriptive names
- Keep functions small and focused
- Follow existing patterns in the codebase

## Security

- Never commit secrets or credentials
- Validate all external input
- Use environment variables for sensitive config
- `.env` and `.env.*` files are blocked from reading (see `.claude/settings.json`)
- See `.claude/rules/security-model.md` for full security documentation

## Commit Review

Before committing changes, always:
1. Show the user what files are being committed
2. Briefly explain the key changes
3. Ask for confirmation before proceeding

This prevents "vibe coding" - blindly committing AI-generated changes without review.

## Available Skills

Skills are invoked automatically when your request matches their description:
- **code-review**: Review code changes for quality and security
- **explain-code**: Explain how code works
- **generate-tests**: Generate comprehensive tests
- **refactor-code**: Improve code without changing behavior
- **review-mr**: Review merge/pull requests
- **install-precommit**: Install the pre-commit review hook

## Available Agents

Use these specialized agents for focused tasks:
- **researcher**: Explore and understand code (read-only)
- **code-reviewer**: Thorough code reviews
- **test-writer**: Generate tests

Example: "Use the researcher agent to understand how the setup script works"

## Project Structure

```
.claude/
├── settings.json              # Permissions, hooks
├── skills/                    # Custom skills (YAML frontmatter + instructions)
│   ├── code-review/SKILL.md
│   ├── explain-code/SKILL.md
│   ├── generate-tests/SKILL.md
│   ├── refactor-code/SKILL.md
│   ├── review-mr/SKILL.md
│   └── install-precommit/SKILL.md
├── agents/                    # Specialized subagents
│   ├── researcher.md
│   ├── code-reviewer.md
│   └── test-writer.md
├── hooks/                     # Automation scripts
│   ├── validate-bash.sh       # Pre-command validation
│   ├── auto-format.sh         # Post-edit formatting
│   └── pre-commit-review.sh   # Git pre-commit hook
└── rules/                     # Documentation (not auto-loaded)
    ├── code-style.md
    ├── git.md
    ├── security.md
    ├── security-model.md
    └── testing.md
stacks/                        # Stack-specific presets (starter repo only)
├── typescript/
├── python/
├── go/
├── rust/
├── ruby/
└── elixir/
```

## Commands

```bash
./setup.sh    # Interactive setup for any project
```

## For Users

After cloning, replace this CLAUDE.md with your project-specific version.
See `CLAUDE.template.md` for a starting point.
