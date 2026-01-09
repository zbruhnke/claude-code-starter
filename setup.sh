#!/bin/bash
#
# Claude Code Starter Setup Script
# Production-ready configuration with stack-specific presets
#
# Dependencies: bash 4.0+, git (optional)
# Exit codes: 0=success, 1=error
#

set -euo pipefail

# Check bash version (need 4.0+ for associative arrays and other features)
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  echo "Error: This script requires Bash 4.0 or later."
  echo "Your version: $BASH_VERSION"
  echo ""
  echo "On macOS, install newer bash with Homebrew:"
  echo "  brew install bash"
  echo "  \$(brew --prefix)/bin/bash $0"
  echo ""
  echo "Or add to your shell config:"
  echo "  export PATH=\"\$(brew --prefix)/bin:\$PATH\""
  exit 1
fi

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$(pwd)"

# Source common utilities
source "$SCRIPT_DIR/lib/common.sh"

# Track what we've created for cleanup on failure
CREATED_FILES=()
SETUP_COMPLETE=false

# Track if .claude/ existed before we started
PREEXISTING_CLAUDE_DIR=false
if [ -d "$TARGET_DIR/.claude" ]; then
  PREEXISTING_CLAUDE_DIR=true
fi

# Cleanup function for error handling
# Note: Uses atomic operations to avoid TOCTOU vulnerabilities
cleanup_on_error() {
  if [ "$SETUP_COMPLETE" = true ]; then
    return
  fi

  echo ""
  echo -e "${RED}Setup failed. Cleaning up...${NC}"

  # Remove created files (rm -f handles non-existent files, no check needed)
  # Only remove if file is within TARGET_DIR to prevent symlink attacks
  for file in "${CREATED_FILES[@]}"; do
    # Resolve to absolute path and verify it's under TARGET_DIR
    local resolved
    resolved=$(cd "$(dirname "$file")" 2>/dev/null && pwd)/$(basename "$file") || continue
    if [[ "$resolved" == "$TARGET_DIR"/* ]]; then
      rm -f "$file" 2>/dev/null && echo -e "  ${DIM}Removed: $file${NC}"
    fi
  done

  # Remove .claude/ directory if we created it (not pre-existing)
  # This ensures partial .claude/ installs get cleaned up properly
  if [ "$PREEXISTING_CLAUDE_DIR" = false ] && [ -d "$TARGET_DIR/.claude" ]; then
    # Verify the path is safe before removing
    local resolved_claude
    resolved_claude=$(cd "$TARGET_DIR/.claude" 2>/dev/null && pwd) || true
    if [[ "$resolved_claude" == "$TARGET_DIR/.claude" ]]; then
      rm -rf "$TARGET_DIR/.claude" 2>/dev/null && echo -e "  ${DIM}Removed: .claude/${NC}"
    fi
  fi

  echo ""
  echo -e "${YELLOW}Partial setup was rolled back. Please fix the issue and try again.${NC}"
}

# Set trap for cleanup on error or interrupt
trap cleanup_on_error ERR
trap 'echo ""; echo -e "${RED}Setup interrupted${NC}"; cleanup_on_error; exit 1' INT TERM

# Helper to track created files for cleanup
track_file() {
  CREATED_FILES+=("$1")
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper functions (setup.sh specific)
# ─────────────────────────────────────────────────────────────────────────────

print_header() {
  # Only clear if we have a terminal
  [ -t 1 ] && clear 2>/dev/null || true
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  Claude Code Starter${NC}"
  echo -e "${BLUE}  Production-ready AI coding configuration${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

select_option() {
  local prompt_text="$1"
  shift
  local options=("$@")

  echo -e "  ${prompt_text}"
  echo ""
  for i in "${!options[@]}"; do
    echo -e "    ${DIM}$((i+1)))${NC} ${options[$i]}"
  done
  echo ""

  while true; do
    read -p "  Enter choice [1-${#options[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
      SELECTED_INDEX=$((choice-1))
      return 0
    fi
    echo "  Invalid choice. Please enter a number between 1 and ${#options[@]}."
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# Version detection
# ─────────────────────────────────────────────────────────────────────────────

detect_versions() {
  # Read from .tool-versions if present
  DETECTED_NODE_VERSION=$(read_tool_version "nodejs" || read_tool_version "node")
  DETECTED_PYTHON_VERSION=$(read_tool_version "python")
  DETECTED_GO_VERSION=$(read_tool_version "golang" || read_tool_version "go")
  DETECTED_RUST_VERSION=$(read_tool_version "rust")
  DETECTED_RUBY_VERSION=$(read_tool_version "ruby")
  DETECTED_ELIXIR_VERSION=$(read_tool_version "elixir")

  # Also try to detect from runtime commands as fallback
  if [ -z "$DETECTED_NODE_VERSION" ] && command -v node &> /dev/null; then
    DETECTED_NODE_VERSION=$(node --version 2>/dev/null | sed 's/^v//')
  fi
  if [ -z "$DETECTED_PYTHON_VERSION" ] && command -v python3 &> /dev/null; then
    DETECTED_PYTHON_VERSION=$(python3 --version 2>/dev/null | awk '{print $2}')
  fi
  if [ -z "$DETECTED_GO_VERSION" ] && command -v go &> /dev/null; then
    DETECTED_GO_VERSION=$(go version 2>/dev/null | awk '{print $3}' | sed 's/^go//')
  fi
  if [ -z "$DETECTED_RUST_VERSION" ] && command -v rustc &> /dev/null; then
    DETECTED_RUST_VERSION=$(rustc --version 2>/dev/null | awk '{print $2}')
  fi
  if [ -z "$DETECTED_RUBY_VERSION" ] && command -v ruby &> /dev/null; then
    DETECTED_RUBY_VERSION=$(ruby --version 2>/dev/null | awk '{print $2}')
  fi
  if [ -z "$DETECTED_ELIXIR_VERSION" ] && command -v elixir &> /dev/null; then
    DETECTED_ELIXIR_VERSION=$(elixir --version 2>/dev/null | grep "Elixir" | awk '{print $2}')
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Auto-detect stack
# ─────────────────────────────────────────────────────────────────────────────

detect_stack() {
  if [ -f "package.json" ]; then
    # Use typescript stack for both TS and JS projects (settings work for both)
    echo "typescript"
  elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ] || [ -f "setup.py" ]; then
    echo "python"
  elif [ -f "go.mod" ]; then
    echo "go"
  elif [ -f "Cargo.toml" ]; then
    echo "rust"
  elif [ -f "Gemfile" ]; then
    echo "ruby"
  elif [ -f "mix.exs" ]; then
    echo "elixir"
  else
    echo "generic"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Main setup flow
# ─────────────────────────────────────────────────────────────────────────────

print_header

# Step 1: Stack Selection
print_step "Step 1: Select Your Stack"

DETECTED_STACK=$(detect_stack)

if [ "$DETECTED_STACK" != "generic" ]; then
  echo -e "  ${DIM}Detected: ${DETECTED_STACK}${NC}"
  echo ""
fi

STACKS=("TypeScript/JavaScript" "Python" "Go" "Rust" "Ruby" "Elixir" "Generic (any stack)")
select_option "Which stack is this project using?" "${STACKS[@]}"

case $SELECTED_INDEX in
  0) STACK="typescript" ;;
  1) STACK="python" ;;
  2) STACK="go" ;;
  3) STACK="rust" ;;
  4) STACK="ruby" ;;
  5) STACK="elixir" ;;
  *) STACK="generic" ;;
esac

print_success "Selected: $STACK"

# Detect versions from .tool-versions or runtime
detect_versions

if [ -f ".tool-versions" ]; then
  print_info "Found .tool-versions - will use detected versions"
fi

# Step 2: Project Information
print_step "Step 2: Project Information"

PROJECT_NAME=$(prompt "Project name" "$(basename "$TARGET_DIR")")
PROJECT_DESC=$(prompt "Brief description" "")

# Step 3: Stack-specific commands
print_step "Step 3: Commands"

case $STACK in
  typescript)
    CMD_DEV=$(prompt "Dev command" "npm run dev")
    CMD_TEST=$(prompt "Test command" "npm test")
    CMD_BUILD=$(prompt "Build command" "npm run build")
    CMD_LINT=$(prompt "Lint command" "npm run lint")
    CMD_TYPECHECK=$(prompt "Type check command" "npx tsc --noEmit")
    ;;
  python)
    CMD_DEV=$(prompt "Dev command" "python -m uvicorn app:app --reload")
    CMD_TEST=$(prompt "Test command" "pytest")
    CMD_LINT=$(prompt "Lint command" "ruff check .")
    CMD_FORMAT=$(prompt "Format command" "black .")
    CMD_TYPECHECK=$(prompt "Type check command" "mypy .")
    ;;
  go)
    CMD_DEV=$(prompt "Dev command" "go run .")
    CMD_TEST=$(prompt "Test command" "go test ./...")
    CMD_BUILD=$(prompt "Build command" "go build -o bin/app")
    CMD_LINT=$(prompt "Lint command" "golangci-lint run")
    ;;
  rust)
    CMD_DEV=$(prompt "Dev command" "cargo run")
    CMD_TEST=$(prompt "Test command" "cargo test")
    CMD_BUILD=$(prompt "Build command" "cargo build --release")
    CMD_LINT=$(prompt "Lint command" "cargo clippy")
    ;;
  ruby)
    CMD_DEV=$(prompt "Dev command" "bin/rails server")
    CMD_TEST=$(prompt "Test command" "bundle exec rspec")
    CMD_LINT=$(prompt "Lint command" "bundle exec rubocop")
    CMD_CONSOLE=$(prompt "Console command" "bin/rails console")
    ;;
  elixir)
    CMD_DEV=$(prompt "Dev command" "mix phx.server")
    CMD_TEST=$(prompt "Test command" "mix test")
    CMD_FORMAT=$(prompt "Format command" "mix format")
    CMD_LINT=$(prompt "Lint command" "mix credo")
    ;;
  *)
    CMD_DEV=$(prompt "Dev command" "")
    CMD_TEST=$(prompt "Test command" "")
    CMD_BUILD=$(prompt "Build command" "")
    CMD_LINT=$(prompt "Lint command" "")
    ;;
esac

# Step 4: Components
print_step "Step 4: Components to Install"

INSTALL_RULES=true
INSTALL_SKILLS=true
INSTALL_AGENTS=true
INSTALL_HOOKS=true
INSTALL_MCP=false
INSTALL_PRECOMMIT_REVIEW=false

if ! prompt_yn "Install modular rules?" "y"; then INSTALL_RULES=false; fi
if ! prompt_yn "Install skills (/review, /test, etc.)?" "y"; then INSTALL_SKILLS=false; fi
if ! prompt_yn "Install agents (researcher, reviewer, etc.)?" "y"; then INSTALL_AGENTS=false; fi
if ! prompt_yn "Install security hooks?" "y"; then INSTALL_HOOKS=false; fi
if prompt_yn "Create MCP server template?" "n"; then INSTALL_MCP=true; fi
echo ""
echo -e "  ${DIM}Pre-commit review forces you to review and confirm changes before${NC}"
echo -e "  ${DIM}every git commit. Helps prevent 'vibe coding' with AI assistants.${NC}"
if prompt_yn "Install pre-commit review hook?" "n"; then INSTALL_PRECOMMIT_REVIEW=true; fi

# ─────────────────────────────────────────────────────────────────────────────
# Create files
# ─────────────────────────────────────────────────────────────────────────────

print_step "Step 5: Creating Configuration"

# Create directories (.claude/ tracked at cleanup level, not individually)
mkdir -p "$TARGET_DIR/.claude/rules"
mkdir -p "$TARGET_DIR/.claude/skills"
mkdir -p "$TARGET_DIR/.claude/agents"
mkdir -p "$TARGET_DIR/.claude/hooks"

# Generate CLAUDE.md from stack template or create generic
print_info "Creating CLAUDE.md..."

if [ -f "$SCRIPT_DIR/stacks/$STACK/CLAUDE.md" ]; then
  # Use stack template and substitute variables
  # Using | as delimiter to avoid issues with / in paths
  # Escaping special characters in user input
  sed -e "s|{{PROJECT_NAME}}|$(sed_escape "$PROJECT_NAME")|g" \
      -e "s|{{PROJECT_DESC}}|$(sed_escape "$PROJECT_DESC")|g" \
      -e "s|{{CMD_DEV}}|$(sed_escape "${CMD_DEV:-# not configured}")|g" \
      -e "s|{{CMD_TEST}}|$(sed_escape "${CMD_TEST:-# not configured}")|g" \
      -e "s|{{CMD_BUILD}}|$(sed_escape "${CMD_BUILD:-# not configured}")|g" \
      -e "s|{{CMD_LINT}}|$(sed_escape "${CMD_LINT:-# not configured}")|g" \
      -e "s|{{CMD_FORMAT}}|$(sed_escape "${CMD_FORMAT:-# not configured}")|g" \
      -e "s|{{CMD_TYPECHECK}}|$(sed_escape "${CMD_TYPECHECK:-# not configured}")|g" \
      -e "s|{{CMD_CONSOLE}}|$(sed_escape "${CMD_CONSOLE:-# not configured}")|g" \
      -e "s|{{FRAMEWORK}}|[specify your framework]|g" \
      -e "s|{{DATABASE}}|[specify if applicable]|g" \
      -e "s|{{PACKAGE_MANAGER}}|[npm/yarn/pnpm]|g" \
      -e "s|{{NODE_VERSION}}|${DETECTED_NODE_VERSION:-[specify version]}|g" \
      -e "s|{{TS_VERSION}}|[specify version]|g" \
      -e "s|{{PYTHON_VERSION}}|${DETECTED_PYTHON_VERSION:-[specify version]}|g" \
      -e "s|{{GO_VERSION}}|${DETECTED_GO_VERSION:-[specify version]}|g" \
      -e "s|{{RUST_VERSION}}|${DETECTED_RUST_VERSION:-[specify version]}|g" \
      -e "s|{{RUBY_VERSION}}|${DETECTED_RUBY_VERSION:-[specify version]}|g" \
      -e "s|{{ELIXIR_VERSION}}|${DETECTED_ELIXIR_VERSION:-[specify version]}|g" \
      "$SCRIPT_DIR/stacks/$STACK/CLAUDE.md" > "$TARGET_DIR/CLAUDE.md"
else
  cat > "$TARGET_DIR/CLAUDE.md" << EOF
# $PROJECT_NAME

$PROJECT_DESC

## Commands

\`\`\`bash
${CMD_DEV:-# Dev command not configured}
${CMD_TEST:-# Test command not configured}
${CMD_BUILD:-# Build command not configured}
${CMD_LINT:-# Lint command not configured}
\`\`\`

## Code Conventions

<!-- Add your project's conventions -->

## Do Not

- Never commit secrets or .env files
- Don't modify generated files directly
EOF
fi
track_file "$TARGET_DIR/CLAUDE.md"
print_success "Created CLAUDE.md"

# Copy stack-specific settings.json
print_info "Creating .claude/settings.json..."

if [ -f "$SCRIPT_DIR/stacks/$STACK/settings.json" ]; then
  cp "$SCRIPT_DIR/stacks/$STACK/settings.json" "$TARGET_DIR/.claude/settings.json"
elif [ -f "$SCRIPT_DIR/.claude/settings.json" ]; then
  cp "$SCRIPT_DIR/.claude/settings.json" "$TARGET_DIR/.claude/settings.json"
fi
track_file "$TARGET_DIR/.claude/settings.json"
print_success "Created .claude/settings.json ($STACK preset)"

# Create or update .claudeignore
if [ ! -f "$TARGET_DIR/.claudeignore" ]; then
  print_info "Creating .claudeignore..."
  if [ -f "$SCRIPT_DIR/.claudeignore" ]; then
    cp "$SCRIPT_DIR/.claudeignore" "$TARGET_DIR/.claudeignore"
    track_file "$TARGET_DIR/.claudeignore"
  fi
  print_success "Created .claudeignore"
else
  # Append missing recommended patterns to existing .claudeignore
  print_info "Updating .claudeignore with recommended patterns..."
  CLAUDEIGNORE_UPDATED=false
  # Essential patterns that prevent "my context is huge" issues
  RECOMMENDED_PATTERNS=(
    "node_modules/"
    "vendor/"
    ".venv/"
    "venv/"
    "__pycache__/"
    "dist/"
    "build/"
    ".next/"
    "coverage/"
    "package-lock.json"
    "yarn.lock"
    "pnpm-lock.yaml"
  )
  for pattern in "${RECOMMENDED_PATTERNS[@]}"; do
    if ! grep -q "^${pattern}$" "$TARGET_DIR/.claudeignore" 2>/dev/null; then
      echo "$pattern" >> "$TARGET_DIR/.claudeignore"
      CLAUDEIGNORE_UPDATED=true
    fi
  done
  if [ "$CLAUDEIGNORE_UPDATED" = true ]; then
    print_success "Added missing patterns to .claudeignore"
  else
    print_info ".claudeignore already has recommended patterns"
  fi
fi

# Copy rules
if [ "$INSTALL_RULES" = true ]; then
  print_info "Installing rules..."
  cp -r "$SCRIPT_DIR/.claude/rules/"* "$TARGET_DIR/.claude/rules/" 2>/dev/null || true
  # Add stack-specific rules
  if [ -f "$SCRIPT_DIR/stacks/$STACK/rules.md" ]; then
    cp "$SCRIPT_DIR/stacks/$STACK/rules.md" "$TARGET_DIR/.claude/rules/${STACK}.md"
  fi
  print_success "Installed rules (including $STACK-specific)"
fi

# Copy skills
if [ "$INSTALL_SKILLS" = true ]; then
  print_info "Installing skills..."
  cp -r "$SCRIPT_DIR/.claude/skills/"* "$TARGET_DIR/.claude/skills/" 2>/dev/null || true
  print_success "Installed skills"
fi

# Copy agents
if [ "$INSTALL_AGENTS" = true ]; then
  print_info "Installing agents..."
  cp -r "$SCRIPT_DIR/.claude/agents/"* "$TARGET_DIR/.claude/agents/" 2>/dev/null || true
  print_success "Installed agents"
fi

# Copy hooks
if [ "$INSTALL_HOOKS" = true ]; then
  print_info "Installing security hooks..."
  cp -r "$SCRIPT_DIR/.claude/hooks/"* "$TARGET_DIR/.claude/hooks/" 2>/dev/null || true
  chmod +x "$TARGET_DIR/.claude/hooks/"*.sh 2>/dev/null || true
  print_success "Installed security hooks"
fi

# Create MCP template
if [ "$INSTALL_MCP" = true ]; then
  print_info "Creating .mcp.json.example..."
  if [ -f "$SCRIPT_DIR/.mcp.json.example" ]; then
    cp "$SCRIPT_DIR/.mcp.json.example" "$TARGET_DIR/.mcp.json.example"
    track_file "$TARGET_DIR/.mcp.json.example"
  fi
  print_success "Created .mcp.json.example"
fi

# Update .gitignore
print_info "Updating .gitignore..."
touch "$TARGET_DIR/.gitignore"
for entry in "CLAUDE.local.md" ".claude/settings.local.json"; do
  if ! grep -q "^$entry$" "$TARGET_DIR/.gitignore" 2>/dev/null; then
    echo "$entry" >> "$TARGET_DIR/.gitignore"
  fi
done
print_success "Updated .gitignore"

# Install git pre-commit hook (if opted in)
if [ "$INSTALL_PRECOMMIT_REVIEW" = true ]; then
  if [ -d "$TARGET_DIR/.git" ]; then
    print_info "Installing git pre-commit review hook..."
    mkdir -p "$TARGET_DIR/.git/hooks"
    if [ -f "$TARGET_DIR/.claude/hooks/pre-commit-review.sh" ]; then
      cp "$TARGET_DIR/.claude/hooks/pre-commit-review.sh" "$TARGET_DIR/.git/hooks/pre-commit"
      chmod +x "$TARGET_DIR/.git/hooks/pre-commit"
      print_success "Installed git pre-commit hook (review before every commit)"
    fi
  else
    print_warning "No .git directory found - skipping pre-commit hook"
    print_info "Run 'git init' then: cp .claude/hooks/pre-commit-review.sh .git/hooks/pre-commit"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

# Mark setup as complete to prevent cleanup
SETUP_COMPLETE=true

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}Stack:${NC} $STACK"
echo ""
echo -e "  ${BOLD}Files created:${NC}"
echo "    • CLAUDE.md              - Project context"
echo "    • .claudeignore          - File exclusions"
echo "    • .claude/settings.json  - Permissions & hooks"
[ "$INSTALL_RULES" = true ] && echo "    • .claude/rules/         - Code rules ($STACK-specific)"
[ "$INSTALL_SKILLS" = true ] && echo "    • .claude/skills/        - Custom commands"
[ "$INSTALL_AGENTS" = true ] && echo "    • .claude/agents/        - Specialized agents"
[ "$INSTALL_HOOKS" = true ] && echo "    • .claude/hooks/         - Security hooks"
[ "$INSTALL_MCP" = true ] && echo "    • .mcp.json.example      - MCP template"
[ "$INSTALL_PRECOMMIT_REVIEW" = true ] && echo "    • .git/hooks/pre-commit  - Pre-commit review"
echo ""
echo -e "  ${BOLD}Security features:${NC}"
echo "    • .env file blocking (read/edit/write)"
echo "    • Dangerous command prevention (rm -rf, sudo, curl|bash)"
echo "    • Pre-tool security gate hook"
[ "$INSTALL_PRECOMMIT_REVIEW" = true ] && echo "    • Pre-commit review (understand before committing)"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo "    1. Review and customize CLAUDE.md for your project"
echo "    2. Check .claude/settings.json permissions"
echo "    3. Run 'claude' to start"
echo ""
echo -e "  ${DIM}Documentation: https://github.com/zbruhnke/claude-code-starter${NC}"
echo ""
