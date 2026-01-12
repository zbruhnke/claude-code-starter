# Homebrew Tap Setup

This directory contains the Homebrew formula for claude-code-starter.

## Setting up the tap repository

1. **Create a new GitHub repository** named `homebrew-claude-code-starter`
   - The `homebrew-` prefix is required for Homebrew taps

2. **Copy the Formula directory** to the new repo:
   ```bash
   cd homebrew-claude-code-starter
   cp -r /path/to/claude-code-starter/homebrew/Formula .
   git add Formula/
   git commit -m "Add claude-code-starter formula"
   git push
   ```

3. **Test the tap locally:**
   ```bash
   brew tap zbruhnke/claude-code-starter
   brew install claude-code-starter
   ```

## Updating the formula for new releases

When you release a new version:

1. Get the SHA256 of the new release:
   ```bash
   curl -fsSL -o /tmp/release.tar.gz https://github.com/zbruhnke/claude-code-starter/archive/refs/tags/vX.Y.Z.tar.gz
   shasum -a 256 /tmp/release.tar.gz
   ```

2. Update `Formula/claude-code-starter.rb`:
   - Change `url` to the new version
   - Update `sha256` with the new checksum

3. Commit and push to the tap repo:
   ```bash
   git commit -am "Update to vX.Y.Z"
   git push
   ```

4. Users can then update with:
   ```bash
   brew upgrade claude-code-starter
   ```

## Automated updates

You can use the `update-formula.sh` script to automate this:

```bash
./update-formula.sh v0.6.0
```

This will:
- Download the release and compute SHA256
- Update the formula file
- Show a diff for review

## Formula structure

```
homebrew-claude-code-starter/
└── Formula/
    └── claude-code-starter.rb
```

## Testing changes

Before pushing formula changes:

```bash
# Audit the formula
brew audit --strict Formula/claude-code-starter.rb

# Test installation
brew install --build-from-source Formula/claude-code-starter.rb

# Run tests
brew test claude-code-starter
```
