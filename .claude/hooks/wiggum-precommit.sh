#!/usr/bin/env bash
#
# Wiggum Pre-Commit Hook
# Blocks commits if validation checks fail
#
# Install: cp .claude/hooks/wiggum-precommit.sh .git/hooks/pre-commit
#
# This hook enforces:
# - CHANGELOG.md has [Unreleased] entries (if code files changed)
# - Tests pass
# - Lint passes
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# CHECK: Is this a wiggum session?
# ─────────────────────────────────────────────────────────────────────────────
# Only enforce if .wiggum-session file exists (created by wiggum at start)
if [ ! -f ".wiggum-session" ]; then
  # Not a wiggum session - allow normal commits through
  exit 0
fi

echo -e "${YELLOW}Wiggum session active - enforcing quality gates${NC}"
echo ""

# Get staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

# Skip if no files staged
if [ -z "$STAGED_FILES" ]; then
  exit 0
fi

# Check if any code files are being committed (not just docs/config)
CODE_FILES=$(echo "$STAGED_FILES" | grep -E '\.(ts|js|tsx|jsx|py|go|rs|rb|ex|exs)$' || true)

# If only docs/config, allow through
if [ -z "$CODE_FILES" ]; then
  exit 0
fi

echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  WIGGUM PRE-COMMIT ENFORCEMENT${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

FAILED=0

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 1: CHANGELOG.md
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}Checking CHANGELOG.md...${NC}"

if [ -f "CHANGELOG.md" ]; then
  # Check if CHANGELOG is staged OR has unreleased content
  CHANGELOG_STAGED=$(echo "$STAGED_FILES" | grep -E "^CHANGELOG.md$" || true)

  if [ -n "$CHANGELOG_STAGED" ]; then
    echo -e "  ${GREEN}✓${NC} CHANGELOG.md is staged"
  else
    # Check if [Unreleased] has content
    UNRELEASED=$(awk '/## \[Unreleased\]/,/## \[[0-9]/' CHANGELOG.md | grep -E "^- " | head -1 || true)
    if [ -n "$UNRELEASED" ]; then
      echo -e "  ${GREEN}✓${NC} CHANGELOG.md has [Unreleased] entries"
    else
      echo -e "  ${RED}✗${NC} CHANGELOG.md [Unreleased] section is empty"
      echo -e "  ${YELLOW}→${NC} Add changelog entries before committing code changes"
      FAILED=1
    fi
  fi
else
  echo -e "  ${RED}✗${NC} CHANGELOG.md not found"
  FAILED=1
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 2: Tests (if test command can be discovered)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}Running tests...${NC}"

TEST_CMD=""
if [ -f "package.json" ]; then
  TEST_CMD="npm test"
elif [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
  TEST_CMD="pytest"
elif [ -f "go.mod" ]; then
  TEST_CMD="go test ./..."
elif [ -f "Cargo.toml" ]; then
  TEST_CMD="cargo test"
elif [ -f "mix.exs" ]; then
  TEST_CMD="mix test"
elif [ -f "Gemfile" ]; then
  TEST_CMD="bundle exec rspec"
fi

if [ -n "$TEST_CMD" ]; then
  echo -e "  Running: $TEST_CMD"
  if $TEST_CMD > /tmp/wiggum-test-output.txt 2>&1; then
    echo -e "  ${GREEN}✓${NC} Tests passed"
  else
    echo -e "  ${RED}✗${NC} Tests failed"
    echo ""
    tail -20 /tmp/wiggum-test-output.txt
    FAILED=1
  fi
else
  echo -e "  ${YELLOW}!${NC} No test command detected (skipping)"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 3: Lint (if lint command can be discovered)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}Running lint...${NC}"

LINT_CMD=""
if [ -f "package.json" ] && grep -q '"lint"' package.json; then
  LINT_CMD="npm run lint"
elif [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
  if command -v ruff &> /dev/null; then
    LINT_CMD="ruff check ."
  fi
elif [ -f "go.mod" ]; then
  if command -v golangci-lint &> /dev/null; then
    LINT_CMD="golangci-lint run"
  fi
elif [ -f "Cargo.toml" ]; then
  LINT_CMD="cargo clippy"
fi

if [ -n "$LINT_CMD" ]; then
  echo -e "  Running: $LINT_CMD"
  if $LINT_CMD > /tmp/wiggum-lint-output.txt 2>&1; then
    echo -e "  ${GREEN}✓${NC} Lint passed"
  else
    echo -e "  ${RED}✗${NC} Lint failed"
    echo ""
    tail -20 /tmp/wiggum-lint-output.txt
    FAILED=1
  fi
else
  echo -e "  ${YELLOW}!${NC} No lint command detected (skipping)"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# RESULT
# ─────────────────────────────────────────────────────────────────────────────
if [ $FAILED -gt 0 ]; then
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "  ${RED}${BOLD}COMMIT BLOCKED${NC}"
  echo -e "  Fix the issues above before committing."
  echo ""
  echo -e "  To bypass (emergency only): ${YELLOW}git commit --no-verify${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  exit 1
fi

echo -e "${GREEN}${BOLD}All checks passed. Commit allowed.${NC}"
exit 0
