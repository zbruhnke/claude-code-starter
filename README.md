# Claude Code Starter

[![CI](https://github.com/zbruhnke/claude-code-starter/actions/workflows/ci.yml/badge.svg)](https://github.com/zbruhnke/claude-code-starter/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-ready starter template for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Get a fully configured setup in minutes instead of hours.

## Prerequisites

**Required:**
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Bash 3.2+ (macOS default works)
- Git
- [jq](https://jqlang.github.io/jq/) - JSON parsing in hooks (`brew install jq` / `apt install jq`)

**Optional (for formatting hooks):**
- Your language's formatter: prettier, black/ruff, gofmt, rustfmt, rubocop, mix format

**Check your setup:**
```bash
claude --version     # Should show Claude Code version
bash --version       # Should be 3.2+ (macOS default works)
jq --version         # Required for hooks
```

### Compatibility

| Component | Requirement | Notes |
|-----------|-------------|-------|
| **OS** | Linux, macOS | Tested on Ubuntu 22.04+, macOS 13+ |
| **Bash** | 3.2+ | macOS default (3.2) works fine |
| **jq** | Any version | Required for hooks |
| **Claude Code** | Any version | Tested with 1.x |

**Stack-specific formatters (optional):**

| Stack | Formatter | Install |
|-------|-----------|---------|
| TypeScript | prettier | `npm i -g prettier` |
| Python | black, ruff | `pip install black ruff` |
| Go | gofmt | Included with Go |
| Rust | rustfmt | `rustup component add rustfmt` |
| Ruby | rubocop | `gem install rubocop` |
| Elixir | mix format | Included with Elixir |

## Why This Exists

Most developers install Claude Code and use maybe 10% of its capabilities. This repo gives you:

- **Stack-specific presets** - TypeScript, Python, Go, Rust, Ruby, Elixir configurations
- **Security by default** - Blocked sensitive files, dangerous command prevention
- **Custom skills** - Reusable commands like review, test, explain
- **Specialized agents** - Subagents for research, code review, test writing
- **Pre-commit review** - Forces you to understand what you're committing
- **Auto-formatting** - Runs your formatter after every edit
- **Version detection** - Reads from `.tool-versions` automatically

---

## Installation

### Homebrew (recommended)

```bash
brew tap zbruhnke/claude-code-starter
brew install claude-code-starter
```

**Update:**
```bash
brew upgrade claude-code-starter
```

### Shell script

```bash
curl -fsSL https://raw.githubusercontent.com/zbruhnke/claude-code-starter/main/install.sh | bash
```

This installs `ccs` (short alias) and `claude-code-starter` (full name) to your PATH.

The installer automatically verifies SHA256 checksums when available (v0.7.0+).

**Update:**
```bash
ccs update
```

**Pin to a specific version:**
```bash
curl -fsSL https://raw.githubusercontent.com/zbruhnke/claude-code-starter/main/install.sh | bash -s -- --version <version>
```

---

## 5 Minute Tour

See it work end-to-end:

```bash
# 1. Install the CLI (if you haven't already)
curl -fsSL https://raw.githubusercontent.com/zbruhnke/claude-code-starter/main/install.sh | bash
source ~/.zshrc  # or restart your terminal

# 2. Create your project and configure it
mkdir my-app && cd my-app
git init
ccs init    # Pick TypeScript, accept defaults

# 3. Create something to work with
mkdir -p src && echo "export const hello = () => 'world';" > src/utils.ts
git add -A

# 4. Start Claude Code
claude
```

Now in Claude Code:
```
> Review my staged changes
# → Claude runs code-review skill, analyzes src/utils.ts

> Add a helper function to validate emails in src/utils.ts
# → After edit, auto-format hook runs prettier automatically

> Stage and commit these changes
# → Pre-commit hook shows diff, Claude explains before committing
```

That's the core loop: **edit → auto-format → review → commit with understanding**.

---

## Quick Start

### New Project

```bash
mkdir my-project && cd my-project
git init
ccs init
```

### Existing Project

```bash
cd your-existing-project
ccs init
```

### Add Components

```bash
ccs adopt              # Interactive mode - choose what to install
ccs adopt all          # Install core: skills, agents, hooks, rules, security
ccs adopt skills       # Just skills
ccs adopt agents       # Just agents
ccs adopt precommit    # Pre-commit review hook
ccs adopt security     # Security config only
ccs adopt stack        # Stack-specific preset
```

> **Note:** `adopt all` installs core components but NOT stack presets or precommit hook (since those are project-specific choices). Use interactive mode or add them explicitly.

### CLI Reference

```bash
ccs help              # Show all commands
ccs init              # Interactive setup
ccs adopt [component] # Add components
ccs update            # Update to latest version
ccs version           # Show version
```

> **Note:** `claude-code-starter` also works as the full command name.

The setup script will:
1. Ask which stack you're using (TypeScript, Python, Go, Rust, Ruby, Elixir)
2. Auto-detect versions from `.tool-versions` if present
3. Ask for your project name and description
4. Ask for your dev/test/build commands
5. Select components to install (rules, skills, agents, hooks)
6. Generate all configuration files

---

## Alternative Installation Methods

<details>
<summary>Manual installation without the CLI</summary>

### Clone and run directly

```bash
git clone https://github.com/zbruhnke/claude-code-starter.git ~/claude-code-starter
cd your-project
~/claude-code-starter/setup.sh
```

### Download a specific release

```bash
curl -fsSL https://github.com/zbruhnke/claude-code-starter/archive/refs/tags/<version>.tar.gz | tar -xz
cd your-project
~/claude-code-starter-0.4.0/setup.sh
```

### Copy files manually

```bash
# Core files
cp CLAUDE.template.md your-project/CLAUDE.md
cp .claudeignore your-project/
cp -r .claude your-project/

# Stack-specific preset
cp stacks/typescript/CLAUDE.md your-project/CLAUDE.md
cp stacks/typescript/settings.json your-project/.claude/
```

> **Note**: Stack templates contain `{{PLACEHOLDER}}` variables. Manual copies require replacing these yourself.

</details>

---

## Documentation

| Topic | Description |
|-------|-------------|
| [Skills](docs/skills.md) | Creating and using custom skills |
| [Agents](docs/agents.md) | Specialized subagents for focused tasks |
| [Hooks](docs/hooks.md) | Automation via PreToolUse/PostToolUse |
| [Permissions](docs/permissions.md) | Allow/deny rules and patterns |
| [PR Reviews](docs/pr-reviews.md) | Automated CI/CD code reviews |

---

## Stability & Versioning

**Current status:** Pre-release. The file structure and core concepts are stable, but details may change.

**What's stable:**
- File structure (`.claude/`, `CLAUDE.md`, `.claudeignore`)
- Skill and agent YAML frontmatter format
- Hook input/output contract (JSON on stdin, exit codes)
- Permission pattern syntax

**What may change:**
- Setup script prompts and flow
- Default permissions in presets
- Included skills/agents/rules content

**For reproducible installs**, pin to a specific version:
```bash
curl -fsSL https://raw.githubusercontent.com/zbruhnke/claude-code-starter/main/install.sh | bash -s -- --version <version>
```

**Upgrade to latest:**
```bash
claude-code-starter update
```

This downloads the latest release while preserving your project's `CLAUDE.md` and `.claude/settings.local.json`.

See [Releases](https://github.com/zbruhnke/claude-code-starter/releases) for all versions.

---

## Detailed Usage Guide

### Understanding the File Structure

```
your-project/
├── CLAUDE.md                    # Project context (Claude reads this first)
├── CLAUDE.local.md              # Personal context (gitignored)
├── .claudeignore                # Files to exclude from Claude's context
├── .claude/
│   ├── settings.json            # Permissions, hooks, environment
│   ├── settings.local.json      # Personal overrides (gitignored)
│   ├── rules/                   # Reference documentation (NOT auto-loaded)
│   │   ├── code-style.md
│   │   ├── git.md
│   │   ├── quality-gates.md
│   │   ├── security.md
│   │   ├── security-model.md
│   │   └── testing.md
│   ├── skills/                  # Custom skill definitions
│   │   ├── code-review/SKILL.md
│   │   ├── explain-code/SKILL.md
│   │   ├── generate-tests/SKILL.md
│   │   ├── install-precommit/SKILL.md
│   │   ├── refactor-code/SKILL.md
│   │   ├── refresh-claude/SKILL.md
│   │   ├── review-mr/SKILL.md
│   │   ├── wiggum/SKILL.md
│   │   ├── changelog-writer/SKILL.md
│   │   ├── release-checklist/SKILL.md
│   │   └── risk-register/SKILL.md
│   ├── agents/                  # Specialized subagents
│   │   ├── researcher.md
│   │   ├── code-reviewer.md
│   │   ├── code-simplifier.md
│   │   ├── test-writer.md
│   │   ├── documentation-writer.md
│   │   └── adr-writer.md
│   └── hooks/                   # Automation scripts
│       ├── validate-bash.sh
│       ├── auto-format.sh
│       └── pre-commit-review.sh
```

**In the starter repo only (not copied to your project):**
```
stacks/                          # Stack presets used by setup.sh
├── typescript/
├── python/
├── go/
├── rust/
├── ruby/
└── elixir/
```

---

### CLAUDE.md - Your Project's Brain

This is the most important file. Claude reads it at the start of every session. Changes made during a session require restarting Claude to take effect.

**What to include:**
- Project name and one-line description
- Tech stack with specific versions
- Commands to run (dev, test, build, lint)
- Code conventions specific to YOUR project
- Things Claude should NEVER do

**Example:**
```markdown
# Acme API

REST API for the Acme e-commerce platform.

## Tech Stack
- Python 3.11
- FastAPI 0.104
- PostgreSQL 15 via SQLAlchemy
- Redis for caching

## Commands
make dev          # Start with hot reload
make test         # Run pytest
make lint         # ruff + mypy

## Conventions
- Use Pydantic models for all request/response schemas
- Async everywhere - no sync database calls
- All endpoints need OpenAPI descriptions

## Do Not
- Never use raw SQL - always SQLAlchemy
- Never commit .env files
- Don't add print statements for debugging (use logging)
```

**Tips:**
- Keep it under 500 lines
- Be specific, not generic
- Update it when you learn Claude makes mistakes

---

### Skills

Skills are reusable instruction sets that Claude applies via semantic matching. Describe what you want, and Claude applies the relevant skill automatically.

**Included skills:** `code-review`, `explain-code`, `generate-tests`, `refactor-code`, `review-mr`, `install-precommit`, `wiggum`, `refresh-claude`, `changelog-writer`, `release-checklist`, `risk-register`

**Example usage:**
```
"Review my staged changes"              # Triggers code-review skill
"Explain how src/utils.py works"        # Triggers explain-code skill
"Generate tests for UserService"        # Triggers generate-tests skill
```

→ **[Full documentation: docs/skills.md](docs/skills.md)**

---

### Agents

Agents are focused AI assistants with limited tool access, useful for delegating specific tasks.

**Included agents:** `researcher` (read-only exploration), `code-reviewer`, `code-simplifier`, `test-writer`, `documentation-writer`, `adr-writer`

**Example usage:**
```
Use the researcher agent to understand how authentication works
Use the test-writer agent to generate tests for UserService
```

→ **[Full documentation: docs/agents.md](docs/agents.md)**

---

### Hooks

Hooks run scripts at specific points in Claude's workflow for validation and automation.

**Included hooks:**
- `validate-bash.sh` - Block dangerous shell commands (PreToolUse)
- `auto-format.sh` - Run formatter after file edits (PostToolUse)
- `pre-commit-review.sh` - Review changes before git commits

→ **[Full documentation: docs/hooks.md](docs/hooks.md)**

---

### Permissions

Control what Claude can and cannot do via allow/deny rules in `.claude/settings.json`.

**Default posture:** Safe operations allowed (git, ls, pwd), dangerous operations denied (rm -rf, sudo, .env access). Unlisted commands prompt for approval.

**Configuration scopes:**
- `.claude/settings.json` - Team defaults (committed)
- `.claude/settings.local.json` - Personal overrides (git-ignored)

→ **[Full documentation: docs/permissions.md](docs/permissions.md)**

---

### Security Model & Limitations

**What this protects against:**
- Accidental exposure of `.env` files and secrets
- Recursive deletions (`rm -rf`)
- Privilege escalation (`sudo`)
- Remote code execution (`curl | bash`)
- Overly permissive file modes (`chmod 777`)

**What this does NOT protect against:**
- Determined adversarial use (variables, encoding, indirect access)
- Secrets exposed through logs, test output, or your own code
- Network exfiltration if your app makes API calls
- Reading sensitive files via allowed commands

**This is a safety net, not a security boundary.** A sophisticated user can bypass these protections. See `.claude/rules/security-model.md` for full details including bypass techniques and hardening recommendations.

---

### Permission Philosophy

Permissions follow a deliberate escalation model:

| Layer | Scope | Example |
|-------|-------|---------|
| **Base** | Safe, non-destructive | `git status`, `ls`, `pwd` |
| **Stack presets** | Build/test/lint for your language | `npm test`, `pytest`, `cargo build` |
| **Local overrides** | Opt-in risky operations | `rm`, `mv`, file system writes |

**Design principles:**
- Claude prompts for unlisted commands (you approve once per session)
- Destructive operations (`rm -rf`, `sudo`) are explicitly denied
- Stack presets add only what's needed for that ecosystem
- Personal preferences go in `.claude/settings.local.json` (git-ignored)

This means a fresh install is safe by default. You expand permissions intentionally, not accidentally.

---

### Pre-Commit Review (Important!)

This starter includes a pre-commit review system that forces you to understand what you're committing.

**Why this matters:**
When using AI coding assistants, it's easy to fall into "vibe coding" - accepting changes without really understanding them. The pre-commit review hook shows you:

1. What files changed
2. Summary of the changes
3. Potential issues or concerns
4. Requires you to confirm before committing

**How it works:**
```bash
$ git commit -m "Add user authentication"

┌─────────────────────────────────────────────────────────────┐
│  PRE-COMMIT REVIEW                                          │
├─────────────────────────────────────────────────────────────┤
│  Files changed: 5                                           │
│  Lines added: 247  |  Lines removed: 12                     │
├─────────────────────────────────────────────────────────────┤
│  SUMMARY:                                                   │
│  Adding JWT-based authentication with login/logout          │
│  endpoints and middleware for protected routes.             │
│                                                             │
│  NEED TO KNOW:                                              │
│  • New dependency: jsonwebtoken                             │
│  • Environment variable required: JWT_SECRET                │
│  • Breaking: /api/users now requires auth header            │
│                                                             │
│  POTENTIAL ISSUES:                                          │
│  • Token expiry set to 7 days (consider shorter)            │
│  • No refresh token implementation                          │
│  • Missing rate limiting on login endpoint                  │
└─────────────────────────────────────────────────────────────┘

Do you understand these changes and want to commit?
(y)es to commit, (n)o to abort, (d)iff to see full diff, (q)uit
```

**Enable the hook:**
```bash
# The setup.sh script does this automatically, but manually:
cp .claude/hooks/pre-commit-review.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Non-interactive mode (Claude Code, CI, GUI clients):**
The hook passes silently in non-TTY environments. When using Claude Code, Claude is instructed (via CLAUDE.md) to explain changes and ask for confirmation in the conversation before committing.

```bash
# Skip review entirely (emergency use)
SKIP_PRE_COMMIT_REVIEW=1 git commit -m "Emergency fix"
```

---

### Stack Presets

The setup script includes presets for common stacks:

| Stack | Includes |
|-------|----------|
| **TypeScript** | npm/yarn commands, prettier, eslint, tsc |
| **Python** | pytest, ruff, black, mypy, uvicorn |
| **Go** | go test, golangci-lint, gofmt |
| **Rust** | cargo test, clippy, rustfmt |
| **Ruby** | rspec, rubocop, rails commands |
| **Elixir** | mix test, credo, format, Commanded/CQRS patterns |

Each preset includes:
- Appropriate `settings.json` permissions
- Stack-specific CLAUDE.md template
- Relevant rules and patterns
- Auto-format hook for that language

---

### Version Detection

If your project has a `.tool-versions` file (asdf/mise), the setup script automatically detects versions:

```
# .tool-versions
nodejs 20.10.0
python 3.11.4
elixir 1.15.7
```

These are used to populate your CLAUDE.md template. If no `.tool-versions` exists, it falls back to detecting from runtime commands (`node --version`, `python3 --version`, etc.).

---

### Automatic PR/MR Reviews (CI/CD)

Get AI-powered code reviews automatically on every pull request.

**Quick start:**
```bash
# Command line
./review-mr.sh                    # Review current branch
./review-mr.sh --pr 123           # Review GitHub PR

# GitHub Actions
cp .github/workflows/pr-review.yml your-repo/.github/workflows/
# Add ANTHROPIC_API_KEY to repo secrets

# GitLab CI
# Add to .gitlab-ci.yml: include: - local: 'ci/gitlab-mr-review.yml'
# Set ANTHROPIC_API_KEY and GITLAB_TOKEN in CI/CD variables
```

**Data handling:** PR automation sends the diff, file paths, and commit messages to Anthropic's API. Don't enable on repos with secrets in code or where your security policy prohibits external API calls with code content.

→ **[Full documentation: docs/pr-reviews.md](docs/pr-reviews.md)** (includes detailed privacy guidance)

---

## Files Reference

| File | Committed | Purpose |
|------|-----------|---------|
| `CLAUDE.md` | Yes | Project context for team |
| `CLAUDE.local.md` | No | Personal context |
| `.claude/settings.json` | Yes | Team permissions/hooks |
| `.claude/settings.local.json` | No | Personal overrides |
| `.claude/rules/*.md` | Yes | Reference documentation |
| `.claude/skills/*/SKILL.md` | Yes | Custom commands |
| `.claude/agents/*.md` | Yes | Specialized subagents |
| `.claudeignore` | Yes | File exclusions |

---

## Troubleshooting

### "Permission denied" on hooks
```bash
chmod +x .claude/hooks/*.sh
```

### Skills not showing up
- Ensure directory structure is `.claude/skills/<name>/SKILL.md`
- Check YAML frontmatter has `name`, `description`, `tools`, `model`

### Hooks not running
- Verify JSON structure in `settings.json` (nested `hooks` array)
- Check hook script is executable
- Test hook manually: `echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | .claude/hooks/validate-bash.sh`

### Rules not being followed
Rules in `.claude/rules/` are reference documentation, not automatically loaded instructions. Include critical rules directly in `CLAUDE.md`.

---

## Uninstall

### Uninstall the CLI

```bash
# Remove the installation
rm -rf ~/.claude-code-starter

# Remove PATH entry from your shell config (~/.zshrc, ~/.bashrc, etc.)
# Delete the lines containing "claude-code-starter"
```

### Remove from a project

> **Note:** These commands are for you (human). Claude Code is blocked from running `rm -rf`.

```bash
# Core files
rm -rf .claude/
rm -f CLAUDE.md CLAUDE.local.md .claudeignore

# Git hook (if installed)
rm -f .git/hooks/pre-commit

# CI workflows (if copied)
rm -f .github/workflows/pr-review.yml
rm -f ci/gitlab-mr-review.yml
```

**Secrets:** Remove `ANTHROPIC_API_KEY` from your CI/CD secrets if you added it for PR reviews.

---

## Contributing

PRs welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Quick quality check:**
```bash
shellcheck --severity=warning setup.sh adopt.sh install.sh review-mr.sh bin/claude-code-starter lib/common.sh .claude/hooks/*.sh
for f in .claude/settings.json stacks/*/settings.json; do jq . "$f" > /dev/null; done
```

---

## Security

See [SECURITY.md](SECURITY.md) for our security policy and how to report vulnerabilities.

---

## Support

Need help? See [SUPPORT.md](SUPPORT.md) for troubleshooting and how to get assistance.

---

## License

MIT - See [LICENSE](LICENSE)

---

## Community

- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Changelog](CHANGELOG.md)
