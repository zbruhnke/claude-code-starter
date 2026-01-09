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

# Force C locale for deterministic grep character class behavior
export LC_ALL=C

# Read JSON input from stdin (cap at 8k to avoid pathological cases)
INPUT=$(head -c 8192)

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

# Function to check if command matches pattern (case-insensitive)
matches() {
  local pattern="$1"
  [[ "$LOWER" == *"$pattern"* ]]
}

# Function to check with word boundaries (case-insensitive)
matches_word() {
  local pattern="$1"
  echo "$LOWER" | grep -qE "(^|[^a-zA-Z])${pattern}([^a-zA-Z]|$)"
}

# Function to check if rm command has recursive flags
# Handles: -r, -rf, -fr, -R, --recursive, and combinations like -r -f
has_rm_recursive() {
  # Check if command starts with rm (word boundary)
  if ! echo "$LOWER" | grep -qE '(^|[;&|])[ ]*rm[ ]'; then
    return 1
  fi
  # Check for recursive flag in any form
  echo "$LOWER" | grep -qE 'rm[^;|&]*(-[a-z]*r|-[a-z]*R|--recursive)'
}

# Function to check for dangerous rm targets
has_dangerous_rm_target() {
  local cmd="$LOWER"
  # Root filesystem
  echo "$cmd" | grep -qE 'rm[^;|&]+[ ]/([ ;|&]|$)' && return 0
  # Root with wildcard (rm -rf /*)
  echo "$cmd" | grep -qE 'rm[^;|&]+[ ]/\*' && return 0
  # Home directory
  echo "$cmd" | grep -qE 'rm[^;|&]+[ ](~|\$home|\$\{home\})' && return 0
  # Current directory (repo wipe)
  echo "$cmd" | grep -qE 'rm[^;|&]+[ ]\.(/|[ ;|&]|$)' && return 0
  # Parent directory
  echo "$cmd" | grep -qE 'rm[^;|&]+[ ]\.\.(/|[ ;|&]|$)' && return 0
  # Path traversal
  echo "$cmd" | grep -qE 'rm[^;|&]+[ ][^ ]*\.\./' && return 0
  # --no-preserve-root
  echo "$cmd" | grep -qE 'rm[^;|&]+--no-preserve-root' && return 0
  return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# BLOCKED PATTERNS - Exit 2 to block
# ═══════════════════════════════════════════════════════════════════════════════

# Destructive rm commands - check for recursive + dangerous target
# Handles: rm -rf, rm -fr, rm -r -f, rm --recursive --force, etc.
if has_rm_recursive && has_dangerous_rm_target; then
  echo "BLOCKED: Recursive delete of protected path" >&2
  exit 2
fi

# Block disk destruction commands (case-insensitive via matches_word on $LOWER)
if matches_word "mkfs" || matches_word "fdisk" || matches_word "parted"; then
  echo "BLOCKED: Disk formatting/partitioning command" >&2
  exit 2
fi

# Block dd writes to block devices (don't require if=, just check of=/dev/)
if matches_word "dd" && echo "$LOWER" | grep -qE 'of=[ ]*/dev/'; then
  echo "BLOCKED: Direct disk write with dd" >&2
  exit 2
fi

# Block direct writes to block devices via redirection
if matches "> /dev/sd" || matches "> /dev/nvme" || matches "> /dev/hd" || matches "> /dev/disk"; then
  echo "BLOCKED: Direct write to block device" >&2
  exit 2
fi

# Fork bomb patterns (actual syntax, not just keywords)
if matches ":(){" || matches ":(){ :|:&"; then
  echo "BLOCKED: Potential fork bomb detected" >&2
  exit 2
fi

# Block curl/wget piped to shell (common malware pattern)
if echo "$LOWER" | grep -qE '(curl|wget)[^|]*\|[^|]*(bash|sh|zsh)'; then
  echo "BLOCKED: Piping remote content to shell" >&2
  exit 2
fi

# Block chmod 777 on root or recursive on root
if matches "chmod 777 /" || matches "chmod -r 777 /"; then
  echo "BLOCKED: Dangerous permission change" >&2
  exit 2
fi

# ═══════════════════════════════════════════════════════════════════════════════
# WARNINGS - Log but allow
# ═══════════════════════════════════════════════════════════════════════════════

if matches_word "sudo"; then
  echo "WARNING: Command uses sudo - review carefully" >&2
fi

# Only warn about force flags for destructive commands (rm, mv, cp, git push)
# Avoids noise from tools that use -f harmlessly
if echo "$LOWER" | grep -qE '(^|[;&|])[ ]*(rm|mv|cp)[ ]' && (matches "--force" || echo "$LOWER" | grep -qE ' -[a-z]*f'); then
  echo "NOTE: Destructive command uses force flag" >&2
fi
if echo "$LOWER" | grep -qE 'git[ ]+push[^;|&]+(-f|--force)'; then
  echo "WARNING: git push with force flag" >&2
fi

if matches_word "eval"; then
  echo "WARNING: Command uses eval" >&2
fi

# Allow the command
exit 0
