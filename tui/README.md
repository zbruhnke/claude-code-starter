# Wiggum TUI Dashboard

A real-time terminal dashboard for monitoring Wiggum loop sessions with a soft pastel aesthetic.

## Features

- **Session Info**: Phase, iteration count, elapsed time
- **Current Task**: Active task with status and attempts
- **Chunks**: Visual progress through implementation chunks
- **Command Gates**: Status of TEST, LINT, TYPECHECK, BUILD, FORMAT
- **Agents**: Status of researcher, test-writer, code-reviewer, code-simplifier
- **Commits**: Recent commits made during the session
- **Auto-Launch**: Automatically opens when wiggum skill is invoked

## Building

```bash
cd tui
go build -o wiggum-tui .
```

## Running

The TUI **automatically launches** in a new terminal window when you invoke `/wiggum`. No manual setup required.

To run manually:
```bash
./tui/wiggum-tui
```

### Disabling Auto-Launch

If you prefer to not have the TUI auto-launch:
```bash
export WIGGUM_NO_TUI=1
```

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
───────────────────────────────────────────────────────────────────────────────
 ✦ WIGGUM DASHBOARD ✦                                          ⏱ 14:32:07
───────────────────────────────────────────────────────────────────────────────

◈ Session                               ◈ Gates
╭─────────────────────────────╮         ╭─────────────────────────────────╮
│ Phase     ● Implementing    │         │ ✓ TEST      npm test            │
│ Iteration [████████░░░] 3/5 │         │ ✓ LINT      npm run lint        │
│ Elapsed   15m30s            │         │ ◐ TYPECHECK tsc --noEmit        │
│ Base      abc1234           │         │ ○ BUILD     npm run build       │
│                             │         │ − FORMAT    ---                 │
│ Chunks: 1/3  Commits: 2     │         ╰─────────────────────────────────╯
╰─────────────────────────────╯
                                        ◈ Agents
◈ Active Task                           ╭─────────────────────────────────╮
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓         │ ✓ researcher                    │
┃ ◉ Implement token valid...  ┃         │ ◐ test-writer          !1W      │
┃ Create JWT validation       ┃         │ ○ code-reviewer                 │
┃                             ┃         │ ○ code-simplifier               │
┃ Status: Running  Attempt: 2/3         ╰─────────────────────────────────╯
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
                                        ◈ Commits
◈ Chunks                                ╭─────────────────────────────────╮
╭─────────────────────────────╮         │ a1b2c3d feat(auth): add login   │
│ ● [01] Login endpoint       │         │ b2c3d4e test(auth): add tests   │
│ ◐ [02] Token validation     │         ╰─────────────────────────────────╯
│ ○ [03] Logout functionality │
╰─────────────────────────────╯

───────────────────────────────────────────────────────────────────────────────
 [Q] Quit  [R] Refresh                                    ● Monitoring
```

## Color Palette

The dashboard uses a soft pastel color scheme:

| Element | Color | Hex |
|---------|-------|-----|
| Success/Primary | Mint | #98D8C8 |
| Info/Secondary | Sky Blue | #7EC8E3 |
| In Progress | Peach | #FFCBA4 |
| Error/Failed | Coral Pink | #FFB3BA |
| Active/Accent | Lavender | #C9B1FF |
| Highlight | Lemon | #FDFD96 |
| Muted/Dim | Gray | #9E9E9E |

## Platform Support

**Auto-launch works on:**
- macOS (uses AppleScript to open Terminal.app)
- Linux (supports gnome-terminal, xterm)

**Manual run works on:**
- Any platform with a terminal that supports 256 colors or true color
