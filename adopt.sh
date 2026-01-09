#!/bin/bash
#
# Claude Code Starter - Adoption Script
# Selectively adopt components into an existing project
#
# Usage: ./adopt.sh [component]
#
# Components:
#   skills      - Install custom skills (/review, /test, etc.)
#   agents      - Install specialized agents
#   hooks       - Install security and formatting hooks
#   rules       - Install reference documentation
#   precommit   - Install pre-commit review hook
#   security    - Install security configuration (permissions + hooks)
#   stack       - Install stack-specific preset
#   all         - Install everything
#
# Without arguments, runs interactive mode.
#
# Dependencies: bash 4.0+
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
  echo "  /opt/homebrew/bin/bash $0"
  echo ""
  echo "Or add to your shell config:"
  echo "  export PATH=\"/opt/homebrew/bin:\$PATH\""
  exit 1
fi

# Script location (where claude-code-starter is)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$(pwd)"

# Source common utilities
source "$SCRIPT_DIR/lib/common.sh"

check_installed() {
  local component="$1"
  case $component in
    skills) [ -d "$TARGET_DIR/.claude/skills" ] && [ "$(ls -A "$TARGET_DIR/.claude/skills" 2>/dev/null)" ] ;;
    agents) [ -d "$TARGET_DIR/.claude/agents" ] && [ "$(ls -A "$TARGET_DIR/.claude/agents" 2>/dev/null)" ] ;;
    hooks) [ -d "$TARGET_DIR/.claude/hooks" ] && [ "$(ls -A "$TARGET_DIR/.claude/hooks" 2>/dev/null)" ] ;;
    rules) [ -d "$TARGET_DIR/.claude/rules" ] && [ "$(ls -A "$TARGET_DIR/.claude/rules" 2>/dev/null)" ] ;;
    precommit) [ -f "$TARGET_DIR/.git/hooks/pre-commit" ] ;;
    settings) [ -f "$TARGET_DIR/.claude/settings.json" ] ;;
    claudemd) [ -f "$TARGET_DIR/CLAUDE.md" ] ;;
  esac
}

