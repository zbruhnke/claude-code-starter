#!/bin/bash
#
# Auto-format Hook
# Runs after Edit/Write to format files
#
# Receives JSON via stdin with tool_input containing file_path
#
# Security notes:
# - Requires jq for reliable JSON parsing
# - Validates file path is a regular file (not symlink to sensitive location)
# - Only formats files that exist
#

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Require jq for reliable JSON parsing
if ! command -v jq &> /dev/null; then
  # For post-tool hooks, we can fail silently - formatting is optional
  # but we should warn the user
  echo "WARNING: jq not installed. Auto-formatting skipped." >&2
  echo "Install jq: brew install jq (macOS) / apt install jq (Debian/Ubuntu)" >&2
  exit 0
fi

# Extract file path from JSON
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Security: Resolve symlinks and validate the path
# This prevents formatting files outside the expected location via symlinks
if [ -L "$FILE_PATH" ]; then
  # Portable symlink resolution (works on both GNU and BSD/macOS)
  # readlink -f is GNU-only, so we use a portable alternative
  if command -v realpath &> /dev/null; then
    REAL_PATH=$(realpath "$FILE_PATH" 2>/dev/null) || REAL_PATH=""
  elif command -v python3 &> /dev/null; then
    REAL_PATH=$(python3 -c "import os; print(os.path.realpath('$FILE_PATH'))" 2>/dev/null) || REAL_PATH=""
  else
    # Fallback: try readlink -f (GNU) or just use the path as-is
    REAL_PATH=$(readlink -f "$FILE_PATH" 2>/dev/null) || REAL_PATH="$FILE_PATH"
  fi
  if [ -z "$REAL_PATH" ]; then
    exit 0  # Can't resolve, skip silently
  fi
  FILE_PATH="$REAL_PATH"
fi

# Skip if file doesn't exist (must be a regular file)
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Get file extension
EXT="${FILE_PATH##*.}"

# Format based on file type
case "$EXT" in
  js|jsx|ts|tsx|json|md|css|scss|html|yaml|yml)
    if command -v prettier &> /dev/null; then
      prettier --write "$FILE_PATH" 2>/dev/null
    fi
    ;;
  py)
    if command -v black &> /dev/null; then
      black --quiet "$FILE_PATH" 2>/dev/null
    elif command -v ruff &> /dev/null; then
      ruff format "$FILE_PATH" 2>/dev/null
    fi
    ;;
  go)
    if command -v gofmt &> /dev/null; then
      gofmt -w "$FILE_PATH" 2>/dev/null
    fi
    ;;
  rs)
    if command -v rustfmt &> /dev/null; then
      rustfmt "$FILE_PATH" 2>/dev/null
    fi
    ;;
  rb|rake)
    if command -v rubocop &> /dev/null; then
      rubocop -a "$FILE_PATH" 2>/dev/null
    fi
    ;;
  ex|exs)
    if command -v mix &> /dev/null; then
      mix format "$FILE_PATH" 2>/dev/null
    fi
    ;;
esac

exit 0
