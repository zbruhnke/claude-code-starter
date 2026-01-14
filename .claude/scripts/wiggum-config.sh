#!/usr/bin/env bash
#
# Wiggum Configuration Manager
# Manages wiggum.config.json - the single source of truth for project configuration
#
# Usage:
#   wiggum-config.sh get <path>              # Get value: "commands.test.command"
#   wiggum-config.sh validate                # Validate config exists and is valid
#   wiggum-config.sh discover                # Auto-detect commands from project files
#   wiggum-config.sh init [--from-discover]  # Initialize config (optionally from discovery)
#   wiggum-config.sh set <path> <value>      # Set a config value
#
# Environment:
#   WIGGUM_CONFIG - Override config file path (default: wiggum.config.json)
#

set -euo pipefail

# Configuration
CONFIG_FILE="${WIGGUM_CONFIG:-wiggum.config.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors (disabled in non-interactive contexts)
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

# Ensure jq is available
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is required but not installed${NC}" >&2
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# GET - Query configuration value
# ─────────────────────────────────────────────────────────────────────────────
get_config() {
  local path="$1"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo ""
    return 1
  fi

  # Convert dot notation to jq path
  local jq_path
  jq_path=$(echo "$path" | sed 's/\./\./g')

  jq -r ".$jq_path // empty" "$CONFIG_FILE" 2>/dev/null || echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# SET - Update configuration value
# ─────────────────────────────────────────────────────────────────────────────
set_config() {
  local path="$1"
  local value="$2"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Error: $CONFIG_FILE not found${NC}" >&2
    return 1
  fi

  # Determine if value is a string or other type
  local jq_value
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    jq_value="$value"
  elif [[ "$value" == "true" ]] || [[ "$value" == "false" ]]; then
    jq_value="$value"
  else
    jq_value="\"$value\""
  fi

  jq ".$path = $jq_value" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
  echo -e "${GREEN}Set $path = $value${NC}"
}

# ─────────────────────────────────────────────────────────────────────────────
# VALIDATE - Check configuration is valid
# ─────────────────────────────────────────────────────────────────────────────
validate_config() {
  local errors=0

  echo -e "${BOLD}Validating wiggum configuration...${NC}"
  echo ""

  # Check file exists
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}  [FAIL] $CONFIG_FILE not found${NC}"
    echo -e "${YELLOW}  Run: wiggum-config.sh init${NC}"
    return 1
  fi
  echo -e "${GREEN}  [OK] Config file exists${NC}"

  # Check valid JSON
  if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo -e "${RED}  [FAIL] Invalid JSON syntax${NC}"
    return 1
  fi
  echo -e "${GREEN}  [OK] Valid JSON${NC}"

  # Check version
  local version
  version=$(get_config "version")
  if [[ -z "$version" ]]; then
    echo -e "${YELLOW}  [WARN] No version field${NC}"
  else
    echo -e "${GREEN}  [OK] Version: $version${NC}"
  fi

  # Check commands section
  local test_cmd lint_cmd
  test_cmd=$(get_config "commands.test.command")
  lint_cmd=$(get_config "commands.lint.command")

  if [[ -z "$test_cmd" ]]; then
    echo -e "${YELLOW}  [WARN] commands.test.command is empty${NC}"
    ((errors++)) || true
  else
    echo -e "${GREEN}  [OK] TEST: $test_cmd${NC}"
  fi

  if [[ -z "$lint_cmd" ]]; then
    echo -e "${YELLOW}  [WARN] commands.lint.command is empty${NC}"
    ((errors++)) || true
  else
    echo -e "${GREEN}  [OK] LINT: $lint_cmd${NC}"
  fi

  # Check limits
  local max_iter max_fail
  max_iter=$(get_config "limits.max_iterations_per_chunk")
  max_fail=$(get_config "limits.max_gate_failures")

  if [[ -z "$max_iter" ]] || [[ "$max_iter" -lt 1 ]]; then
    echo -e "${YELLOW}  [WARN] limits.max_iterations_per_chunk should be >= 1${NC}"
  else
    echo -e "${GREEN}  [OK] Max iterations/chunk: $max_iter${NC}"
  fi

  if [[ -z "$max_fail" ]] || [[ "$max_fail" -lt 1 ]]; then
    echo -e "${YELLOW}  [WARN] limits.max_gate_failures should be >= 1${NC}"
  else
    echo -e "${GREEN}  [OK] Max gate failures: $max_fail${NC}"
  fi

  echo ""
  if [[ $errors -gt 0 ]]; then
    echo -e "${YELLOW}Validation completed with $errors warning(s)${NC}"
    echo -e "${YELLOW}Run: wiggum-config.sh discover${NC} to auto-detect commands"
    return 0
  else
    echo -e "${GREEN}${BOLD}Configuration valid${NC}"
    return 0
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# DISCOVER - Auto-detect commands from project files
# ─────────────────────────────────────────────────────────────────────────────
discover_commands() {
  local test_cmd="" lint_cmd="" build_cmd="" typecheck_cmd="" format_cmd=""
  local detected_stack="unknown"

  echo -e "${BOLD}Discovering project commands...${NC}"
  echo ""

  # Node.js / TypeScript
  if [[ -f "package.json" ]]; then
    detected_stack="node"
    echo -e "${BLUE}  Detected: Node.js project${NC}"

    # Package manager detection
    local pm="npm"
    [[ -f "yarn.lock" ]] && pm="yarn"
    [[ -f "pnpm-lock.yaml" ]] && pm="pnpm"
    [[ -f "bun.lockb" ]] && pm="bun"
    echo -e "${BLUE}  Package manager: $pm${NC}"

    # Test command
    if jq -e '.scripts.test' package.json &>/dev/null; then
      test_cmd="$pm test"
    fi

    # Lint command
    if jq -e '.scripts.lint' package.json &>/dev/null; then
      lint_cmd="$pm run lint"
    elif [[ -f ".eslintrc" ]] || [[ -f ".eslintrc.js" ]] || [[ -f ".eslintrc.json" ]] || [[ -f "eslint.config.js" ]]; then
      lint_cmd="npx eslint ."
    fi

    # Build command
    if jq -e '.scripts.build' package.json &>/dev/null; then
      build_cmd="$pm run build"
    fi

    # Typecheck command
    if jq -e '.scripts.typecheck' package.json &>/dev/null; then
      typecheck_cmd="$pm run typecheck"
    elif jq -e '.scripts["type-check"]' package.json &>/dev/null; then
      typecheck_cmd="$pm run type-check"
    elif [[ -f "tsconfig.json" ]]; then
      typecheck_cmd="npx tsc --noEmit"
    fi

    # Format command
    if jq -e '.scripts.format' package.json &>/dev/null; then
      format_cmd="$pm run format"
    elif [[ -f ".prettierrc" ]] || [[ -f ".prettierrc.js" ]] || [[ -f "prettier.config.js" ]]; then
      format_cmd="npx prettier --write ."
    fi

  # Python
  elif [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "requirements.txt" ]]; then
    detected_stack="python"
    echo -e "${BLUE}  Detected: Python project${NC}"

    # Test command
    if [[ -f "pytest.ini" ]] || [[ -d "tests" ]] || grep -q "pytest" pyproject.toml 2>/dev/null; then
      test_cmd="pytest"
    elif [[ -d "test" ]]; then
      test_cmd="python -m unittest discover"
    fi

    # Lint command
    if command -v ruff &>/dev/null || grep -q "ruff" pyproject.toml 2>/dev/null; then
      lint_cmd="ruff check ."
    elif command -v flake8 &>/dev/null; then
      lint_cmd="flake8"
    elif command -v pylint &>/dev/null; then
      lint_cmd="pylint"
    fi

    # Typecheck command
    if command -v mypy &>/dev/null || grep -q "mypy" pyproject.toml 2>/dev/null; then
      typecheck_cmd="mypy ."
    elif command -v pyright &>/dev/null; then
      typecheck_cmd="pyright"
    fi

    # Format command
    if command -v ruff &>/dev/null || grep -q "ruff" pyproject.toml 2>/dev/null; then
      format_cmd="ruff format ."
    elif command -v black &>/dev/null; then
      format_cmd="black ."
    fi

  # Go
  elif [[ -f "go.mod" ]]; then
    detected_stack="go"
    echo -e "${BLUE}  Detected: Go project${NC}"

    test_cmd="go test ./..."
    build_cmd="go build ./..."

    if command -v golangci-lint &>/dev/null; then
      lint_cmd="golangci-lint run"
    else
      lint_cmd="go vet ./..."
    fi

    format_cmd="gofmt -w ."

  # Rust
  elif [[ -f "Cargo.toml" ]]; then
    detected_stack="rust"
    echo -e "${BLUE}  Detected: Rust project${NC}"

    test_cmd="cargo test"
    build_cmd="cargo build"
    lint_cmd="cargo clippy"
    format_cmd="cargo fmt"

  # Ruby
  elif [[ -f "Gemfile" ]]; then
    detected_stack="ruby"
    echo -e "${BLUE}  Detected: Ruby project${NC}"

    if grep -q "rspec" Gemfile 2>/dev/null; then
      test_cmd="bundle exec rspec"
    elif grep -q "minitest" Gemfile 2>/dev/null; then
      test_cmd="bundle exec rake test"
    fi

    if grep -q "rubocop" Gemfile 2>/dev/null; then
      lint_cmd="bundle exec rubocop"
    fi

    format_cmd="bundle exec rubocop -a"

  # Elixir
  elif [[ -f "mix.exs" ]]; then
    detected_stack="elixir"
    echo -e "${BLUE}  Detected: Elixir project${NC}"

    test_cmd="mix test"
    build_cmd="mix compile"

    if grep -q "credo" mix.exs 2>/dev/null; then
      lint_cmd="mix credo"
    fi

    format_cmd="mix format"
  fi

  echo ""
  echo -e "${BOLD}Discovered commands:${NC}"
  [[ -n "$test_cmd" ]] && echo -e "  ${GREEN}TEST:      $test_cmd${NC}" || echo -e "  ${YELLOW}TEST:      (not found)${NC}"
  [[ -n "$lint_cmd" ]] && echo -e "  ${GREEN}LINT:      $lint_cmd${NC}" || echo -e "  ${YELLOW}LINT:      (not found)${NC}"
  [[ -n "$build_cmd" ]] && echo -e "  ${GREEN}BUILD:     $build_cmd${NC}" || echo -e "  ${YELLOW}BUILD:     (not found)${NC}"
  [[ -n "$typecheck_cmd" ]] && echo -e "  ${GREEN}TYPECHECK: $typecheck_cmd${NC}" || echo -e "  ${YELLOW}TYPECHECK: (not found)${NC}"
  [[ -n "$format_cmd" ]] && echo -e "  ${GREEN}FORMAT:    $format_cmd${NC}" || echo -e "  ${YELLOW}FORMAT:    (not found)${NC}"

  # Output as JSON for piping
  if [[ "${1:-}" == "--json" ]]; then
    echo ""
    jq -n \
      --arg stack "$detected_stack" \
      --arg test "$test_cmd" \
      --arg lint "$lint_cmd" \
      --arg build "$build_cmd" \
      --arg typecheck "$typecheck_cmd" \
      --arg format "$format_cmd" \
      '{
        detected_stack: $stack,
        commands: {
          test: { command: $test, required: ($test != ""), timeout: 120000 },
          lint: { command: $lint, required: ($lint != ""), timeout: 60000 },
          build: { command: $build, required: ($build != ""), timeout: 180000 },
          typecheck: { command: $typecheck, required: ($typecheck != ""), timeout: 60000 },
          format: { command: $format, required: false, timeout: 30000 }
        }
      }'
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# INIT - Initialize configuration file
# ─────────────────────────────────────────────────────────────────────────────
init_config() {
  local from_discover=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --from-discover)
        from_discover=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${YELLOW}Config file already exists: $CONFIG_FILE${NC}"
    read -p "Overwrite? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Aborted."
      return 1
    fi
  fi

  local test_cmd="" lint_cmd="" build_cmd="" typecheck_cmd="" format_cmd=""

  if [[ "$from_discover" == true ]]; then
    echo -e "${BOLD}Auto-detecting commands...${NC}"

    # Run discovery and capture results
    local discovery_output
    discovery_output=$(discover_commands --json 2>/dev/null | tail -1)

    test_cmd=$(echo "$discovery_output" | jq -r '.commands.test.command // empty')
    lint_cmd=$(echo "$discovery_output" | jq -r '.commands.lint.command // empty')
    build_cmd=$(echo "$discovery_output" | jq -r '.commands.build.command // empty')
    typecheck_cmd=$(echo "$discovery_output" | jq -r '.commands.typecheck.command // empty')
    format_cmd=$(echo "$discovery_output" | jq -r '.commands.format.command // empty')
  fi

  # Create config file
  cat > "$CONFIG_FILE" << EOF
{
  "\$schema": "./.claude/schemas/wiggum-config.schema.json",
  "version": "1.0",
  "commands": {
    "test": {
      "command": "$test_cmd",
      "required": true,
      "timeout": 120000
    },
    "lint": {
      "command": "$lint_cmd",
      "required": true,
      "timeout": 60000
    },
    "typecheck": {
      "command": "$typecheck_cmd",
      "required": false,
      "timeout": 60000
    },
    "build": {
      "command": "$build_cmd",
      "required": false,
      "timeout": 180000
    },
    "format": {
      "command": "$format_cmd",
      "required": false,
      "timeout": 30000
    }
  },
  "limits": {
    "max_iterations_per_chunk": 5,
    "max_gate_failures": 3,
    "max_chunk_lines": 300,
    "max_chunk_files": 5
  },
  "agents": {
    "researcher": { "enabled": true },
    "test-writer": { "enabled": true },
    "code-reviewer": { "enabled": true, "security_checklist": true },
    "code-simplifier": { "enabled": true },
    "documentation-writer": { "enabled": true },
    "adr-writer": { "enabled": true }
  },
  "paths": {
    "adr": "docs/adr",
    "changelog": "CHANGELOG.md",
    "docs": "docs"
  },
  "dependencies": {
    "require_approval": true,
    "allowed_licenses": ["MIT", "Apache-2.0", "BSD-3-Clause", "ISC", "0BSD", "Unlicense"]
  }
}
EOF

  echo -e "${GREEN}${BOLD}Created $CONFIG_FILE${NC}"
  echo ""
  echo -e "Next steps:"
  echo -e "  1. ${BLUE}wiggum-config.sh validate${NC}    - Verify configuration"
  echo -e "  2. ${BLUE}wiggum-config.sh discover${NC}    - See detected commands"
  echo -e "  3. Edit $CONFIG_FILE to customize"
}