status_icon() {
  if check_installed "$1"; then
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${DIM}○${NC}"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Installation functions
# ─────────────────────────────────────────────────────────────────────────────

install_skills() {
  print_info "Installing skills..."
  mkdir -p "$TARGET_DIR/.claude/skills"

  # Copy each skill directory
  for skill_dir in "$SCRIPT_DIR/.claude/skills/"*/; do
    if [ -d "$skill_dir" ]; then
      skill_name=$(basename "$skill_dir")
      if [ -d "$TARGET_DIR/.claude/skills/$skill_name" ]; then
        print_warning "Skill '$skill_name' already exists, skipping"
      else
        cp -r "$skill_dir" "$TARGET_DIR/.claude/skills/"
        print_success "Installed skill: $skill_name"
      fi
    fi
  done
}

install_agents() {
  print_info "Installing agents..."
  mkdir -p "$TARGET_DIR/.claude/agents"

  for agent in "$SCRIPT_DIR/.claude/agents/"*.md; do
    if [ -f "$agent" ]; then
      agent_name=$(basename "$agent")
      if [ -f "$TARGET_DIR/.claude/agents/$agent_name" ]; then
        print_warning "Agent '$agent_name' already exists, skipping"
      else
        cp "$agent" "$TARGET_DIR/.claude/agents/"
        print_success "Installed agent: $agent_name"
      fi
    fi
  done
}

install_hooks() {
  print_info "Installing hooks..."
  mkdir -p "$TARGET_DIR/.claude/hooks"

  for hook in "$SCRIPT_DIR/.claude/hooks/"*.sh; do
    if [ -f "$hook" ]; then
      hook_name=$(basename "$hook")
      # Skip pre-commit-review.sh - that's handled separately
      if [ "$hook_name" = "pre-commit-review.sh" ]; then
        continue
      fi
      if [ -f "$TARGET_DIR/.claude/hooks/$hook_name" ]; then
        print_warning "Hook '$hook_name' already exists, skipping"
      else
        cp "$hook" "$TARGET_DIR/.claude/hooks/"
        chmod +x "$TARGET_DIR/.claude/hooks/$hook_name"
        print_success "Installed hook: $hook_name"
      fi
    fi
  done

  # Update settings.json to include hooks if not present
  if [ -f "$TARGET_DIR/.claude/settings.json" ]; then
    if ! grep -q '"hooks"' "$TARGET_DIR/.claude/settings.json"; then
      print_info "Note: Add hooks configuration to .claude/settings.json manually"
      print_info "See README.md for hook configuration examples"
    fi
  fi
}

install_rules() {
  print_info "Installing rules..."
  mkdir -p "$TARGET_DIR/.claude/rules"

  for rule in "$SCRIPT_DIR/.claude/rules/"*.md; do
    if [ -f "$rule" ]; then
      rule_name=$(basename "$rule")
      if [ -f "$TARGET_DIR/.claude/rules/$rule_name" ]; then
        print_warning "Rule '$rule_name' already exists, skipping"
      else
        cp "$rule" "$TARGET_DIR/.claude/rules/"
        print_success "Installed rule: $rule_name"
      fi
    fi
  done
}

install_precommit() {
  print_info "Installing pre-commit review hook..."

  if [ ! -d "$TARGET_DIR/.git" ]; then
    print_error "Not a git repository. Run 'git init' first."
    return 1
  fi

  mkdir -p "$TARGET_DIR/.git/hooks"
  mkdir -p "$TARGET_DIR/.claude/hooks"

  # Copy the hook script to .claude/hooks
  cp "$SCRIPT_DIR/.claude/hooks/pre-commit-review.sh" "$TARGET_DIR/.claude/hooks/"
  chmod +x "$TARGET_DIR/.claude/hooks/pre-commit-review.sh"

  # Install as git hook
  if [ -f "$TARGET_DIR/.git/hooks/pre-commit" ]; then
    print_warning "Pre-commit hook already exists"
    echo -e "  ${DIM}Existing hook saved to .git/hooks/pre-commit.backup${NC}"
    mv "$TARGET_DIR/.git/hooks/pre-commit" "$TARGET_DIR/.git/hooks/pre-commit.backup"
  fi

  cp "$TARGET_DIR/.claude/hooks/pre-commit-review.sh" "$TARGET_DIR/.git/hooks/pre-commit"
  chmod +x "$TARGET_DIR/.git/hooks/pre-commit"
  print_success "Installed pre-commit review hook"
  echo ""
  echo -e "  ${DIM}Every commit will now show a review summary.${NC}"
  echo -e "  ${DIM}Skip with: SKIP_PRE_COMMIT_REVIEW=1 git commit${NC}"
}

install_security() {
  print_info "Installing security configuration..."
  mkdir -p "$TARGET_DIR/.claude"
  mkdir -p "$TARGET_DIR/.claude/hooks"

  # Install validate-bash hook
  if [ ! -f "$TARGET_DIR/.claude/hooks/validate-bash.sh" ]; then
    cp "$SCRIPT_DIR/.claude/hooks/validate-bash.sh" "$TARGET_DIR/.claude/hooks/"
    chmod +x "$TARGET_DIR/.claude/hooks/validate-bash.sh"
    print_success "Installed validate-bash.sh"
  fi

  # Create or merge settings.json
  if [ -f "$TARGET_DIR/.claude/settings.json" ]; then
    print_warning "settings.json exists - please merge security settings manually"
    echo ""
    echo -e "  ${DIM}Add these deny rules to your settings.json:${NC}"
    echo '    "deny": ['
    echo '      "Read(.env)", "Read(.env.*)",'
    echo '      "Read(**/*.pem)", "Read(**/*.key)",'
    echo '      "Edit(.env)", "Write(.env)",'
    echo '      "Bash(rm -rf /)", "Bash(sudo:*)"'
    echo '    ]'
  else
    cp "$SCRIPT_DIR/.claude/settings.json" "$TARGET_DIR/.claude/settings.json"
    print_success "Created settings.json with security defaults"
  fi

  # Install security rules
  mkdir -p "$TARGET_DIR/.claude/rules"
  for rule in "security.md" "security-model.md"; do
    if [ -f "$SCRIPT_DIR/.claude/rules/$rule" ]; then
      cp "$SCRIPT_DIR/.claude/rules/$rule" "$TARGET_DIR/.claude/rules/"
      print_success "Installed $rule"
    fi
  done
}

install_stack() {
  echo ""
  echo -e "  ${BOLD}Available stacks:${NC}"
  echo "    1) TypeScript"
  echo "    2) Python"
  echo "    3) Go"
  echo "    4) Rust"
  echo "    5) Ruby"
  echo "    6) Elixir"
  echo ""

  read -r -p "  Select stack [1-6]: " choice

  case $choice in
    1) STACK="typescript" ;;
    2) STACK="python" ;;
    3) STACK="go" ;;
    4) STACK="rust" ;;
    5) STACK="ruby" ;;
    6) STACK="elixir" ;;
    *) print_error "Invalid choice"; return 1 ;;
  esac

  print_info "Installing $STACK preset..."

  # Copy stack-specific rules
  if [ -f "$SCRIPT_DIR/stacks/$STACK/rules.md" ]; then
    mkdir -p "$TARGET_DIR/.claude/rules"
    cp "$SCRIPT_DIR/stacks/$STACK/rules.md" "$TARGET_DIR/.claude/rules/${STACK}.md"
    print_success "Installed ${STACK}.md rules"
  fi

  # Offer to replace settings.json
  if [ -f "$SCRIPT_DIR/stacks/$STACK/settings.json" ]; then
    if [ -f "$TARGET_DIR/.claude/settings.json" ]; then
      echo ""
      read -r -p "  Replace settings.json with $STACK preset? [y/N]: " replace
      if [[ "$replace" =~ ^[Yy] ]]; then
        cp "$SCRIPT_DIR/stacks/$STACK/settings.json" "$TARGET_DIR/.claude/settings.json"
        print_success "Replaced settings.json with $STACK preset"
      else
        print_info "Kept existing settings.json"
      fi
    else
      mkdir -p "$TARGET_DIR/.claude"
      cp "$SCRIPT_DIR/stacks/$STACK/settings.json" "$TARGET_DIR/.claude/settings.json"
      print_success "Created settings.json with $STACK preset"
    fi
  fi

  # Show CLAUDE.md template location
  if [ -f "$SCRIPT_DIR/stacks/$STACK/CLAUDE.md" ]; then
    echo ""
    echo -e "  ${DIM}Stack template available at: stacks/$STACK/CLAUDE.md${NC}"
    echo -e "  ${DIM}Copy and customize for your project.${NC}"
  fi
}

