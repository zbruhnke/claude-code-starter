# Support

## Getting Help

### Documentation

- [README](README.md) - Quick start and overview
- [docs/](docs/) - Detailed documentation for skills, agents, hooks, and permissions
- [CLAUDE.md](CLAUDE.md) - How this repo is configured for Claude Code

### Common Issues

**Skills not triggering:**
- Check directory structure: `.claude/skills/<name>/SKILL.md`
- Verify YAML frontmatter has `name` and `description`
- Skills match semantically, not by exact phrase

**Hooks not running:**
- Make scripts executable: `chmod +x .claude/hooks/*.sh`
- Verify JSON syntax in settings.json: `jq . .claude/settings.json`
- Test manually: `echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | .claude/hooks/validate-bash.sh`

**setup.sh fails:**
- Requires Bash 4.0+: `bash --version`
- Requires jq: `jq --version`
- macOS users: `brew install bash jq`

## Reporting Issues

Open a [GitHub Issue](https://github.com/zbruhnke/claude-code-starter/issues) with:

1. What you were trying to do
2. What happened (error messages, unexpected behavior)
3. Your environment (OS, Bash version, Claude Code version)
4. Steps to reproduce

## Response Expectations

This is a community project maintained in spare time.

- **Bug reports**: Usually acknowledged within a few days
- **Feature requests**: May take longer; PRs welcome
- **Security issues**: See [SECURITY.md](SECURITY.md)

## What We Can Help With

- Setup and configuration issues
- Bug reports with reproduction steps
- Documentation clarifications

## What We Can't Help With

- General Claude Code questions (see [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code))
- Issues with your specific project's code
- Debugging custom skills/hooks you've written

## Contributing

Want to help? See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
