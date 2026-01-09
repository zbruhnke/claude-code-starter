#!/bin/bash
#
# Common utilities for Claude Code Starter scripts
#
# Source this file in your scripts:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/lib/common.sh"
#

# ─────────────────────────────────────────────────────────────────────────────
# Colors
# ─────────────────────────────────────────────────────────────────────────────

# Disable colors if not a terminal or if NO_COLOR is set
if [ -t 1 ] && [ -z "$NO_COLOR" ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  BLUE='\033[0;34m'
  YELLOW='\033[1;33m'
  BOLD='\033[1m'
  DIM='\033[2m'
  NC='\033[0m'
else
  RED='' GREEN='' BLUE='' YELLOW='' BOLD='' DIM='' NC=''
fi

# ─────────────────────────────────────────────────────────────────────────────
# Print helpers
# ─────────────────────────────────────────────────────────────────────────────

print_success() { echo -e "  ${GREEN}✓${NC} $1"; }
print_info() { echo -e "  ${BLUE}→${NC} $1"; }
print_warning() { echo -e "  ${YELLOW}!${NC} $1"; }
print_error() { echo -e "  ${RED}✗${NC} $1"; }
print_step() { echo -e "\n${BOLD}$1${NC}\n"; }

# ─────────────────────────────────────────────────────────────────────────────
# String utilities
# ─────────────────────────────────────────────────────────────────────────────

# Escape special characters for sed replacement
# Handles: / & | \ [ ] * . ^ $ and newlines
# Usage: sed "s|pattern|$(sed_escape "$value")|g"
sed_escape() {
  printf '%s' "$1" | sed -e 's/[\/&|\\[\]*.$^]/\\&/g' -e 's/$/\\/' -e '$s/\\$//'
}

# Normalize user input for display/templating purposes
# NOTE: This is NOT a security function. It does basic character replacement
# for cleaner output in templates. For actual security:
# - Use proper quoting when passing to commands: "$value"
# - Use printf '%q' for shell-safe escaping
# - Use jq for JSON handling
# Usage: VALUE=$(normalize_input "$USER_INPUT")
normalize_input() {
  local value="$1"
  value="${value//\"/\'}"  # Replace double quotes with single (for templates)
  value="${value//\`/\'}"  # Replace backticks (for templates)
  printf '%s' "$value"
}

# ─────────────────────────────────────────────────────────────────────────────
# Git utilities
# ─────────────────────────────────────────────────────────────────────────────

# Get the default branch name (main, master, develop, trunk)
# Returns via stdout
get_default_branch() {
  # Try to get from remote HEAD
  local default_branch
  default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')

  if [ -n "$default_branch" ] && git rev-parse --verify "$default_branch" &>/dev/null; then
    echo "$default_branch"
    return 0
  fi

  # Fallback: try common branch names
  for branch in main master develop trunk; do
    if git rev-parse --verify "$branch" &>/dev/null; then
      echo "$branch"
      return 0
    fi
  done

  return 1
}

# Get current branch name (handles older Git versions and detached HEAD)
# Returns via stdout, returns 1 on failure
get_current_branch() {
  local branch

  # Try git branch --show-current (Git 2.22+)
  branch=$(git branch --show-current 2>/dev/null)

  # Fallback for older Git versions
  if [ -z "$branch" ]; then
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  fi

  # Check for detached HEAD
  if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then
    return 1
  fi

  echo "$branch"
}

# Check if a branch exists
branch_exists() {
  git rev-parse --verify "$1" &>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# Prompts (interactive)
# ─────────────────────────────────────────────────────────────────────────────

# Read input from /dev/tty if available, otherwise stdin
# This allows scripts to work in CI where /dev/tty doesn't exist
_read_input() {
  # Check if stdin is a terminal - if so, use /dev/tty for prompts
  # In CI, stdin is a pipe so we read from stdin directly
  if [ -t 0 ]; then
    read "$@" </dev/tty
  else
    read "$@"
  fi
}

# Prompt for text input with optional default
# Usage: VALUE=$(prompt "Enter name" "default")
prompt() {
  local prompt_text="$1"
  local default="$2"
  local value=""

  if [ -n "$default" ]; then
    _read_input -r -p "  $prompt_text [$default]: " value || true
    value="${value:-$default}"
  else
    _read_input -r -p "  $prompt_text: " value || true
  fi

  # Normalize for template use
  normalize_input "$value"
}

# Prompt for yes/no with default
# Usage: if prompt_yn "Continue?" "y"; then ...
prompt_yn() {
  local prompt_text="$1"
  local default="$2"
  local yn=""

  while true; do
    _read_input -r -p "  $prompt_text (y/n) [$default]: " yn || true
    yn="${yn:-$default}"
    case $yn in
      [Yy]* ) return 0;;
      [Nn]* ) return 1;;
      * ) echo "  Please answer y or n.";;
    esac
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# Version detection
# ─────────────────────────────────────────────────────────────────────────────

# Read version from .tool-versions file (asdf/mise format)
# Usage: VERSION=$(read_tool_version "nodejs")
read_tool_version() {
  local tool="$1"
  if [ -f ".tool-versions" ]; then
    grep "^$tool " .tool-versions 2>/dev/null | awk '{print $2}' | head -1
  fi
}

# Detect runtime version with fallback to command
# Usage: VERSION=$(detect_version "node" "--version" "v")
detect_version() {
  local cmd="$1"
  local flag="${2:---version}"
  local strip_prefix="${3:-}"

  if command -v "$cmd" &>/dev/null; then
    local version
    version=$("$cmd" $flag 2>/dev/null | head -1)
    if [ -n "$strip_prefix" ]; then
      version="${version#$strip_prefix}"
    fi
    echo "$version"
  fi
}
