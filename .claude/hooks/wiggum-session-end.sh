#!/usr/bin/env bash
#
# Wiggum Session End Hook
# Automatically removes .wiggum-session marker when validation passes
#
# This hook runs AFTER Bash commands execute.
# If the command was wiggum-validate.sh and it succeeded, cleanup the session.
#
# Input: JSON with tool result including command and exit code
# Output: Removes .wiggum-session if validation passed
#

set -euo pipefail

# Read the tool result from stdin
INPUT=$(cat)

# Extract the command that was run and its exit code
# PostToolUse receives: {"tool_name": "Bash", "tool_input": {...}, "tool_result": {...}}
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_result.exit_code // .tool_result.exitCode // "unknown"' 2>/dev/null || true)

# Check if this was the validation script
if [[ "$COMMAND" == *"wiggum-validate.sh"* ]]; then
  # Check if it succeeded (exit code 0)
  if [ "$EXIT_CODE" = "0" ]; then
    # Validation passed - remove session marker to disable enforcement
    if [ -f ".wiggum-session" ]; then
      rm -f ".wiggum-session"
      echo "Wiggum session ended - validation passed, enforcement disabled" >&2
    fi
  fi
fi

# Always exit 0 - PostToolUse hooks shouldn't block
exit 0
