#!/bin/bash
#
# Validate Bash Hook
# Runs before Bash commands to catch dangerous patterns
#
# Receives JSON via stdin, exit 0 to allow, exit 2 to block
#
# Security notes:
# - Requires jq for reliable JSON parsing (fails closed without it)
# - Normalizes whitespace to prevent bypass via "rm  -rf  /"
# - Uses word boundary matching where possible
# - Cannot prevent all obfuscation (base64, variables, etc.)
# - This is a safety net, not a security boundary
#

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Validate we got input
if [ -z "$INPUT" ]; then
  exit 0
fi

# Require jq for reliable JSON parsing - fail closed without it
if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is required for validate-bash.sh hook" >&2
  echo "Install jq: brew install jq (macOS) / apt install jq (Debian/Ubuntu)" >&2
  echo "Blocking command execution for safety" >&2
  exit 2
fi

# Extract command from JSON
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || COMMAND=""

# If no command found, allow (might be a different tool input)
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Normalize whitespace: collapse multiple spaces/tabs to single space
NORMALIZED=$(echo "$COMMAND" | tr -s '[:space:]' ' ' | sed 's/^ //;s/ $//')

# Convert to lowercase for case-insensitive matching
LOWER=$(echo "$NORMALIZED" | tr '[:upper:]' '[:lower:]')

# Function to check if command matches pattern
matches() {
  local pattern="$1"
  [[ "$NORMALIZED" == *"$pattern"* ]] || [[ "$LOWER" == *"$pattern"* ]]
}

# Function to check with word boundaries (more precise)
matches_word() {
  local pattern="$1"
  echo "$NORMALIZED" | grep -qE "(^|[^a-zA-Z])${pattern}([^a-zA-Z]|$)"
}

# ═══════════════════════════════════════════════════════════════════════════════
# BLOCKED PATTERNS - Exit 2 to block
# ═══════════════════════════════════════════════════════════════════════════════

# Destructive filesystem commands
if matches "rm -rf /" || matches "rm -rf --no-preserve-root"; then
  echo "BLOCKED: Recursive delete of root filesystem" >&2
  exit 2
fi

if matches "rm -rf ~" || matches 'rm -rf $HOME' || matches 'rm -rf ${HOME}'; then
  echo "BLOCKED: Recursive delete of home directory" >&2
  exit 2
fi

# Check for rm -rf with path traversal
if echo "$NORMALIZED" | grep -qE 'rm[[:space:]]+-[rf]+[[:space:]]+\.\./'; then
  echo "BLOCKED: Recursive delete with path traversal" >&2
  exit 2
fi

# Block disk destruction commands
if matches_word "mkfs" || matches_word "fdisk" || matches_word "parted"; then
  echo "BLOCKED: Disk formatting/partitioning command" >&2
  exit 2
fi

if matches "dd if=" && (matches "of=/dev/" || matches "of= /dev/"); then
  echo "BLOCKED: Direct disk write with dd" >&2
  exit 2
fi

if matches "> /dev/sd" || matches "> /dev/nvme" || matches "> /dev/hd"; then
  echo "BLOCKED: Direct write to block device" >&2
  exit 2
fi

# Fork bomb patterns (actual syntax, not just keywords)
if matches ":(){" || matches ":(){ :|:&"; then
  echo "BLOCKED: Potential fork bomb detected" >&2
  exit 2
fi

# Block curl/wget piped to shell (common malware pattern)
if echo "$NORMALIZED" | grep -qE '(curl|wget)[^|]*\|[^|]*(bash|sh|zsh)'; then
  echo "BLOCKED: Piping remote content to shell" >&2
  exit 2
fi

# Block chmod 777 on sensitive paths
if matches "chmod 777 /" || matches "chmod -R 777 /"; then
  echo "BLOCKED: Dangerous permission change" >&2
  exit 2
fi

# ═══════════════════════════════════════════════════════════════════════════════
# WARNINGS - Log but allow
# ═══════════════════════════════════════════════════════════════════════════════

if matches_word "sudo"; then
  echo "WARNING: Command uses sudo - review carefully" >&2
fi

if matches "--force" || matches " -f "; then
  echo "NOTE: Command uses force flag" >&2
fi

if matches_word "eval"; then
  echo "WARNING: Command uses eval" >&2
fi

# Allow the command
exit 0
