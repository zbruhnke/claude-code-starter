# Contributing to Claude Code Starter

Thank you for your interest in contributing! This guide will help you get started.

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold this code.

## What We're Looking For

### High-Value Contributions

- **New stack presets** - Language/framework configurations with `CLAUDE.md` template, `settings.json`, and `rules.md`
- **Useful skills** - Reusable instruction sets with clear use cases
- **Useful agents** - Focused subagents for specific tasks
- **Hook improvements** - Cross-platform fixes, new validation patterns
- **Documentation** - Clarifications, typo fixes, examples

### Not Accepting

- Breaking changes to stable interfaces (file structure, hook contract, skill format)
- Features requiring non-standard dependencies
- Platform-specific code without cross-platform fallbacks
- Changes that reduce security defaults

## Development Setup

```bash
# Clone the repo
git clone https://github.com/zbruhnke/claude-code-starter.git
cd claude-code-starter

# Verify your environment
bash --version       # Should be 4.0+
jq --version         # Required for hooks
shellcheck --version # For linting
```

## Quality Requirements

All contributions must pass CI checks. Run these locally before submitting:

### Shell Scripts

```bash
# Lint with shellcheck
shellcheck --severity=warning setup.sh adopt.sh review-mr.sh lib/common.sh
shellcheck --severity=warning .claude/hooks/*.sh

# Syntax check
for f in setup.sh adopt.sh review-mr.sh lib/common.sh .claude/hooks/*.sh; do
  bash -n "$f"
done
```

### JSON Files

```bash
# Validate JSON syntax
for f in .claude/settings.json stacks/*/settings.json; do
  jq . "$f" > /dev/null
done
```

### General Guidelines

- Shell scripts must work on Bash 4.0+ (macOS ships with older Bash)
- Use `$CLAUDE_PROJECT_DIR` instead of relative paths in hooks
- Test on both Linux and macOS if possible
- Keep documentation in sync with code

## Submitting Changes

### Before You Start

1. Check existing [issues](https://github.com/zbruhnke/claude-code-starter/issues) to avoid duplicate work
2. For large changes, open an issue first to discuss the approach
3. Fork the repo and create a feature branch

### Pull Request Process

1. Create a feature branch: `git checkout -b feature/my-feature`
2. Make your changes
3. Run quality checks locally (see above)
4. Commit with clear messages (see below)
5. Push to your fork and open a PR
6. Fill out the PR description explaining what and why

### Commit Messages

Use conventional commit format:

```
type: short description

[optional body]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Examples:
- `feat: add Ruby stack preset`
- `fix: handle spaces in file paths`
- `docs: clarify hook exit codes`

## Adding a New Stack Preset

1. Create directory `stacks/your-stack/`
2. Add required files:
   - `CLAUDE.md` - Template with `{{PLACEHOLDER}}` variables
   - `settings.json` - Language-specific permissions
   - `rules.md` - Code style and conventions
3. Update `setup.sh` to include the new stack option
4. Add to README stack table
5. Test with a real project

### Template Variables

| Variable | Purpose |
|----------|---------|
| `{{PROJECT_NAME}}` | Project name |
| `{{PROJECT_DESCRIPTION}}` | One-line description |
| `{{VERSION_*}}` | Language version (e.g., `{{VERSION_NODE}}`) |
| `{{CMD_DEV}}` | Dev server command |
| `{{CMD_TEST}}` | Test command |
| `{{CMD_BUILD}}` | Build command |
| `{{CMD_LINT}}` | Lint command |

## Adding a New Skill

1. Create directory `.claude/skills/your-skill/`
2. Add `SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: your-skill
   description: Clear description of what this skill does and when to use it.
   tools: Read, Grep, Glob, Bash
   model: opus
   ---

   [Instructions for Claude when this skill is active]
   ```
3. Include sections for: Project Context, Scope, What NOT to do, Process, Output Format
4. Update README skills table

## Adding a New Agent

1. Create `.claude/agents/your-agent.md`
2. Include YAML frontmatter:
   ```yaml
   ---
   name: your-agent
   description: What this agent does and when to use it
   tools: Read, Grep, Glob
   model: sonnet
   ---

   [Agent instructions]
   ```
3. Update README agents table

## Adding a New Hook

1. Create `.claude/hooks/your-hook.sh`
2. Make it executable: `chmod +x .claude/hooks/your-hook.sh`
3. Hooks receive JSON on stdin, exit 2 to block (PreToolUse only)
4. Update `.claude/settings.json` to register the hook
5. Add documentation to `docs/hooks.md`

## Releasing (Maintainers Only)

### Release checklist

```bash
# 1. Update VERSION file
echo "v0.7.0" > VERSION

# 2. Update CHANGELOG.md (move Unreleased to new version)

# 3. Commit version bump
git add VERSION CHANGELOG.md
git commit -m "chore: bump version to v0.7.0"

# 4. Create annotated tag
git tag -a v0.7.0 -m "v0.7.0 - Brief description"

# 5. Push commit and tag
git push origin main v0.7.0

# 6. Generate checksums (after tag is pushed)
./scripts/generate-checksums.sh v0.7.0

# 7. Create GitHub release and upload checksums
gh release create v0.7.0 --generate-notes
gh release upload v0.7.0 checksums.txt

# 8. Update Homebrew tap
./homebrew/update-formula.sh v0.7.0
cp homebrew/Formula/claude-code-starter.rb ~/projects/homebrew-claude-code-starter/Formula/
cd ~/projects/homebrew-claude-code-starter
git commit -am "Update to v0.7.0" && git push
```

### Checksum verification

Starting with v0.7.0, releases include `checksums.txt` for install verification.
The installer automatically verifies downloads when checksums are available.

**Signed tags (recommended for production releases):**
```bash
# Requires GPG key configured with git
git tag -s v1.0.0 -m "v1.0.0 - Production release"
git push origin v1.0.0

# Verify a signed tag
git tag -v v1.0.0
```

Versioning:
- `v0.x.y` during pre-1.0 development
- Semver (`vX.Y.Z`) after 1.0
- Add `-alpha`, `-beta`, `-rc.1` suffix for pre-releases

## Getting Help

- Open an issue for bugs or feature requests
- See [SUPPORT.md](SUPPORT.md) for response expectations
- Check existing documentation before asking

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
