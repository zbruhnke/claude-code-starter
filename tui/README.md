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
 🚔 WIGGUM DASHBOARD

SESSION                          COMMAND GATES
┌──────────────────────────┐     ┌────────────────────────────────┐
│ Phase:     IMPLEMENT     │     │ ✓ TEST       npm test          │
│ Iteration: 3/5           │     │ ✓ LINT       npm run lint      │
│ Elapsed:   15m30s        │     │ ● TYPECHECK  tsc --noEmit      │
│ Start:     abc1234       │     │ ○ BUILD      npm run build     │
└──────────────────────────┘     │ - FORMAT     prettier          │
                                 └────────────────────────────────┘
CURRENT TASK
┌──────────────────────────┐     AGENTS
│ Implement token valid... │     ┌────────────────────────────────┐
│ Create JWT validation    │     │ ✓ researcher                   │
│ Status: in progress      │     │ ● test-writer (1 warning)      │
│ Attempt: 2/3             │     │ ○ code-reviewer                │
└──────────────────────────┘     │ ○ code-simplifier              │
                                 └────────────────────────────────┘
CHUNKS
┌──────────────────────────┐     COMMITS
│ ✓ 1. Login endpoint      │     ┌────────────────────────────────┐
│ ● 2. Token validation    │     │ a1b2c3d feat(auth): add login  │
│ ○ 3. Logout functionality│     │ b2c3d4e test(auth): add tests  │
└──────────────────────────┘     └────────────────────────────────┘

Press 'q' to quit, 'r' to refresh
```

## Integration with Wiggum Skill

The wiggum skill should be updated to emit status updates using the helper script throughout its execution. This enables real-time monitoring of autonomous implementation sessions.
