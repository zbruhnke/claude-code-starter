# Contributing to Claude Code Starter

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## Ways to Contribute

- **Report bugs**: Open an issue describing the bug and how to reproduce it
- **Suggest features**: Open an issue describing the feature and its use case
- **Submit fixes**: Fork, fix, and submit a pull request
- **Add stack presets**: New language/framework configurations
- **Improve skills/agents**: Better prompts or new capabilities
- **Improve documentation**: Clarifications, examples, or corrections

## Development Setup

```bash
# Clone the repo
git clone https://github.com/zbruhnke/claude-code-starter.git
cd claude-code-starter

# No build step required - this is a configuration template
# Test changes by running setup.sh in a test directory
mkdir /tmp/test-project && cd /tmp/test-project
/path/to/claude-code-starter/setup.sh
```

## Code Standards

### Shell Scripts

- Use `#!/bin/bash` shebang
- Include `set -e` for error handling
- Use `set -euo pipefail` in hooks
- Quote all variables: `"$VAR"` not `$VAR`
- Use `read -r` to prevent backslash interpretation
- Test on both macOS and Linux when possible

### Skills and Agents

- Use YAML frontmatter with `name`, `description`, `tools`, and `model`
- Reference CLAUDE.md for project context
- Include "What NOT to do" sections
- Provide structured output formats
- Keep prompts focused and actionable

### Documentation

- Use clear, concise language
- Include examples where helpful
- Keep README.md under 1000 lines
- Update relevant docs when changing functionality

## Submitting Changes

### Pull Request Process

1. **Fork** the repository
2. **Create a branch**: `git checkout -b feature/your-feature`
3. **Make changes** and test them
4. **Commit** with clear messages
5. **Push** to your fork
6. **Open a PR** with a clear description

### Commit Messages

Use conventional commit format:

```
type: short description

Longer explanation if needed.

Fixes #123
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, no code change
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding tests
- `chore`: Maintenance tasks

### PR Description Template

```markdown
## What does this PR do?
[Brief description]

## Why is this change needed?
[Motivation]

## How was this tested?
[Testing steps]

## Checklist
- [ ] Shell scripts pass `bash -n` syntax check
- [ ] Documentation updated if needed
- [ ] No secrets or personal data included
```

## Adding a New Stack Preset

1. Create directory: `stacks/<language>/`
2. Add these files:
   - `CLAUDE.md` - Template with `{{PLACEHOLDERS}}`
   - `settings.json` - Stack-specific permissions
   - `rules.md` - Language-specific conventions
3. Update `setup.sh` to detect the stack
4. Update README.md stack list
5. Test with a real project

## Adding a New Skill

1. Create directory: `.claude/skills/<skill-name>/`
2. Create `SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: skill-name
   description: What the skill does
   tools: Read, Grep, Glob
   model: opus
   ---
   ```
3. Write clear instructions with:
   - Project Context section referencing CLAUDE.md
   - Scope section
   - What NOT to do section
   - Process steps
   - Output format
4. Update README.md skills list

## Adding a New Agent

1. Create file: `.claude/agents/<agent-name>.md`
2. Use YAML frontmatter:
   ```yaml
   ---
   name: agent-name
   description: When to use this agent
   tools: Read, Grep, Glob
   model: sonnet
   ---
   ```
3. Follow same structure as skills
4. Update README.md agents list

## Questions?

Open an issue with the `question` label or reach out to the maintainers.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
