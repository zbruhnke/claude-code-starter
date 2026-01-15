# Hooks

This directory contains Claude Code hooks that run automatically during conversations.

## Hook Types

### UserPromptSubmit Hooks
Run when the user submits a prompt, before Claude processes it.

### PreToolUse Hooks
Run before a tool executes. Can block the tool with exit code 2.

### PostToolUse Hooks
Run after a tool executes. Used for formatting, cleanup, etc.

## Installed Hooks

### skill-eval-wrapper.sh / skill-eval.js
**Type:** UserPromptSubmit

Analyzes user prompts and suggests relevant skills based on keyword matching. For example, if you type "review this PR", it might suggest `/code-review`.

**How it works:**
1. Reads the user's prompt
2. Compares against patterns in `skill-rules.json`
3. Scores matches based on keywords (2pts), patterns (3pts), and intents (4pts)
4. Suggests skills that exceed the confidence threshold (5 points)

**Requires:** Node.js (exits silently if not available)

**Configuration:** Edit `skill-rules.json` to customize triggers.

### validate-bash.sh
**Type:** PreToolUse (Bash)

Validates bash commands before execution to catch dangerous patterns:
- Destructive `rm` commands (`rm -rf /`, `rm -rf ~`, etc.)
- Fork bombs
- Disk operations (`mkfs`, `dd of=/dev/...`)
- Piped remote execution (`curl | bash`)

**Note:** This is a safety net, not a security boundary. See `.claude/rules/security-model.md`.

**Requires:** jq (blocks all commands if missing)

### wiggum-session-start.sh / wiggum-session-end.sh
**Type:** PreToolUse (Skill) / PostToolUse (Bash)

Manages wiggum session state. Creates/removes `.wiggum-session` marker file used by the pre-commit hook to enforce quality gates during autonomous implementation loops.

### auto-format.sh
**Type:** PostToolUse (Edit|Write)

Runs auto-formatters (prettier, black, gofmt, etc.) on edited files.

### pre-commit-review.sh
**Type:** Git pre-commit hook (optional, installed to `.git/hooks/pre-commit`)

Forces review of changes before every commit. Prevents "vibe coding" by showing a summary of what's being committed and requiring confirmation.

## Test Files

### test-validate-bash.sh
Test suite for `validate-bash.sh`. Run via:
```bash
bash .claude/hooks/test-validate-bash.sh
```

This is used in CI (`.github/workflows/ci.yml`) to verify the hook works correctly.
