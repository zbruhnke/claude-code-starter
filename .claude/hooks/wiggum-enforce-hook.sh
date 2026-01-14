#!/usr/bin/env bash
#
# Wiggum Enforcement Hook
# PreToolUse hook that checks if a stop condition is active
#
# This hook runs BEFORE Bash commands during a wiggum session.
# If a stop condition is active, it blocks the command with exit code 2.
#
# Input: JSON with tool_input (from Claude Code)
# Output: Exit 0 to allow, Exit 2 to block
#

set -euo pipefail

SESSION_FILE=".wiggum-session"
STATUS_FILE=".wiggum-status.json"

# Only enforce if wiggum session is active
if [[ ! -f "$SESSION_FILE" ]]; then
  exit 0
fi

# Check if status file exists
if [[ ! -f "$STATUS_FILE" ]]; then
  exit 0
fi

# Check if stop condition is active
stopped=$(jq -r '.stop_conditions.active // false' "$STATUS_FILE" 2>/dev/null || echo "false")

if [[ "$stopped" == "true" ]]; then
  reason=$(jq -r '.stop_conditions.reason // "unknown"' "$STATUS_FILE" 2>/dev/null)
  details=$(jq -c '.stop_conditions.details // {}' "$STATUS_FILE" 2>/dev/null)

  echo "BLOCKED: Wiggum loop is stopped" >&2
  echo "Reason: $reason" >&2
  echo "Details: $details" >&2
  echo "" >&2
  echo "To continue:" >&2
  echo "  .claude/scripts/wiggum-enforce.sh clear    # Clear stop condition" >&2
  echo "  .claude/scripts/wiggum-enforce.sh status   # View full status" >&2
  exit 2
fi

# Allow command to proceed
exit 0
