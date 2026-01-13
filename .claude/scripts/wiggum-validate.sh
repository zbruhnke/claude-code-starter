#!/usr/bin/env bash
#
# Wiggum Validation Script
# Checks that wiggum actually did what it claims
#
# Usage: .claude/scripts/wiggum-validate.sh [--since <commit>]
#
# This script validates:
# - Git commits were made during the session
# - CHANGELOG.md has [Unreleased] entries
# - Test command passes
# - Lint command passes
# - Build command passes (if defined)
#
# Exit codes:
#   0 = All checks passed
#   1 = One or more checks failed
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

# Parse arguments
SINCE_COMMIT=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --since)
      SINCE_COMMIT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  WIGGUM VALIDATION - Checking Reality${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Helper functions
pass() {
  echo -e "  ${GREEN}✓ PASS${NC}: $1"
  ((PASSED++))
}

fail() {
  echo -e "  ${RED}✗ FAIL${NC}: $1"
  ((FAILED++))
}

warn() {
  echo -e "  ${YELLOW}! WARN${NC}: $1"
  ((WARNINGS++))
}

info() {
  echo -e "  → $1"
}

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 1: Git commits
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}Git Commits${NC}"

if [ -n "$SINCE_COMMIT" ]; then
  COMMIT_COUNT=$(git rev-list --count "$SINCE_COMMIT"..HEAD 2>/dev/null || echo "0")
  if [ "$COMMIT_COUNT" -gt 0 ]; then
    pass "Found $COMMIT_COUNT commit(s) since $SINCE_COMMIT"
    echo ""
    git log --oneline "$SINCE_COMMIT"..HEAD | head -10 | while read -r line; do
      info "$line"
    done
  else
    fail "No commits found since $SINCE_COMMIT"
  fi
else
  # Check for any commits today with Co-Authored-By: Claude
  TODAY=$(date +%Y-%m-%d)
  CLAUDE_COMMITS=$(git log --since="$TODAY 00:00" --grep="Co-Authored-By: Claude" --oneline 2>/dev/null | wc -l | tr -d ' ')
  if [ "$CLAUDE_COMMITS" -gt 0 ]; then
    pass "Found $CLAUDE_COMMITS Claude commit(s) today"
    echo ""
    git log --since="$TODAY 00:00" --grep="Co-Authored-By: Claude" --oneline | head -10 | while read -r line; do
      info "$line"
    done
  else
    warn "No Claude commits found today (use --since <commit> for precise check)"
  fi
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 2: CHANGELOG.md
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}CHANGELOG.md${NC}"

if [ -f "CHANGELOG.md" ]; then
  # Check for [Unreleased] section with content
  if grep -q "## \[Unreleased\]" CHANGELOG.md; then
    # Check if there's content between [Unreleased] and the next ## heading
    UNRELEASED_CONTENT=$(awk '/## \[Unreleased\]/,/## \[[0-9]/' CHANGELOG.md | grep -E "^- |^### " | head -5)
    if [ -n "$UNRELEASED_CONTENT" ]; then
      pass "CHANGELOG.md has [Unreleased] entries"
      echo "$UNRELEASED_CONTENT" | while read -r line; do
        info "$line"
      done
    else
      fail "CHANGELOG.md [Unreleased] section is empty"
    fi
  else
    fail "CHANGELOG.md missing [Unreleased] section"
  fi
else
  fail "CHANGELOG.md not found"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 3: Parse CLAUDE.md for commands
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}Command Discovery (from CLAUDE.md)${NC}"

TEST_CMD=""
LINT_CMD=""
BUILD_CMD=""
TYPECHECK_CMD=""

