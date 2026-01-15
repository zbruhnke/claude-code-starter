# Permissions

Control what Claude can and cannot do through allow/deny rules in `.claude/settings.json`.

## Configuration

```json
{
  "permissions": {
    "allow": [
      "Bash(git status)",
      "Bash(git diff:*)",
      "Bash(ls:*)",
      "Bash(pwd)"
    ],
    "deny": [
      "Read(.env)",
      "Read(.env.*)",
      "Bash(rm -rf:*)",
      "Bash(sudo:*)"
    ]
  }
}
```

## Pattern Syntax

| Pattern | Matches |
|---------|---------|
| `Bash(git status)` | Exact command `git status` |
| `Bash(git diff:*)` | `git diff` with any arguments |
| `Bash(npm:*)` | Any npm command |
| `Read(.env)` | Read the `.env` file |
| `Read(.env.*)` | Read `.env.local`, `.env.production`, etc. |
| `Read(**/*.pem)` | Read any `.pem` file in any directory |
| `Read(**/secrets/**)` | Read anything under any `secrets/` directory |

### Wildcards

- `*` matches anything within a segment
- `:*` after a command matches any arguments
- `**` matches across directory boundaries

## Default Configuration

The base `settings.json` includes:

**Allowed (safe, non-destructive):**
```json
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
]
```

**Denied (dangerous operations):**
```json
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
```

> **Note:** Patterns like `curl:*|bash` are coarse heuristics for common footguns, not a security boundary. They can be bypassed with variable construction, encoding, or process substitution. Real enforcement happens in `validate-bash.sh`; see `.claude/rules/security-model.md` for what is and isn't protected.

## Permission Philosophy

Permissions follow a deliberate escalation model:

| Layer | Scope | Example |
|-------|-------|---------|
| **Base** | Safe, non-destructive | `git status`, `ls`, `pwd` |
| **Stack presets** | Build/test/lint for your language | `npm test`, `pytest`, `cargo build` |
| **Local overrides** | Opt-in risky operations | `rm`, `mv`, file system writes |

### Design Principles

1. **Prompt for unlisted commands** - Claude asks permission once per session
2. **Explicit denies** - Destructive operations are blocked, not just unlisted
3. **Stack-specific additions** - Presets add only what's needed
4. **Personal overrides** - Use `.claude/settings.local.json` (git-ignored)

## Configuration Scopes

| File | Committed | Purpose |
|------|-----------|---------|
| `.claude/settings.json` | Yes | Team defaults |
| `.claude/settings.local.json` | No | Personal overrides |

Settings are merged, with local taking precedence.

## Stack Presets

Stack-specific presets (in `stacks/*/stack-settings.json`) add language-appropriate permissions. These are merged with `core-settings.json` during setup:

**TypeScript:**
```json
"allow": [
  "Bash(npm:*)",
  "Bash(npx:*)",
  "Bash(yarn:*)",
  "Bash(pnpm:*)"
]
```

**Python:**
```json
"allow": [
  "Bash(python:*)",
  "Bash(python3:*)",
  "Bash(pip:*)",
  "Bash(pytest:*)",
  "Bash(ruff:*)",
  "Bash(black:*)"
]
```

**Go:**
```json
"allow": [
  "Bash(go:*)",
  "Bash(golangci-lint:*)"
]
```

Stack presets also add extra protections like `Read(**/secrets/**)`.

## Common Customizations

### Allow file operations (risky)

In `.claude/settings.local.json`:
```json
{
  "permissions": {
    "allow": [
      "Bash(rm:*)",
      "Bash(mv:*)",
      "Bash(cp:*)"
    ]
  }
}
```

### Block additional sensitive files

```json
{
  "permissions": {
    "deny": [
      "Read(**/*.pem)",
      "Read(**/*.key)",
      "Read(**/credentials/**)"
    ]
  }
}
```

### Allow Docker commands

```json
{
  "permissions": {
    "allow": [
      "Bash(docker:*)",
      "Bash(docker-compose:*)"
    ]
  }
}
```

## Troubleshooting

**Claude keeps asking for permission:**
- Add the command pattern to `allow` list
- Use `:*` for commands with arguments

**Command is blocked unexpectedly:**
- Check if it matches a `deny` pattern
- Deny rules take precedence over allow

**Settings not taking effect:**
- Restart Claude Code after changing settings
- Verify JSON syntax: `jq . .claude/settings.json`
