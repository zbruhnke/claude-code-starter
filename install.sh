#!/usr/bin/env bash
#
# Claude Code Starter Installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/zbruhnke/claude-code-starter/main/install.sh | bash
#   curl -fsSL ... | bash -s -- --version v0.4.0
#
# Options:
#   --version VERSION   Install specific version (default: latest)
#   --dir PATH          Install to custom directory (default: ~/.claude-code-starter)
#   --no-path           Don't add to PATH
#

set -euo pipefail

# Defaults
INSTALL_DIR="${HOME}/.claude-code-starter"
VERSION=""
ADD_TO_PATH=true
REPO="zbruhnke/claude-code-starter"

# Colors
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  DIM='\033[0;90m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' DIM='' NC=''
fi

error() {
  echo -e "${RED}Error: $1${NC}" >&2
  exit 1
}

info() {
  echo -e "${BLUE}$1${NC}"
}

success() {
  echo -e "${GREEN}$1${NC}"
}

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --dir)
      INSTALL_DIR="$2"
      shift 2
      ;;
    --no-path)
      ADD_TO_PATH=false
      shift
      ;;
    --help|-h)
      echo "Usage: install.sh [--version VERSION] [--dir PATH] [--no-path]"
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      ;;
  esac
done

# Check dependencies
command -v curl >/dev/null 2>&1 || error "curl is required but not installed"
command -v tar >/dev/null 2>&1 || error "tar is required but not installed"

# Get latest version if not specified
if [ -z "$VERSION" ]; then
  info "Fetching latest version..."
  VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
  if [ -z "$VERSION" ]; then
    error "Could not determine latest version. Try specifying --version"
  fi
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Claude Code Starter Installer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Version:  ${GREEN}$VERSION${NC}"
echo -e "  Location: ${DIM}$INSTALL_DIR${NC}"
echo ""

# Check for existing installation
if [ -d "$INSTALL_DIR" ]; then
  existing_version=$(cat "$INSTALL_DIR/VERSION" 2>/dev/null || echo "unknown")
  echo -e "${YELLOW}Existing installation found (${existing_version})${NC}"
  read -p "Replace it? [Y/n] " confirm
  if [[ "$confirm" =~ ^[Nn] ]]; then
    echo "Aborted."
    exit 0
  fi
  rm -rf "$INSTALL_DIR.bak"
  mv "$INSTALL_DIR" "$INSTALL_DIR.bak"
  echo -e "${DIM}  Backed up to ${INSTALL_DIR}.bak${NC}"
fi

# Download and extract
info "Downloading..."
tmp_dir=$(mktemp -d)
trap "rm -rf '$tmp_dir'" EXIT

curl -fsSL "https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz" | tar -xz -C "$tmp_dir"

# Find extracted directory (handle v prefix variations)
extracted_dir=""
for try in "claude-code-starter-${VERSION#v}" "claude-code-starter-${VERSION}"; do
  if [ -d "$tmp_dir/$try" ]; then
    extracted_dir="$tmp_dir/$try"
    break
  fi
done

[ -z "$extracted_dir" ] && error "Could not find extracted directory"

# Install
mv "$extracted_dir" "$INSTALL_DIR"
echo "$VERSION" > "$INSTALL_DIR/VERSION"
chmod +x "$INSTALL_DIR/bin/claude-code-starter"
chmod +x "$INSTALL_DIR/setup.sh"
chmod +x "$INSTALL_DIR/adopt.sh"
chmod +x "$INSTALL_DIR/.claude/hooks/"*.sh 2>/dev/null || true

# Create short alias symlink
ln -sf "$INSTALL_DIR/bin/claude-code-starter" "$INSTALL_DIR/bin/ccs"

success "Installed to $INSTALL_DIR"

# Add to PATH
BIN_PATH="$INSTALL_DIR/bin"
SHELL_CONFIG=""
PATH_ADDED=false

detect_shell_config() {
  case "$(basename "$SHELL")" in
    zsh)  echo "${ZDOTDIR:-$HOME}/.zshrc" ;;
    bash)
      if [ -f "$HOME/.bash_profile" ]; then
        echo "$HOME/.bash_profile"
      else
        echo "$HOME/.bashrc"
      fi
      ;;
    fish) echo "$HOME/.config/fish/config.fish" ;;
    *)    echo "$HOME/.profile" ;;
  esac
}

if [ "$ADD_TO_PATH" = true ]; then
  SHELL_CONFIG=$(detect_shell_config)

  # Check if already in PATH
  if [[ ":$PATH:" == *":$BIN_PATH:"* ]]; then
    echo -e "${DIM}Already in PATH${NC}"
  elif [ -f "$SHELL_CONFIG" ] && grep -q "$BIN_PATH" "$SHELL_CONFIG" 2>/dev/null; then
    echo -e "${DIM}PATH entry already in $SHELL_CONFIG${NC}"
  else
    echo "" >> "$SHELL_CONFIG"
    echo "# Claude Code Starter" >> "$SHELL_CONFIG"
    if [[ "$SHELL_CONFIG" == *"fish"* ]]; then
      echo "set -gx PATH \"$BIN_PATH\" \$PATH" >> "$SHELL_CONFIG"
    else
      echo "export PATH=\"$BIN_PATH:\$PATH\"" >> "$SHELL_CONFIG"
    fi
    PATH_ADDED=true
    success "Added to PATH in $SHELL_CONFIG"
  fi
fi

# Summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$PATH_ADDED" = true ]; then
  echo -e "  ${YELLOW}Restart your shell or run:${NC}"
  echo -e "    source $SHELL_CONFIG"
  echo ""
fi

echo -e "  ${DIM}Get started:${NC}"
echo "    ccs help"
echo "    ccs init"
echo ""
echo -e "  ${DIM}Full command also available:${NC}"
echo "    claude-code-starter"
echo ""
echo -e "  ${DIM}Documentation:${NC}"
echo "    https://github.com/${REPO}"
echo ""
