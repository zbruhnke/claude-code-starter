---
name: wiggum-resume
description: Resume an interrupted wiggum session from its last checkpoint
tools: Read, Bash, Glob, Grep
user-invocable: true
---

# Wiggum Resume

Resume an interrupted wiggum session from its last checkpoint.

Use this skill when a previous `/wiggum` session was interrupted (crashed, timed out, or manually stopped) and you want to continue where you left off.

## When to Use

- Session was interrupted mid-implementation
- Claude Code was restarted during a wiggum loop
- You want to continue previous work without starting over

## Process

1. **Get resumption context** by running:
   ```bash
   .claude/scripts/wiggum-session.sh resume
   ```

2. **Review the output** which includes:
   - Original spec
   - Last phase and chunk
   - Current status
   - Recent git commits

3. **Check for stop conditions** - if one is active:
   ```bash
   .claude/scripts/wiggum-enforce.sh status
   ```

4. **Continue the wiggum loop** from the last phase:
   - If `plan` phase: Re-enter plan mode, design approach
   - If `implement` phase: Continue from the last chunk
   - If `review` phase: Complete final verification

5. **Follow the standard wiggum workflow** from SKILL.md

## Important Notes

- The original spec is preserved in `.wiggum-spec.md`
- Session state is in `.wiggum-session`
- Runtime status is in `.wiggum-status.json`
- If the spec changed since the session started, you'll see a warning

## Example

```
User: /wiggum-resume

Claude:
Let me check the session state...

[Runs .claude/scripts/wiggum-session.sh resume]

I see the session was interrupted during the implement phase at chunk 2.
The original spec was to "implement user authentication".
There have been 3 commits made so far.

Let me continue from chunk 2: "Token validation"...
```

## Recovery from Stop Conditions

If a stop condition is active:

1. Review what caused the stop:
   ```bash
   .claude/scripts/wiggum-enforce.sh status
   ```

2. Either fix the underlying issue, or clear with user approval:
   ```bash
   .claude/scripts/wiggum-enforce.sh clear
   ```

3. Continue the loop

## Starting Fresh

If the session is too corrupted to resume:

```bash
.claude/scripts/wiggum-session.sh abort
```

Then start a new session with `/wiggum`.
