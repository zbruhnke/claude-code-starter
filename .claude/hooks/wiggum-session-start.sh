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
fi

# Always allow the skill to proceed
exit 0
