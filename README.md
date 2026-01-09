# Claude Code Starter

[![CI](https://github.com/zbruhnke/claude-code-starter/actions/workflows/ci.yml/badge.svg)](https://github.com/zbruhnke/claude-code-starter/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-ready starter template for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Get a fully configured setup in minutes instead of hours.

## Prerequisites

**Required:**
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Bash 4.0+ (macOS users: `brew install bash`)
- Git
- [jq](https://jqlang.github.io/jq/) - JSON parsing in hooks (`brew install jq` / `apt install jq`)

**Optional (for formatting hooks):**
- Your language's formatter: prettier, black/ruff, gofmt, rustfmt, rubocop, mix format

**Check your setup:**
```bash
claude --version     # Should show Claude Code version
bash --version       # Should be 4.0+
jq --version         # Required for hooks
```

## Why This Exists

Most developers install Claude Code and use maybe 10% of its capabilities. This repo gives you:

- **Stack-specific presets** - TypeScript, Python, Go, Rust, Ruby, Elixir configurations
- **Security by default** - Blocked sensitive files, dangerous command prevention
- **Custom skills** - Slash commands like `/review`, `/test`, `/explain`
- **Specialized agents** - Subagents for research, code review, test writing
- **Pre-commit review** - Forces you to understand what you're committing
- **Auto-formatting** - Runs your formatter after every edit
- **Version detection** - Reads from `.tool-versions` automatically

## Quick Start

### Option 1: New Project (Start Fresh)

Use this when starting a **brand new project** from scratch:

```bash
# Clone as your new project
git clone https://github.com/zbruhnke/claude-code-starter.git my-project
cd my-project
./setup.sh
```

The setup script will:
1. Ask which stack you're using (TypeScript, Python, Go, Rust, Ruby, Elixir)
2. Auto-detect versions from `.tool-versions` if present
3. Ask for your project name and description
4. Ask for your dev/test/build commands
5. Select components to install (rules, skills, agents, hooks)
6. Generate all configuration files

### Option 2: Existing Project (Add to Your Codebase)

Use this when you have an **existing project** and want to add Claude Code configuration:

Use `adopt.sh` to selectively add components:

```bash
# Clone the starter repo somewhere
git clone https://github.com/zbruhnke/claude-code-starter.git ~/claude-code-starter

# From your project, run adopt interactively
cd your-existing-project
~/claude-code-starter/adopt.sh

# Or adopt specific components directly
~/claude-code-starter/adopt.sh skills      # Just skills
~/claude-code-starter/adopt.sh agents      # Just agents
~/claude-code-starter/adopt.sh precommit   # Just pre-commit hook
~/claude-code-starter/adopt.sh security    # Security config
~/claude-code-starter/adopt.sh stack       # Stack-specific preset
~/claude-code-starter/adopt.sh skill review-mr  # Single skill
```

### Option 3: Full Setup on Existing Project

**Recommended (inspect first):**
```bash
cd your-existing-project
curl -fsSL https://raw.githubusercontent.com/zbruhnke/claude-code-starter/main/setup.sh -o setup.sh
less setup.sh          # Review the script first
chmod +x setup.sh && ./setup.sh
```

> **Note:** The deny-list blocks `curl | bash` to prevent Claude from running piped scripts. That protection is for the AI agent, not for you. You're a human who can (and should) inspect scripts before running them.

### Option 4: Manual Setup

Copy what you need:
```bash
# Core files
cp CLAUDE.template.md your-project/CLAUDE.md
cp .claudeignore your-project/
cp -r .claude your-project/

# Stack-specific preset (contains CLAUDE.md, rules.md, settings.json)
cp stacks/typescript/CLAUDE.md your-project/CLAUDE.md
cp stacks/typescript/settings.json your-project/.claude/
cp stacks/typescript/rules.md your-project/.claude/rules/
```

> **Note**: Stack templates contain `{{PLACEHOLDER}}` variables (e.g., `{{PROJECT_NAME}}`, `{{CMD_TEST}}`). When copying manually, you'll need to replace these yourself. Running `setup.sh` handles substitution automatically.

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
│   │   ├── security.md
│   │   ├── security-model.md
│   │   └── testing.md
│   ├── skills/                  # Custom slash commands
│   │   ├── code-review/SKILL.md
│   │   ├── explain-code/SKILL.md
│   │   ├── generate-tests/SKILL.md
│   │   ├── install-precommit/SKILL.md
│   │   ├── refactor-code/SKILL.md
│   │   └── review-mr/SKILL.md
│   ├── agents/                  # Specialized subagents
│   │   ├── researcher.md
│   │   ├── code-reviewer.md
│   │   └── test-writer.md
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

### Skills - Custom Commands

Skills are slash commands that give Claude specific instructions.

**Directory structure:**
```
.claude/skills/
├── code-review/
│   └── SKILL.md
├── explain-code/
│   └── SKILL.md
└── generate-tests/
    └── SKILL.md
```

**Skill file format (YAML frontmatter + instructions):**
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

**Using skills:**

Skills are invoked via semantic matching - describe what you want, and Claude applies the relevant skill:
```
"Review my staged changes"              # Triggers code-review skill
"Explain how src/utils.py works"        # Triggers explain-code skill
"Generate tests for UserService"        # Triggers generate-tests skill
"Review this merge request"             # Triggers review-mr skill
```

**Available skills:**

| Skill | Description | Model |
|-------|-------------|-------|
| `code-review` | Review code for quality, security, and best practices | opus |
| `explain-code` | Explain how code works in detail | opus |
| `generate-tests` | Generate comprehensive tests for code | opus |
| `refactor-code` | Improve code without changing behavior | opus |
| `review-mr` | Review merge/pull requests | opus |
| `install-precommit` | Install the pre-commit review hook | haiku |

**Creating your own skill:**
1. Create directory: `.claude/skills/my-skill/`
2. Create `SKILL.md` with YAML frontmatter
3. Define `name`, `description`, `tools`, and `model`
4. Write instructions below the frontmatter

---

### Agents - Specialized Subagents

Agents are focused AI assistants with limited tool access.

**Agent file format:**
```markdown
---
name: researcher
description: Explore and understand codebases without making changes
tools: Read, Grep, Glob, WebSearch, WebFetch
model: sonnet
---

You are a research assistant. Your job is to understand code, not change it.

When asked to research:
1. Start broad - understand the overall structure
2. Find relevant files using Grep and Glob
3. Read and understand the code
4. Explain clearly with file:line references

Never suggest changes. Only explain what exists.
```

**Available agent fields:**
- `name`: Identifier for the agent
- `description`: When to use this agent
- `tools`: Comma-separated list of allowed tools
- `model`: `sonnet` (fast), `opus` (thorough), `haiku` (quick tasks)

**Using agents:**
```
Use the researcher agent to understand how authentication works

Use the code-reviewer agent to review my changes to the payment module

Use the test-writer agent to generate tests for the UserService class
```

**Included agents:**
| Agent | Purpose | Tools | Model |
|-------|---------|-------|-------|
| `researcher` | Read-only exploration | Read, Grep, Glob, WebSearch, WebFetch | sonnet |
| `code-reviewer` | Thorough code review | Read, Grep, Glob (read-only) | opus |
| `test-writer` | Generate comprehensive tests | Read, Grep, Glob, Edit, Write, Bash | opus |

---

### Hooks - Automation

Hooks run scripts at specific points in Claude's workflow.

**Hook types:**
- `PreToolUse` - Before Claude uses a tool (can block)
- `PostToolUse` - After Claude uses a tool
- `Stop` - When Claude finishes responding

**Configuration in `.claude/settings.json`:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-bash.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/auto-format.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

**Hook scripts receive JSON on stdin:**
```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "rm -rf node_modules"
  }
}
```

**Blocking a tool (exit code 2):**
```bash
#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ "$COMMAND" == *"rm -rf /"* ]]; then
  echo "BLOCKED: Dangerous command" >&2
  exit 2  # Exit code 2 = block the tool
fi

exit 0  # Exit code 0 = allow
```

**Included hooks:**
| Hook | Purpose |
|------|---------|
| `validate-bash.sh` | Block dangerous shell commands |
| `auto-format.sh` | Run formatter after file edits |
| `pre-commit-review.sh` | Review changes before committing |

---

### Permissions - Security

Control what Claude can and cannot do.

**In `.claude/settings.json` (base configuration):**
```json
{
  "permissions": {
    "allow": [
      "Bash(git status)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git branch:*)",
      "Bash(git checkout:*)",
      "Bash(git stash:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(ls:*)",
      "Bash(pwd)",
      "Bash(which:*)",
      "Bash(echo:*)",
      "Bash(mkdir:*)"
    ],
    "deny": [
      "Read(.env)",
      "Read(.env.*)",
      "Edit(.env)",
      "Edit(.env.*)",
      "Write(.env)",
      "Write(.env.*)",
      "Bash(rm -rf:*)",
      "Bash(rm -r:*)",
      "Bash(sudo:*)",
      "Bash(chmod 777:*)",
      "Bash(curl:*|bash)",
      "Bash(curl:*|sh)",
      "Bash(wget:*|bash)",
      "Bash(wget:*|sh)"
    ]
  }
}
```

**Note:** Destructive operations like `rm`, `mv`, `cp` are intentionally **not** in the default allow list. Claude will prompt for permission when needed. Add them to `.claude/settings.local.json` if you trust Claude with file operations.

Stack-specific presets (in `stacks/*/settings.json`) add language-specific permissions like `npm`, `pytest`, `cargo`, etc., plus additional protections like `Read(**/secrets/**)`.

**Pattern syntax:**
- `*` matches anything within a segment
- `:*` after a command matches any arguments
- `**` matches across directory boundaries

**Configuration scopes:**
- `.claude/settings.json` - Team defaults, committed to repo
- `.claude/settings.local.json` - Personal overrides, git-ignored

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

#### Standalone Script

Review any branch from the command line:

```bash
# Review current branch vs main
./review-mr.sh

# Review specific branch
./review-mr.sh feature-auth

# Review against different base
./review-mr.sh feature-auth develop

# Review GitHub PR by number
./review-mr.sh --pr 123

# Output as markdown (for posting)
./review-mr.sh --format markdown > review.md
```

#### GitHub Actions

Add automatic PR reviews to your GitHub repo:

```bash
# Copy the workflow
mkdir -p .github/workflows
cp .github/workflows/pr-review.yml your-repo/.github/workflows/

# Add your Anthropic API key to repo secrets
# Settings > Secrets > Actions > New repository secret
# Name: ANTHROPIC_API_KEY
```

Every PR will automatically get a Claude review as a comment:
- Runs on PR open, new commits, and reopen
- Updates existing comment instead of spamming
- Can be manually triggered for any PR

#### GitLab CI

Add automatic MR reviews to your GitLab repo:

```yaml
# In your .gitlab-ci.yml
include:
  - local: 'ci/gitlab-mr-review.yml'

# Or copy the job directly from ci/gitlab-mr-review.yml
```

Required CI/CD variables:
- `ANTHROPIC_API_KEY` - Your Anthropic API key
- `GITLAB_TOKEN` - GitLab token with `api` scope for posting comments

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

## Contributing

Found something that makes Claude Code work better? PRs welcome.

- Add useful skills or agents
- Improve stack presets
- Share hook patterns
- Fix documentation

---

## Security

See [SECURITY.md](SECURITY.md) for our security policy and how to report vulnerabilities.

---

## License

MIT
