#!/usr/bin/env bash
#
# Generate checksums.txt for a release
#
# Usage:
#   ./scripts/generate-checksums.sh v0.7.0
#
# This downloads the release tarball from GitHub and generates checksums.
# The output file should be uploaded as a release asset.
#

set -euo pipefail

VERSION="${1:-}"
REPO="zbruhnke/claude-code-starter"

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 v0.7.0"
  exit 1
fi

# Ensure version starts with 'v'
[[ "$VERSION" != v* ]] && VERSION="v$VERSION"

echo "Generating checksums for $VERSION..."

# Create temp directory
tmp_dir=$(mktemp -d)
trap "rm -rf '$tmp_dir'" EXIT

# Download the release tarball
TARBALL_URL="https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz"
TARBALL="$tmp_dir/release.tar.gz"

echo "Downloading tarball..."
curl -fsSL -o "$TARBALL" "$TARBALL_URL" || {
  echo "Error: Failed to download $TARBALL_URL"
  echo "Make sure the tag exists: git tag -l '$VERSION'"
  exit 1
}

# Generate checksums
OUTPUT_FILE="checksums.txt"

echo "Calculating checksums..."
if command -v shasum &>/dev/null; then
  SHA256=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
elif command -v sha256sum &>/dev/null; then
  SHA256=$(sha256sum "$TARBALL" | awk '{print $1}')
else
  echo "Error: Neither shasum nor sha256sum found"
  exit 1
fi

# Write checksums file
cat > "$OUTPUT_FILE" << EOF
# SHA256 checksums for claude-code-starter $VERSION
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
#
# Verify with:
#   shasum -a 256 -c checksums.txt      (macOS)
#   sha256sum -c checksums.txt          (Linux)

$SHA256  release.tar.gz
$SHA256  ${VERSION}.tar.gz
EOF

echo ""
echo "Created: $OUTPUT_FILE"
echo ""
cat "$OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "  1. Create the GitHub release for $VERSION"
echo "  2. Upload checksums.txt as a release asset:"
echo "     gh release upload $VERSION checksums.txt"
echo ""
