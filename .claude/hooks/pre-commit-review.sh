#!/bin/bash
#
# Pre-Commit Review Hook
# Forces developers to understand what they're committing
#
# Install as git hook:
#   cp .claude/hooks/pre-commit-review.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit
#
# Or symlink:
#   ln -sf ../../.claude/hooks/pre-commit-review.sh .git/hooks/pre-commit
#

set -euo pipefail

# Colors (disable if not a terminal)
if [ -t 1 ]; then
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

# Track if we can do interactive prompts
INTERACTIVE=true
if [ ! -t 0 ]; then
  INTERACTIVE=false
fi

# Skip entirely if SKIP_PRE_COMMIT_REVIEW is set
if [ -n "${SKIP_PRE_COMMIT_REVIEW:-}" ]; then
  exit 0
fi

# Get staged changes info
STAGED_FILES=$(git diff --cached --name-only)
FILE_COUNT=$(echo "$STAGED_FILES" | grep -c . || echo "0")

if [ "$FILE_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}No staged files. Nothing to commit.${NC}"
  exit 1
fi

STATS=$(git diff --cached --stat | tail -1)
ADDED=$(git diff --cached --numstat | awk '{sum += $1} END {print sum+0}')
REMOVED=$(git diff --cached --numstat | awk '{sum += $2} END {print sum+0}')

# Get the file types being changed
FILE_TYPES=$(echo "$STAGED_FILES" | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -5)

# Check for potentially sensitive files (single grep instead of loop)
SENSITIVE_FILES=$(echo "$STAGED_FILES" | grep -iE '\.env|secret|credential|password|\.pem$|\.key$' || true)

# Check for new dependencies
NEW_DEPS=""
if echo "$STAGED_FILES" | grep -q "package.json"; then
  NEW_DEPS=$(git diff --cached package.json | grep "^\+" | grep -E '"[^"]+":' | head -10 || true)
fi
if echo "$STAGED_FILES" | grep -q "requirements.txt"; then
  NEW_DEPS="$NEW_DEPS"$(git diff --cached requirements.txt | grep "^\+" | head -10 || true)
fi
if echo "$STAGED_FILES" | grep -q "Gemfile"; then
  NEW_DEPS="$NEW_DEPS"$(git diff --cached Gemfile | grep "^\+" | grep "gem " | head -10 || true)
fi
if echo "$STAGED_FILES" | grep -q "mix.exs"; then
  NEW_DEPS="$NEW_DEPS"$(git diff --cached mix.exs | grep "^\+" | grep -E "{:" | head -10 || true)
fi

# Check for TODO/FIXME comments being added
TODOS=$(git diff --cached | grep "^\+" | grep -iE "(TODO|FIXME|XXX|HACK):" | head -5 || true)

# Check for console.log, print, debugger statements
DEBUG_STATEMENTS=$(git diff --cached | grep "^\+" | grep -E "(console\.(log|debug)|print\(|debugger|IEx\.pry|binding\.pry|puts |p\()" | head -5 || true)

# Print review header
echo ""
echo -e "${BLUE}┌─────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│${NC}  ${BOLD}PRE-COMMIT REVIEW${NC}                                              ${BLUE}│${NC}"
echo -e "${BLUE}├─────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC}  Files: ${BOLD}$FILE_COUNT${NC}   Lines: ${GREEN}+$ADDED${NC} / ${RED}-$REMOVED${NC}                         ${BLUE}│${NC}"
echo -e "${BLUE}└─────────────────────────────────────────────────────────────────┘${NC}"
echo ""

# Show file list
echo -e "${BOLD}Files to be committed:${NC}"
echo "$STAGED_FILES" | while read -r file; do
  if [ -n "$file" ]; then
    STATUS=$(git diff --cached --name-status "$file" 2>/dev/null | cut -f1)
    case $STATUS in
      A) echo -e "  ${GREEN}+ $file${NC} (new)" ;;
      M) echo -e "  ${YELLOW}~ $file${NC} (modified)" ;;
      D) echo -e "  ${RED}- $file${NC} (deleted)" ;;
      R*) echo -e "  ${BLUE}→ $file${NC} (renamed)" ;;
      *) echo -e "  ${DIM}  $file${NC}" ;;
    esac
  fi
