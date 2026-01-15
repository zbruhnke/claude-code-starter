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

# Read JSON input from stdin with size limit
# Read 8193 bytes - if we get exactly that many, input was truncated
INPUT=$(head -c 8193)
INPUT_LEN=${#INPUT}

# Validate we got input
if [ -z "$INPUT" ]; then
  exit 0
fi

# Fail hard if input was truncated - dangerous content could be hidden at the end
if [ "$INPUT_LEN" -ge 8193 ]; then
  echo '{"block": true, "message": "Command too long (>8KB) - cannot safely validate"}'
  exit 2
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

# Function to check if command contains rm with recursive flags
# Handles: -r, -rf, -fr, -R, --recursive, and combinations like -r -f
# Also catches: command rm, \rm, sudo rm, rm after ; && || | (
has_rm_recursive() {
  local cmd="$LOWER"
  # Match rm command with common prefixes and separators
  # Note: (^|[;&|()]|[[:space:]]) is the correct way to combine literals with POSIX classes
  if ! echo "$cmd" | grep -qE '(^|[;&|()]|[[:space:]])(sudo[[:space:]]+)?(command[[:space:]]+)?\\?rm[[:space:]]'; then
    return 1
  fi
  # Look for recursive flags after rm (handles -r, -rf, -fr, --recursive, split flags)
  # Note: [^;|&)]* stops at ) for subshell consistency
  echo "$cmd" | grep -qE '(^|[;&|()]|[[:space:]])(sudo[[:space:]]+)?(command[[:space:]]+)?\\?rm[^;|&)]*([[:space:]]-[a-z]*r|[[:space:]]--recursive)'
}

# Function to check for dangerous rm targets
has_dangerous_rm_target() {
  local cmd="$LOWER"

  # Root filesystem: standalone "/" followed by terminator or EOL
  echo "$cmd" | grep -qE 'rm[^;|&]*[[:space:]]+/([[:space:];|&)]|$)' && return 0

  # Root wildcard: "/*"
  echo "$cmd" | grep -qE 'rm[^;|&]*[[:space:]]+/\*' && return 0

  # Home directory: "~", "$home", "${home}"
  echo "$cmd" | grep -qE 'rm[^;|&]*[[:space:]]+(~|\$home|\$\{home\})([[:space:];|&)]|$)' && return 0

  # Current directory: "." followed by terminator or EOL
  echo "$cmd" | grep -qE 'rm[^;|&]*[[:space:]]+\.([[:space:];|&)]|$)' && return 0
  # Current directory: "./" prefix
  echo "$cmd" | grep -qE 'rm[^;|&]*[[:space:]]+\./' && return 0

  # Parent directory: ".." followed by terminator or EOL
  echo "$cmd" | grep -qE 'rm[^;|&]*[[:space:]]+\.\.([[:space:];|&)]|$)' && return 0
  # Parent directory: "../" prefix
  echo "$cmd" | grep -qE 'rm[^;|&]*[[:space:]]+\.\./' && return 0

  # Path traversal in an arg: something/../
  echo "$cmd" | grep -qE 'rm[^;|&]*[[:space:]][^[:space:]]*\.\./' && return 0

  # --no-preserve-root flag
  echo "$cmd" | grep -qE 'rm[^;|&]*--no-preserve-root' && return 0

  return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# Helper function for JSON responses (structured output)
# Uses jq for proper escaping to avoid JSON injection
# ═══════════════════════════════════════════════════════════════════════════════

output_block() {
  local message="$1"
  local suggestion="${2:-}"
  if [ -n "$suggestion" ]; then
    jq -cn --arg msg "$message" --arg fb "$suggestion" '{block: true, message: $msg, feedback: $fb}'
  else
    jq -cn --arg msg "$message" '{block: true, message: $msg}'
  fi
  exit 2
}

output_warning() {
  local feedback="$1"
  jq -cn --arg fb "$feedback" '{feedback: $fb}'
}

# ═══════════════════════════════════════════════════════════════════════════════
# BLOCKED PATTERNS - Exit 2 to block
# ═══════════════════════════════════════════════════════════════════════════════

# Destructive rm commands - check for recursive + dangerous target
# Handles: rm -rf, rm -fr, rm -r -f, rm --recursive --force, etc.
if has_rm_recursive && has_dangerous_rm_target; then
  output_block "Recursive delete of protected path blocked" "Use a more specific path like rm -rf ./specific-directory instead of parent or root paths"
fi

# Block disk destruction commands (case-insensitive via matches_word on $LOWER)
if matches_word "mkfs" || matches_word "fdisk" || matches_word "parted"; then
  output_block "Disk formatting/partitioning command blocked" "Disk operations require manual execution outside Claude Code"
fi

# Block dd writes to block devices (don't require if=, just check of=/dev/)
if matches_word "dd" && echo "$LOWER" | grep -qE 'of=[ ]*/dev/'; then
  output_block "Direct disk write with dd blocked" "Writing to block devices requires manual execution"
fi

# Block direct writes to block devices via redirection
if matches "> /dev/sd" || matches "> /dev/nvme" || matches "> /dev/hd" || matches "> /dev/disk"; then
  output_block "Direct write to block device blocked" "Block device operations require manual execution"
fi

# Fork bomb patterns (actual syntax, not just keywords)
if matches ":(){" || matches ":(){ :|:&"; then
  output_block "Potential fork bomb detected" "This pattern could exhaust system resources"
fi

# Block curl/wget piped to shell (common malware pattern)
if echo "$LOWER" | grep -qE '(curl|wget)[^|]*\|[^|]*(bash|sh|zsh)'; then
  output_block "Piping remote content to shell blocked" "Download the script first, review it, then execute: curl -o script.sh URL && cat script.sh && bash script.sh"
fi

# Block chmod 777 on root (catastrophic regardless of -R flag)
if echo "$LOWER" | grep -qE 'chmod[^;|&]*[[:space:]]777[[:space:]]+/([[:space:];|&]|$)'; then
  output_block "Dangerous permission change blocked" "chmod 777 on root would make all files world-writable"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# WARNINGS - Provide feedback but allow
# ═══════════════════════════════════════════════════════════════════════════════

WARNINGS=""

if matches_word "sudo"; then
  WARNINGS="${WARNINGS}Using sudo - review output carefully. "
fi

# Only warn about force flags for destructive commands (rm, mv, cp, git push)
# Avoids noise from tools that use -f harmlessly
if echo "$LOWER" | grep -qE '(^|[;&|])[ ]*(rm|mv|cp)[ ]' && (matches "--force" || echo "$LOWER" | grep -qE ' -[a-z]*f'); then
  WARNINGS="${WARNINGS}Force flag on destructive command. "
fi
if echo "$LOWER" | grep -qE 'git[ ]+push[^;|&]+(-f|--force)'; then
  WARNINGS="${WARNINGS}Force push will overwrite remote history. "
fi

if matches_word "eval"; then
  WARNINGS="${WARNINGS}Using eval - ensure input is trusted. "
fi

# Output warnings as feedback if any
if [ -n "$WARNINGS" ]; then
  # Trim trailing space
  WARNINGS="${WARNINGS% }"
  output_warning "$WARNINGS"
fi

# Allow the command
exit 0
