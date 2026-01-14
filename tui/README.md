# Wiggum TUI Dashboard

A real-time terminal dashboard for monitoring Wiggum loop sessions.

## Features

- **Session Info**: Phase, iteration count, elapsed time
- **Current Task**: Active task with status and attempts
- **Chunks**: Visual progress through implementation chunks
- **Command Gates**: Status of TEST, LINT, TYPECHECK, BUILD, FORMAT
- **Agents**: Status of researcher, test-writer, code-reviewer, code-simplifier
- **Commits**: Recent commits made during the session

## Building

```bash
cd tui
go build -o wiggum-tui .
```

## Running

```bash
# From the project root
./tui/wiggum-tui
```

The TUI watches `.wiggum-status.json` in the current directory and auto-refreshes every second.

## Status File

The TUI reads from `.wiggum-status.json`. Use the helper script to update it:

```bash
# Initialize a new status file
.claude/scripts/wiggum-status.sh init

# Update phase
.claude/scripts/wiggum-status.sh phase implement

# Update iteration
.claude/scripts/wiggum-status.sh iteration 3

# Update current task
.claude/scripts/wiggum-status.sh task "Implement auth" "in_progress" "Working on JWT"

# Add/update chunks
.claude/scripts/wiggum-status.sh chunk 1 "Login endpoint" "completed"
.claude/scripts/wiggum-status.sh chunk 2 "Token validation" "in_progress"

# Update gates
.claude/scripts/wiggum-status.sh gate test passed "47 passed"
.claude/scripts/wiggum-status.sh gate lint running

# Update agents
.claude/scripts/wiggum-status.sh agent test-writer active "Writing tests"

# Record commits
.claude/scripts/wiggum-status.sh commit abc1234 "feat: add login"
```

## Keyboard Shortcuts

- `q` or `Ctrl+C`: Quit
- `r`: Manual refresh

## Preview

```
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
 ◄ WIGGUM COMMAND CENTER ►                                    [14:32:07]
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

■ SESSION DATA                      ■ COMMAND GATES
┌─────────────────────────────┐     ┌─────────────────────────────────┐
│ PHASE.....: ▶ IMPLEMENTING  │     │ [✓] TEST      npm test          │
│ ITERATION.: [████████░░░░] 3/5    │ [✓] LINT      npm run lint      │
│ ELAPSED...: 15m30s          │     │ [~] TYPECHECK tsc --noEmit █    │
│ BASE......: abc1234         │     │ [ ] BUILD     npm run build     │
│                             │     │ [-] FORMAT    ---               │
│ CHUNKS: 1/3  COMMITS: 2     │     └─────────────────────────────────┘
└─────────────────────────────┘
                                    ■ AGENT STATUS
■ ACTIVE TASK                       ┌─────────────────────────────────┐
╔═════════════════════════════╗     │ [X] researcher                  │
║ █ Implement token valid...  ║     │ [▓] test-writer        !1W      │
║ Create JWT validation       ║     │ [ ] code-reviewer               │
║                             ║     │ [ ] code-simplifier             │
║ STATUS: RUNNING  ATTEMPT: 2/3     └─────────────────────────────────┘
╚═════════════════════════════╝
                                    ■ GIT LOG
■ CHUNK PROGRESS                    ┌─────────────────────────────────┐
┌─────────────────────────────┐     │ a1b2c3d feat(auth): add login   │
│ ■ [01] Login endpoint       │     │ b2c3d4e test(auth): add tests   │
│ ▶ [02] Token validation █   │     └─────────────────────────────────┘
│ □ [03] Logout functionality │
└─────────────────────────────┘

▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
 [Q]UIT  [R]EFRESH                              STATUS: MONITORING
```

The retro green phosphor CRT aesthetic includes:
- Blinking cursors (█▓▒░) for active items
- Progress bars with block characters
- Double-line borders for active task
- Scanline separators

## Integration with Wiggum Skill

The wiggum skill should be updated to emit status updates using the helper script throughout its execution. This enables real-time monitoring of autonomous implementation sessions.
