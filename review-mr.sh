#!/bin/bash
#
# Standalone MR/PR Review Tool
# Uses Claude to review a branch against base and output structured feedback
#
# Usage:
#   ./review-mr.sh                     # Review current branch vs main
#   ./review-mr.sh feature-branch      # Review specific branch vs main
#   ./review-mr.sh feature-branch dev  # Review branch vs custom base
#   ./review-mr.sh --pr 123            # Review GitHub PR by number
#
# Output formats (--format):
#   terminal  - Colored terminal output (default)
#   markdown  - Clean markdown for PR comments
#   json      - Structured JSON for tooling
#
# Environment variables:
#   ANTHROPIC_API_KEY  - Required for Claude API access
#   GITHUB_TOKEN       - Required for --pr option
#

set -euo pipefail

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities if available
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
  source "$SCRIPT_DIR/lib/common.sh"
else
  # Fallback: define colors inline (for standalone use)
  if [ -t 1 ] && [ -z "${FORMAT:-}" ]; then
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
fi

# Defaults
FORMAT="terminal"
BASE_BRANCH=""
TARGET_BRANCH=""
PR_NUMBER=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --pr)
      PR_NUMBER="$2"
      shift 2
      ;;
    --base)
      BASE_BRANCH="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: review-mr.sh [branch] [base] [options]"
      echo ""
      echo "Arguments:"
      echo "  branch          Branch to review (default: current branch)"
      echo "  base            Base branch to compare against (default: main or master)"
      echo ""
      echo "Options:"
      echo "  --pr NUMBER     Review GitHub PR by number"
      echo "  --base BRANCH   Specify base branch"
      echo "  --format TYPE   Output format: terminal, markdown, json"
      echo "  -h, --help      Show this help"
      echo ""
      echo "Examples:"
      echo "  ./review-mr.sh                          # Current branch vs main"
      echo "  ./review-mr.sh feature-auth             # feature-auth vs main"
      echo "  ./review-mr.sh feature-auth develop     # feature-auth vs develop"
      echo "  ./review-mr.sh --pr 123                 # GitHub PR #123"
      echo "  ./review-mr.sh --format markdown        # Output as markdown"
      exit 0
      ;;
    *)
      if [ -z "$TARGET_BRANCH" ]; then
        TARGET_BRANCH="$1"
      elif [ -z "$BASE_BRANCH" ]; then
        BASE_BRANCH="$1"
      fi
      shift
      ;;
  esac
done

# Detect base branch if not specified
if [ -z "$BASE_BRANCH" ]; then
  # Use common.sh function if available, otherwise inline fallback
  if type get_default_branch &>/dev/null; then
    BASE_BRANCH=$(get_default_branch) || {
      echo "Error: Could not detect base branch." >&2
      echo "Specify with --base <branch>" >&2
      exit 1
    }
  else
    # Inline fallback for standalone use
    DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [ -n "$DEFAULT_BRANCH" ] && git rev-parse --verify "$DEFAULT_BRANCH" &>/dev/null; then
      BASE_BRANCH="$DEFAULT_BRANCH"
    else
      for branch in main master develop trunk; do
        if git rev-parse --verify "$branch" &>/dev/null; then
          BASE_BRANCH="$branch"
          break
        fi
      done
    fi
    if [ -z "$BASE_BRANCH" ]; then
      echo "Error: Could not detect base branch." >&2
      echo "Specify with --base <branch>" >&2
      exit 1
    fi
  fi
fi

# Get target branch if not specified
if [ -z "$TARGET_BRANCH" ]; then
  # Use common.sh function if available, otherwise inline fallback
  if type get_current_branch &>/dev/null; then
    TARGET_BRANCH=$(get_current_branch) || {
      echo "Error: Cannot determine current branch (detached HEAD?)" >&2
      echo "Please checkout a branch or specify with: ./review-mr.sh <branch>" >&2
      exit 1
    }
  else
    # Inline fallback for standalone use
    TARGET_BRANCH=$(git branch --show-current 2>/dev/null)
    if [ -z "$TARGET_BRANCH" ]; then
      TARGET_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    fi
    if [ -z "$TARGET_BRANCH" ] || [ "$TARGET_BRANCH" = "HEAD" ]; then
      echo "Error: Cannot determine current branch (detached HEAD?)" >&2
      echo "Please checkout a branch or specify with: ./review-mr.sh <branch>" >&2
      exit 1
    fi
  fi
fi

# Validate branches exist
if ! git rev-parse --verify "$BASE_BRANCH" &>/dev/null; then
  echo "Error: Base branch '$BASE_BRANCH' not found" >&2
  exit 1
fi

if ! git rev-parse --verify "$TARGET_BRANCH" &>/dev/null; then
  echo "Error: Target branch '$TARGET_BRANCH' not found" >&2
  exit 1
fi

