#!/bin/bash
#
# Wrapper for skill-eval.js that gracefully handles missing Node.js
#
# If Node is not available, exits silently (no skill suggestions).
# This allows the starter to work for Go/Rust/Elixir/etc stacks
# without requiring Node as a prerequisite.
#

# Check if node is available
if ! command -v node >/dev/null 2>&1; then
  # No node - exit silently, don't break the workflow
  exit 0
fi

# Node is available - run the actual skill evaluation
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec node "$SCRIPT_DIR/skill-eval.js"