install_single_skill() {
  local skill_name="$1"

  # Validate skill name - no path separators or traversal
  if [[ "$skill_name" == *"/"* ]] || [[ "$skill_name" == *".."* ]] || [[ "$skill_name" == "."* ]]; then
    print_error "Invalid skill name: '$skill_name' (no paths allowed)"
    return 1
  fi

  if [ ! -d "$SCRIPT_DIR/.claude/skills/$skill_name" ]; then
    print_error "Skill '$skill_name' not found"
    echo ""
    echo "Available skills:"
    for skill_dir in "$SCRIPT_DIR/.claude/skills/"*/; do
      echo "  - $(basename "$skill_dir")"
    done
    return 1
  fi

  mkdir -p "$TARGET_DIR/.claude/skills"
  cp -r "$SCRIPT_DIR/.claude/skills/$skill_name" "$TARGET_DIR/.claude/skills/"
  print_success "Installed skill: $skill_name"
}

install_single_agent() {
  local agent_name="$1"

  # Validate agent name - no path separators or traversal
  if [[ "$agent_name" == *"/"* ]] || [[ "$agent_name" == *".."* ]] || [[ "$agent_name" == "."* ]]; then
    print_error "Invalid agent name: '$agent_name' (no paths allowed)"
    return 1
  fi

  if [ ! -f "$SCRIPT_DIR/.claude/agents/${agent_name}.md" ]; then
    print_error "Agent '$agent_name' not found"
    echo ""
    echo "Available agents:"
    for agent in "$SCRIPT_DIR/.claude/agents/"*.md; do
      echo "  - $(basename "$agent" .md)"
    done
    return 1
  fi

  mkdir -p "$TARGET_DIR/.claude/agents"
  cp "$SCRIPT_DIR/.claude/agents/${agent_name}.md" "$TARGET_DIR/.claude/agents/"
  print_success "Installed agent: $agent_name"
}

# ─────────────────────────────────────────────────────────────────────────────
# Interactive mode
# ─────────────────────────────────────────────────────────────────────────────

