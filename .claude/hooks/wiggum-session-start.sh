#!/usr/bin/env bash
#
# Wiggum Session Start Hook
# Automatically creates .wiggum-session marker when wiggum skill is invoked
#
# This hook runs BEFORE the Skill tool executes, making enforcement mechanical.
# Claude cannot skip this - Claude Code runs it automatically.
#
# Input: JSON with skill invocation parameters
# Output: Creates .wiggum-session if skill is "wiggum"
#

set -euo pipefail

# Read the tool input from stdin
INPUT=$(cat)

# Extract skill name from JSON input
# The Skill tool receives: {"skill": "skill-name", "args": "optional args"}
SKILL_NAME=$(echo "$INPUT" | jq -r '.skill // empty' 2>/dev/null || true)

# Only act on wiggum skill invocation
if [ "$SKILL_NAME" = "wiggum" ]; then
  # Create session marker - THIS ENABLES GIT PRE-COMMIT ENFORCEMENT
  {
    echo "session_start: $(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')"
    echo "starting_commit: $(git rev-parse HEAD 2>/dev/null || echo 'not-a-git-repo')"
    echo "enforcement: enabled"
  } > .wiggum-session

  # Notify user
  echo "Wiggum session started - git pre-commit enforcement is now active" >&2

  PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

  # Initialize status file for TUI dashboard
  STATUS_SCRIPT="$PROJECT_DIR/.claude/scripts/wiggum-status.sh"
  if [ -x "$STATUS_SCRIPT" ]; then
    (cd "$PROJECT_DIR" && "$STATUS_SCRIPT" init) 2>/dev/null || true
  fi

  # Auto-launch TUI dashboard in new terminal window (unless disabled)
  if [ -z "${WIGGUM_NO_TUI:-}" ]; then
    TUI_PATH="$PROJECT_DIR/tui/wiggum-tui"

    if [ -x "$TUI_PATH" ]; then
      # User can set preferred terminal: export WIGGUM_TERMINAL=ghostty
      # Options: ghostty, iterm, warp, kitty, alacritty, terminal
      PREFERRED_TERM="${WIGGUM_TERMINAL:-}"
      LAUNCHED=false

      # Helper function to launch in a terminal
      launch_terminal() {
        local term="$1"
        case "$term" in
          ghostty)
            if command -v ghostty &>/dev/null || [ -d "/Applications/Ghostty.app" ]; then
              open -a Ghostty --args -e "cd '$PROJECT_DIR' && '$TUI_PATH'" >/dev/null 2>&1 &
              echo "TUI dashboard launched in Ghostty" >&2
              return 0
            fi
            ;;
          iterm)
            if [ -d "/Applications/iTerm.app" ]; then
              osascript -e "
                tell application \"iTerm\"
                  create window with default profile
                  tell current session of current window
                    write text \"cd '$PROJECT_DIR' && '$TUI_PATH'\"
                  end tell
                end tell
              " >/dev/null 2>&1 &
              echo "TUI dashboard launched in iTerm2" >&2
              return 0
            fi
            ;;
          warp)
            if [ -d "/Applications/Warp.app" ]; then
              open -a Warp >/dev/null 2>&1
              sleep 0.5
              osascript -e "tell application \"System Events\" to keystroke \"cd '$PROJECT_DIR' && '$TUI_PATH'\" & return" >/dev/null 2>&1 &
              echo "TUI dashboard launched in Warp" >&2
              return 0
            fi
            ;;
          kitty)
            if command -v kitty &>/dev/null; then
              kitty --single-instance --directory "$PROJECT_DIR" "$TUI_PATH" >/dev/null 2>&1 &
              echo "TUI dashboard launched in Kitty" >&2
              return 0
            fi
            ;;
          alacritty)
            if command -v alacritty &>/dev/null; then
              alacritty --working-directory "$PROJECT_DIR" -e "$TUI_PATH" >/dev/null 2>&1 &
              echo "TUI dashboard launched in Alacritty" >&2
              return 0
            fi
            ;;
          terminal)
            osascript -e "
              tell application \"Terminal\"
                do script \"cd '$PROJECT_DIR' && '$TUI_PATH'\"
                activate
              end tell
            " >/dev/null 2>&1 &
            echo "TUI dashboard launched in Terminal.app" >&2
            return 0
            ;;
          gnome-terminal)
            if command -v gnome-terminal &>/dev/null; then
              gnome-terminal -- bash -c "cd '$PROJECT_DIR' && '$TUI_PATH'; exec bash" &
              echo "TUI dashboard launched in gnome-terminal" >&2
              return 0
            fi
            ;;
          xterm)
            if command -v xterm &>/dev/null; then
              xterm -e "cd '$PROJECT_DIR' && '$TUI_PATH'" &
              echo "TUI dashboard launched in xterm" >&2
              return 0
            fi
            ;;
        esac
        return 1
      }

      # If user specified a terminal, use it
      if [ -n "$PREFERRED_TERM" ]; then
        if launch_terminal "$PREFERRED_TERM"; then
          LAUNCHED=true
        else
          echo "Warning: $PREFERRED_TERM not found, trying auto-detect" >&2
        fi
      fi

      # Auto-detect: try terminals in order of preference
      if [ "$LAUNCHED" = false ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
          # macOS terminal preference order
          for term in ghostty iterm kitty alacritty warp terminal; do
            if launch_terminal "$term"; then
              LAUNCHED=true
              break
            fi
          done
        else
          # Linux terminal preference order
          for term in kitty alacritty gnome-terminal xterm; do
            if launch_terminal "$term"; then
              LAUNCHED=true
              break
            fi
          done
        fi
      fi
    fi
  fi
fi

# Always allow the skill to proceed
exit 0