# Handle PR number
if [ -n "$PR_NUMBER" ]; then
  if ! command -v gh &>/dev/null; then
    echo "Error: GitHub CLI (gh) required for --pr option" >&2
    exit 1
  fi
  TARGET_BRANCH=$(gh pr view "$PR_NUMBER" --json headRefName -q '.headRefName')
  BASE_BRANCH=$(gh pr view "$PR_NUMBER" --json baseRefName -q '.baseRefName')
fi

# Get diff stats
DIFF_STATS=$(git diff "$BASE_BRANCH"..."$TARGET_BRANCH" --stat 2>/dev/null || git diff "$BASE_BRANCH".."$TARGET_BRANCH" --stat)
FILES_CHANGED=$(git diff "$BASE_BRANCH"..."$TARGET_BRANCH" --name-only 2>/dev/null | wc -l | tr -d ' ')
ADDITIONS=$(git diff "$BASE_BRANCH"..."$TARGET_BRANCH" --numstat 2>/dev/null | awk '{sum += $1} END {print sum+0}')
DELETIONS=$(git diff "$BASE_BRANCH"..."$TARGET_BRANCH" --numstat 2>/dev/null | awk '{sum += $2} END {print sum+0}')

# Get commit messages
COMMITS=$(git log "$BASE_BRANCH".."$TARGET_BRANCH" --oneline 2>/dev/null || echo "Unable to get commits")

# Get the diff
DIFF=$(git diff "$BASE_BRANCH"..."$TARGET_BRANCH" 2>/dev/null || git diff "$BASE_BRANCH".."$TARGET_BRANCH")

# Build the review prompt
REVIEW_PROMPT="You are reviewing a merge request.

Branch: $TARGET_BRANCH → $BASE_BRANCH
Files changed: $FILES_CHANGED
Lines: +$ADDITIONS / -$DELETIONS

Commits:
$COMMITS

Provide a structured review with:

## Summary
Brief overview of what this MR does (2-3 sentences)

## Need to Know
Critical items reviewers must understand:
- Breaking changes
- New dependencies
- Environment variables needed
- Security implications
- Database migrations

## The Good
What's done well (be specific)

## Concerns

### Critical (must fix)
Issues that block merging

### Important (should fix)
Issues that should be addressed

### Minor (nice to have)
Suggestions for improvement

## Questions
Things that need clarification from the author

## Verdict
- [ ] Ready to merge
- [ ] Needs changes
- [ ] Needs discussion

Here's the diff:

\`\`\`diff
$DIFF
\`\`\`"

# Check for Claude CLI
if command -v claude &>/dev/null; then
  # Use Claude CLI
  REVIEW=$(echo "$REVIEW_PROMPT" | claude --print 2>/dev/null || echo "Error running Claude CLI")
else
  # Fallback: just output the stats and prompt
  echo -e "${YELLOW}Note: Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code${NC}"
  echo ""
  echo "To get an AI review, install Claude CLI or copy the diff below to Claude manually."
  echo ""
  echo -e "${BOLD}Review Context:${NC}"
  echo "Branch: $TARGET_BRANCH → $BASE_BRANCH"
  echo "Files: $FILES_CHANGED | +$ADDITIONS / -$DELETIONS"
  echo ""
  echo -e "${BOLD}Commits:${NC}"
  echo "$COMMITS"
  echo ""
  echo -e "${BOLD}Files Changed:${NC}"
  git diff "$BASE_BRANCH"..."$TARGET_BRANCH" --name-only 2>/dev/null
  echo ""
  echo -e "${BOLD}Diff Stats:${NC}"
  echo "$DIFF_STATS"
  exit 0
fi

# Output based on format
case $FORMAT in
  markdown)
    echo "# MR Review: $TARGET_BRANCH"
    echo ""
    echo "**Branch:** \`$TARGET_BRANCH\` → \`$BASE_BRANCH\`"
    echo "**Changes:** $FILES_CHANGED files, +$ADDITIONS/-$DELETIONS lines"
    echo ""
    echo "$REVIEW"
    echo ""
    echo "---"
    echo "*Generated by [claude-code-starter](https://github.com/zbruhnke/claude-code-starter)*"
    ;;

  json)
    # Properly escaped JSON output using jq
    if command -v jq &>/dev/null; then
      jq -n \
        --arg branch "$TARGET_BRANCH" \
        --arg base "$BASE_BRANCH" \
        --argjson files "${FILES_CHANGED:-0}" \
        --argjson additions "${ADDITIONS:-0}" \
        --argjson deletions "${DELETIONS:-0}" \
        --arg review "$REVIEW" \
        '{branch: $branch, base: $base, files_changed: $files, additions: $additions, deletions: $deletions, review: $review}'
    else
      echo "Error: jq is required for JSON output format" >&2
      exit 1
    fi
    ;;

  terminal|*)
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  MR Review: ${BOLD}$TARGET_BRANCH${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${DIM}$TARGET_BRANCH → $BASE_BRANCH${NC}"
    echo -e "${DIM}$FILES_CHANGED files | ${GREEN}+$ADDITIONS${NC} / ${RED}-$DELETIONS${NC}"
    echo ""
    echo "$REVIEW"
    echo ""
    ;;
esac