if [ -f "CLAUDE.md" ]; then
  # Try to find commands in CLAUDE.md
  # Look for patterns like "npm test", "pytest", "go test", etc.

  # Test command
  TEST_CMD=$(grep -E "^\s*(npm test|yarn test|pnpm test|pytest|go test|cargo test|mix test|rspec|bundle exec rspec)" CLAUDE.md 2>/dev/null | head -1 | xargs || true)
  if [ -z "$TEST_CMD" ]; then
    TEST_CMD=$(grep -iE "(test|spec).*:" CLAUDE.md 2>/dev/null | grep -oE "(npm|yarn|pnpm) (run )?test[a-z]*|pytest|go test|cargo test|mix test|rspec" | head -1 || true)
  fi

  # Lint command
  LINT_CMD=$(grep -E "^\s*(npm run lint|yarn lint|pnpm lint|ruff|pylint|golangci-lint|cargo clippy|mix credo)" CLAUDE.md 2>/dev/null | head -1 | xargs || true)
  if [ -z "$LINT_CMD" ]; then
    LINT_CMD=$(grep -iE "lint.*:" CLAUDE.md 2>/dev/null | grep -oE "(npm|yarn|pnpm) (run )?lint[a-z]*|ruff|pylint|eslint|golangci-lint|cargo clippy|mix credo" | head -1 || true)
  fi

  # Build command
  BUILD_CMD=$(grep -E "^\s*(npm run build|yarn build|pnpm build|go build|cargo build|mix compile)" CLAUDE.md 2>/dev/null | head -1 | xargs || true)
  if [ -z "$BUILD_CMD" ]; then
    BUILD_CMD=$(grep -iE "build.*:" CLAUDE.md 2>/dev/null | grep -oE "(npm|yarn|pnpm) (run )?build[a-z]*|go build|cargo build|mix compile" | head -1 || true)
  fi

  # Typecheck command
  TYPECHECK_CMD=$(grep -E "^\s*(tsc|npx tsc|mypy|pyright)" CLAUDE.md 2>/dev/null | head -1 | xargs || true)
  if [ -z "$TYPECHECK_CMD" ]; then
    TYPECHECK_CMD=$(grep -iE "typecheck.*:|type.*:" CLAUDE.md 2>/dev/null | grep -oE "tsc|npx tsc|mypy|pyright" | head -1 || true)
  fi

  [ -n "$TEST_CMD" ] && info "TEST: $TEST_CMD" || warn "TEST: not found in CLAUDE.md"
  [ -n "$LINT_CMD" ] && info "LINT: $LINT_CMD" || warn "LINT: not found in CLAUDE.md"
  [ -n "$BUILD_CMD" ] && info "BUILD: $BUILD_CMD" || info "BUILD: not found (may be N/A)"
  [ -n "$TYPECHECK_CMD" ] && info "TYPECHECK: $TYPECHECK_CMD" || info "TYPECHECK: not found (may be N/A)"
else
  fail "CLAUDE.md not found - cannot discover commands"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 4: Run commands
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}Command Gates${NC}"

run_gate() {
  local name="$1"
  local cmd="$2"

  if [ -z "$cmd" ]; then
    info "$name: skipped (no command)"
    return
  fi

  echo -e "  Running: ${BOLD}$cmd${NC}"
  if eval "$cmd" > /tmp/wiggum-gate-output.txt 2>&1; then
    pass "$name passed"
    # Show abbreviated output
    tail -3 /tmp/wiggum-gate-output.txt | while read -r line; do
      info "$line"
    done
  else
    fail "$name failed"
    tail -10 /tmp/wiggum-gate-output.txt | while read -r line; do
      info "$line"
    done
  fi
  echo ""
}

run_gate "TEST" "$TEST_CMD"
run_gate "LINT" "$LINT_CMD"
run_gate "BUILD" "$BUILD_CMD"
run_gate "TYPECHECK" "$TYPECHECK_CMD"

# ─────────────────────────────────────────────────────────────────────────────
# CHECK 5: Documentation
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}Documentation${NC}"

if [ -f "README.md" ]; then
  # Check if README was modified recently (within last hour)
  README_MOD=$(stat -f %m README.md 2>/dev/null || stat -c %Y README.md 2>/dev/null || echo "0")
  NOW=$(date +%s)
  DIFF=$((NOW - README_MOD))
  if [ $DIFF -lt 3600 ]; then
    pass "README.md modified in last hour"
  else
    info "README.md not recently modified (may be OK if no new features)"
  fi
else
  warn "README.md not found"
fi

# Check for inline docs (comments) - just a heuristic
if [ -d "src" ]; then
  DOC_COMMENTS=$(grep -r "^\s*/\*\*\|^\s*///" src/ 2>/dev/null | wc -l | tr -d ' ')
  info "Found ~$DOC_COMMENTS doc comments in src/"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  SUMMARY${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}Passed${NC}: $PASSED"
echo -e "  ${RED}Failed${NC}: $FAILED"
echo -e "  ${YELLOW}Warnings${NC}: $WARNINGS"
echo ""

if [ $FAILED -gt 0 ]; then
  echo -e "  ${RED}${BOLD}VALIDATION FAILED${NC}"
  echo -e "  Wiggum cannot claim COMPLETE until all checks pass."
  echo ""
  exit 1
else
  echo -e "  ${GREEN}${BOLD}VALIDATION PASSED${NC}"
  echo -e "  Evidence collected. Wiggum may proceed to completion."
  echo ""
  exit 0
fi
