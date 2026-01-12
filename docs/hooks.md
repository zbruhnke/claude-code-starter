# Hooks - Automation

Hooks run scripts at specific points in Claude's workflow, enabling validation, formatting, and custom automation.

## Hook Types

| Type | When | Can Block? |
|------|------|------------|
| `PreToolUse` | Before Claude uses a tool | Yes (exit code 2) |
| `PostToolUse` | After Claude uses a tool | No |
| `Stop` | When Claude finishes responding | No |

## Configuration

Hooks are configured in `.claude/settings.json`:

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

### Configuration Fields

| Field | Description |
|-------|-------------|
| `matcher` | Regex pattern matching tool names (e.g., `Bash`, `Edit\|Write`) |
| `type` | Must be `command` |
| `command` | Shell command to run. Use `$CLAUDE_PROJECT_DIR` for project root. |
| `timeout` | Maximum seconds to wait (required) |

## Hook Input

Hooks receive JSON on stdin describing the tool call:

```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "rm -rf node_modules"
  }
}
```

For file operations:
```json
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "/path/to/file.ts",
    "old_string": "...",
    "new_string": "..."
  }
}
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Allow the tool to proceed |
| 2 | Block the tool (PreToolUse only) |
| Other | Error, but tool proceeds |

## Writing a Blocking Hook

```bash
#!/bin/bash
# validate-bash.sh - Block dangerous commands

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Block recursive deletion
if [[ "$COMMAND" == *"rm -rf /"* ]]; then
  echo "BLOCKED: Dangerous command" >&2
  exit 2  # Exit code 2 = block the tool
fi

# Block sudo
if [[ "$COMMAND" == sudo* ]]; then
  echo "BLOCKED: No sudo allowed" >&2
  exit 2
fi

exit 0  # Allow
```

## Writing a Post-Tool Hook

```bash
#!/bin/bash
# auto-format.sh - Format files after edit

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

# Determine formatter by extension
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx)
    npx prettier --write "$FILE" 2>/dev/null
    ;;
  *.py)
    black "$FILE" 2>/dev/null || ruff format "$FILE" 2>/dev/null
    ;;
  *.go)
    gofmt -w "$FILE" 2>/dev/null
    ;;
esac

exit 0
```

## Included Hooks

| Hook | Type | Purpose |
|------|------|---------|
| `validate-bash.sh` | PreToolUse | Block dangerous shell commands |
| `auto-format.sh` | PostToolUse | Run formatter after file edits |
| `pre-commit-review.sh` | Git hook | Review changes before committing |

---

## Pre-Commit Review Hook

The `pre-commit-review.sh` hook enforces human review before commits. We believe this is an important best practice when using AI coding assistants - it ensures you understand what you're pushing and why.

### Why Human Review Matters

When working with AI assistants like Claude Code, it's easy to fall into **"vibe coding"** - accepting generated code without fully understanding it. Taking a moment to review helps because:

1. **You're responsible for your codebase**, not the AI
2. **AI can make subtle mistakes** that look correct but aren't
3. **Security issues** are easier to catch when you're paying attention
4. **Technical debt** is easier to manage when you understand what's being added
5. **Debugging is easier** when you know how the code works

### What the Hook Does

Before every commit, the hook displays:

```
┌─────────────────────────────────────────────────────────────────┐
│  PRE-COMMIT REVIEW                                              │
├─────────────────────────────────────────────────────────────────┤
│  Files: 5   Lines: +247 / -12                                   │
└─────────────────────────────────────────────────────────────────┘

Files to be committed:
  + src/auth.ts (new)
  ~ src/api.ts (modified)
  - src/old-auth.ts (deleted)

⚠ SENSITIVE FILES DETECTED:
  • config/secrets.json

⚠ DEBUG STATEMENTS FOUND:
  + console.log("debug:", user)

📝 TODOs added:
  + // TODO: implement rate limiting

📦 New dependencies:
  + "jsonwebtoken": "^9.0.0"
```

Then requires you to:
- Press **y** to commit (you understand the changes)
- Press **n** to abort (you need to review more)
- Press **d** to see the full diff
- Press **q** to quit

### The Human Review Contract

When you press **y**, you're affirming:

1. ✓ I have read and understand these changes
2. ✓ I know why each file was modified
3. ✓ I've considered security implications
4. ✓ I can explain this code to someone else
5. ✓ I take responsibility for this code

**If you can't affirm all five, press n and review more carefully.**

### Installation

```bash
# Copy the hook
cp .claude/hooks/pre-commit-review.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Or use the skill
/install-precommit
```

### Bypassing

```bash
# Skip review when needed
SKIP_PRE_COMMIT_REVIEW=1 git commit -m "Quick fix"
```

If you find yourself bypassing frequently, consider whether you're getting full value from the review step.

### Non-Interactive Mode

In CI/CD or when Claude Code is committing, the hook passes silently. This is intentional - Claude is instructed (via CLAUDE.md) to explain changes and ask for confirmation in the conversation before committing.

The hook's value is in **interactive human sessions** where it's easy to rubber-stamp changes.

## Debugging Hooks

Test hooks manually:

```bash
# Test validate-bash.sh
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | .claude/hooks/validate-bash.sh
echo "Exit code: $?"

# Test auto-format.sh
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"}}' | .claude/hooks/auto-format.sh
```

Check that hooks are executable:

```bash
chmod +x .claude/hooks/*.sh
```

## Environment Variables

Hooks have access to:

| Variable | Value |
|----------|-------|
| `CLAUDE_PROJECT_DIR` | Absolute path to project root |
| Standard env | PATH, HOME, etc. |

## Tips

- Keep hooks fast (use timeouts)
- Log to stderr, not stdout
- Use `jq` for JSON parsing (required dependency)
- Test hooks manually before relying on them
- Hooks that error don't block tools (only exit code 2 blocks)