done
echo ""

# Warnings section
HAS_WARNINGS=false

if [ -n "$SENSITIVE_FILES" ]; then
  HAS_WARNINGS=true
  echo -e "${RED}${BOLD}⚠ SENSITIVE FILES DETECTED:${NC}"
  echo "$SENSITIVE_FILES" | while read -r file; do
    [ -n "$file" ] && echo -e "  ${RED}• $file${NC}"
  done
  echo ""
fi

if [ -n "$DEBUG_STATEMENTS" ]; then
  HAS_WARNINGS=true
  echo -e "${YELLOW}${BOLD}⚠ DEBUG STATEMENTS FOUND:${NC}"
  echo "$DEBUG_STATEMENTS" | head -5 | while read -r line; do
    [ -n "$line" ] && echo -e "  ${YELLOW}$line${NC}"
  done
  echo ""
fi

if [ -n "$TODOS" ]; then
  echo -e "${DIM}${BOLD}📝 TODOs added:${NC}"
  echo "$TODOS" | while read -r line; do
    [ -n "$line" ] && echo -e "  ${DIM}$line${NC}"
  done
  echo ""
fi

if [ -n "$NEW_DEPS" ]; then
  echo -e "${BLUE}${BOLD}📦 New dependencies:${NC}"
  echo "$NEW_DEPS" | while read -r line; do
    [ -n "$line" ] && echo -e "  ${BLUE}$line${NC}"
  done
  echo ""
fi

# Quick diff summary (just the functions/classes changed)
echo -e "${BOLD}Changes overview:${NC}"
git diff --cached --stat | head -20
echo ""

# Confirmation section
echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
if [ "$HAS_WARNINGS" = true ]; then
  echo -e "${YELLOW}${BOLD}There are warnings above. Please review carefully.${NC}"
fi
echo ""

# Non-interactive mode: pass silently
# In Claude Code, the AI should explain changes in conversation instead
if [ "$INTERACTIVE" = false ]; then
  exit 0
fi

# Interactive mode: require explicit confirmation
echo -e "${BOLD}Do you understand these changes and want to commit?${NC}"
echo -e "${DIM}(y)es to commit, (n)o to abort, (d)iff to see full diff, (q)uit${NC}"
echo ""

# Handle Ctrl+C gracefully
trap 'echo ""; echo -e "${RED}✗ Commit aborted (interrupted)${NC}"; exit 1' INT

MAX_ATTEMPTS=10
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))

  # Read with 60 second timeout
  if ! read -r -t 60 -p "Your choice [y/n/d/q]: " choice; then
    echo ""
    echo -e "${RED}✗ Commit aborted (timeout)${NC}"
    exit 1
  fi

  case $choice in
    [Yy]|[Yy][Ee][Ss])
      echo ""
      echo -e "${GREEN}✓ Proceeding with commit${NC}"
      exit 0
      ;;
    [Nn]|[Nn][Oo]|[Qq]|[Qq][Uu][Ii][Tt])
      echo ""
      echo -e "${RED}✗ Commit aborted${NC}"
      echo -e "${DIM}Use 'git reset HEAD' to unstage files${NC}"
      exit 1
      ;;
    [Dd]|[Dd][Ii][Ff][Ff])
      echo ""
      git diff --cached | less || true
      echo ""
      echo -e "${BOLD}Do you want to commit? [y/n/d/q]:${NC}"
      ;;
    "")
      # Empty input - remind user
      echo -e "${DIM}Please enter y, n, d, or q${NC}"
      ;;
    *)
      echo "Please answer y(es), n(o), d(iff), or q(uit)"
      ;;
  esac
done

# Too many attempts
echo ""
echo -e "${RED}✗ Commit aborted (too many invalid inputs)${NC}"
exit 1