interactive_mode() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  Claude Code Starter - Adopt Components${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "  ${BOLD}Target:${NC} $TARGET_DIR"
  echo ""
  echo -e "  ${BOLD}Current Status:${NC}"
  echo -e "    $(status_icon claudemd) CLAUDE.md"
  echo -e "    $(status_icon settings) .claude/settings.json"
  echo -e "    $(status_icon skills) Skills"
  echo -e "    $(status_icon agents) Agents"
  echo -e "    $(status_icon hooks) Hooks"
  echo -e "    $(status_icon rules) Rules"
  echo -e "    $(status_icon precommit) Pre-commit review"
  echo ""
  echo -e "  ${BOLD}What would you like to adopt?${NC}"
  echo ""
  echo "    1) Skills        - Custom commands (review, test, explain, etc.)"
  echo "    2) Agents        - Specialized subagents (researcher, reviewer)"
  echo "    3) Hooks         - Security and auto-formatting hooks"
  echo "    4) Rules         - Reference documentation"
  echo "    5) Pre-commit    - Review changes before every commit"
  echo "    6) Security      - Security configuration (permissions + hooks)"
  echo "    7) Stack preset  - Language-specific configuration"
  echo "    8) Everything    - Install all components"
  echo ""
  echo "    s) Single skill  - Install one specific skill"
  echo "    a) Single agent  - Install one specific agent"
  echo ""
  echo "    q) Quit"
  echo ""

  read -r -p "  Select option: " choice
  echo ""

  case $choice in
    1) install_skills ;;
    2) install_agents ;;
    3) install_hooks ;;
    4) install_rules ;;
    5) install_precommit ;;
    6) install_security ;;
    7) install_stack ;;
    8)
      install_skills
      install_agents
      install_hooks
      install_rules
      install_security
      echo ""
      read -r -p "  Also install pre-commit review hook? [y/N]: " precommit
      [[ "$precommit" =~ ^[Yy] ]] && install_precommit
      ;;
    s|S)
      echo "Available skills:"
      for skill_dir in "$SCRIPT_DIR/.claude/skills/"*/; do
        echo "  - $(basename "$skill_dir")"
      done
      echo ""
      read -r -p "  Skill name: " skill_name
      install_single_skill "$skill_name"
      ;;
    a|A)
      echo "Available agents:"
      for agent in "$SCRIPT_DIR/.claude/agents/"*.md; do
        echo "  - $(basename "$agent" .md)"
      done
      echo ""
      read -r -p "  Agent name: " agent_name
      install_single_agent "$agent_name"
      ;;
    q|Q) exit 0 ;;
    *) print_error "Invalid option" ;;
  esac

  echo ""
  print_success "Done!"
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

# Handle help before any other checks
if [ $# -gt 0 ] && [[ "$1" == "-h" || "$1" == "--help" || "$1" == "help" ]]; then
  echo "Usage: adopt.sh [component]"
  echo ""
  echo "Components:"
  echo "  skills      Install custom skills"
  echo "  agents      Install specialized agents"
  echo "  hooks       Install security/formatting hooks"
  echo "  rules       Install reference documentation"
  echo "  precommit   Install pre-commit review hook"
  echo "  security    Install security configuration"
  echo "  stack       Install stack-specific preset"
  echo "  all         Install everything"
  echo ""
  echo "  skill <name>   Install a specific skill"
  echo "  agent <name>   Install a specific agent"
  echo ""
  echo "Without arguments, runs interactive mode."
  exit 0
fi

# Check we're not in the starter repo itself
if [ "$TARGET_DIR" = "$SCRIPT_DIR" ]; then
  print_error "Cannot adopt into the starter repo itself"
  echo "  Run this script from your project directory:"
  echo "    cd /path/to/your/project"
  echo "    /path/to/claude-code-starter/adopt.sh"
  exit 1
fi

# Handle command line arguments
if [ $# -eq 0 ]; then
  interactive_mode
else
  case "$1" in
    skills) install_skills ;;
    agents) install_agents ;;
    hooks) install_hooks ;;
    rules) install_rules ;;
    precommit) install_precommit ;;
    security) install_security ;;
    stack) install_stack ;;
    all)
      install_skills
      install_agents
      install_hooks
      install_rules
      install_security
      ;;
    skill)
      if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
        print_error "Usage: adopt.sh skill <skill-name>"
        exit 1
      fi
      install_single_skill "$2"
      ;;
    agent)
      if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
        print_error "Usage: adopt.sh agent <agent-name>"
        exit 1
      fi
      install_single_agent "$2"
      ;;
    *)
      print_error "Unknown component: $1"
      echo "Run 'adopt.sh --help' for usage"
      exit 1
      ;;
  esac

  echo ""
  print_success "Done!"
fi
