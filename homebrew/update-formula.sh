#!/usr/bin/env bash
#
# Update the Homebrew formula for a new release
#
# Usage:
#   ./update-formula.sh v0.6.0
#   ./update-formula.sh v0.6.0 --commit  # Also commit the change
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMULA_FILE="$SCRIPT_DIR/Formula/claude-code-starter.rb"
REPO="zbruhnke/claude-code-starter"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

error() { echo -e "${RED}Error: $1${NC}" >&2; exit 1; }
info() { echo -e "${GREEN}$1${NC}"; }
warn() { echo -e "${YELLOW}$1${NC}"; }

# Check arguments
VERSION="${1:-}"
COMMIT="${2:-}"

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version> [--commit]"
  echo "Example: $0 v0.6.0"
  exit 1
fi

# Ensure version starts with 'v'
[[ "$VERSION" != v* ]] && VERSION="v$VERSION"

info "Updating formula to $VERSION..."

# Download and compute SHA256
TMP_FILE=$(mktemp)
trap "rm -f '$TMP_FILE'" EXIT

info "Downloading release tarball..."
curl -fsSL -o "$TMP_FILE" "https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz" || error "Failed to download release"

SHA256=$(shasum -a 256 "$TMP_FILE" | cut -d' ' -f1)
info "SHA256: $SHA256"

# Check formula file exists
[ -f "$FORMULA_FILE" ] || error "Formula file not found: $FORMULA_FILE"

# Update version in URL
OLD_URL=$(grep -E '^\s+url "' "$FORMULA_FILE" | head -1)
NEW_URL="  url \"https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz\""

# Update SHA256
OLD_SHA=$(grep -E '^\s+sha256 "' "$FORMULA_FILE" | head -1)
NEW_SHA="  sha256 \"${SHA256}\""

# Apply changes
sed -i.bak -E "s|url \"https://github.com/${REPO}/archive/refs/tags/v[^\"]+\.tar\.gz\"|url \"https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz\"|" "$FORMULA_FILE"
sed -i.bak -E "s|sha256 \"[a-f0-9]{64}\"|sha256 \"${SHA256}\"|" "$FORMULA_FILE"
rm -f "$FORMULA_FILE.bak"

info "Formula updated!"
echo ""
echo "Changes:"
echo "  URL: .../${VERSION}.tar.gz"
echo "  SHA: ${SHA256}"
echo ""

# Show diff
if command -v git &>/dev/null && [ -d "$SCRIPT_DIR/../.git" ]; then
  warn "Diff:"
  git diff "$FORMULA_FILE" || true
  echo ""
fi

# Optionally commit
if [ "$COMMIT" = "--commit" ]; then
  if command -v git &>/dev/null; then
    git add "$FORMULA_FILE"
    git commit -m "Update formula to $VERSION"
    info "Committed!"
  else
    warn "git not found, skipping commit"
  fi
else
  echo "To commit: git add $FORMULA_FILE && git commit -m 'Update formula to $VERSION'"
fi

info "Done!"
echo ""
echo "Next steps:"
echo "  1. Push to the homebrew-claude-code-starter repo"
echo "  2. Users can update with: brew upgrade claude-code-starter"