# ─────────────────────────────────────────────────────────────────────────────
# APPLY-DISCOVERY - Apply discovered commands to config
# ─────────────────────────────────────────────────────────────────────────────
apply_discovery() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Error: $CONFIG_FILE not found. Run: wiggum-config.sh init${NC}" >&2
    return 1
  fi

  echo -e "${BOLD}Applying discovered commands to config...${NC}"

  # Run discovery and capture results
  local discovery_output
  discovery_output=$(discover_commands --json 2>/dev/null | tail -1)

  local test_cmd lint_cmd build_cmd typecheck_cmd format_cmd
  test_cmd=$(echo "$discovery_output" | jq -r '.commands.test.command // empty')
  lint_cmd=$(echo "$discovery_output" | jq -r '.commands.lint.command // empty')
  build_cmd=$(echo "$discovery_output" | jq -r '.commands.build.command // empty')
  typecheck_cmd=$(echo "$discovery_output" | jq -r '.commands.typecheck.command // empty')
  format_cmd=$(echo "$discovery_output" | jq -r '.commands.format.command // empty')

  # Update config with discovered values (only if non-empty)
  local updated=0

  if [[ -n "$test_cmd" ]]; then
    jq --arg cmd "$test_cmd" '.commands.test.command = $cmd' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    echo -e "  ${GREEN}TEST:      $test_cmd${NC}"
    ((updated++))
  fi

  if [[ -n "$lint_cmd" ]]; then
    jq --arg cmd "$lint_cmd" '.commands.lint.command = $cmd' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    echo -e "  ${GREEN}LINT:      $lint_cmd${NC}"
    ((updated++))
  fi

  if [[ -n "$build_cmd" ]]; then
    jq --arg cmd "$build_cmd" '.commands.build.command = $cmd' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    echo -e "  ${GREEN}BUILD:     $build_cmd${NC}"
    ((updated++))
  fi

  if [[ -n "$typecheck_cmd" ]]; then
    jq --arg cmd "$typecheck_cmd" '.commands.typecheck.command = $cmd' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    echo -e "  ${GREEN}TYPECHECK: $typecheck_cmd${NC}"
    ((updated++))
  fi

  if [[ -n "$format_cmd" ]]; then
    jq --arg cmd "$format_cmd" '.commands.format.command = $cmd' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    echo -e "  ${GREEN}FORMAT:    $format_cmd${NC}"
    ((updated++))
  fi

  echo ""
  echo -e "${GREEN}Updated $updated command(s) in $CONFIG_FILE${NC}"
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
case "${1:-}" in
  get)
    get_config "${2:-}"
    ;;
  set)
    set_config "${2:-}" "${3:-}"
    ;;
  validate)
    validate_config
    ;;
  discover)
    discover_commands "${2:-}"
    ;;
  apply-discovery)
    apply_discovery
    ;;
  init)
    shift
    init_config "$@"
    ;;
  *)
    echo "Wiggum Configuration Manager"
    echo ""
    echo "Usage: wiggum-config.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  get <path>              Get config value (e.g., 'commands.test.command')"
    echo "  set <path> <value>      Set config value"
    echo "  validate                Validate configuration file"
    echo "  discover [--json]       Auto-detect commands from project"
    echo "  apply-discovery         Apply discovered commands to config"
    echo "  init [--from-discover]  Initialize new config file"
    echo ""
    echo "Environment:"
    echo "  WIGGUM_CONFIG           Override config file path (default: wiggum.config.json)"
    exit 1
    ;;
esac
