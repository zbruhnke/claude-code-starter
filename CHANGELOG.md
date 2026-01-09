# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Incomplete rollback tracking: setup.sh now removes entire .claude/ directory on failure if it didn't exist before
- Bash 4 error message now shows `$(brew --prefix)` instead of hardcoded `/opt/homebrew`
- adopt.sh security merge guidance now matches actual deny patterns shipped in settings.json
- setup.sh security summary no longer overclaims "keys, secrets" blocking (only .env files are blocked by default)
- validate-bash.sh: rm detection now handles flag permutations (`-fr`, `-r -f`, `--recursive`)
- validate-bash.sh: rm detection now blocks `.`, `..`, `/*` targets
- validate-bash.sh: rm detection now catches `sudo rm`, `command rm`, `\rm` bypass attempts
- validate-bash.sh: dd detection no longer requires `if=` (blocks any `of=/dev/`)
- validate-bash.sh: mkfs/fdisk/parted detection is now case-insensitive
- validate-bash.sh: chmod detection now correctly uses `-R` (was incorrectly `-r`)
- validate-bash.sh: fixed regex character class issues in target detection
- validate-bash.sh: force flag warning now only triggers for rm/mv/cp/git-push (reduces noise)

### Changed
- .claudeignore now appends missing recommended patterns instead of skipping when file exists
- validate-bash.sh uses LC_ALL=C and 8k input cap for grep safety
- Test harness uses `jq -cn` for safe JSON construction (handles quotes/backslashes)

### Added
- Regression test suite for validate-bash.sh hook (41 test cases)
- validate-bash.sh tests run in CI on both Ubuntu and macOS

## [0.2.1] - 2025-01-09

### Fixed
- BSD `cp -r` compatibility for adopt.sh on macOS (trailing slash behavior difference)
- Exit code capture in CI using `set +e`/`set -e` instead of fragile pipeline `||`
- Added `apt-get update` before `apt-get install` in CI
- Dynamic Homebrew prefix detection (works on both Intel and ARM Macs)
- More robust previous tag detection in release workflow

### Added
- Smoke test for setup.sh in release validation job
- macOS `shasum -a 256` command in release checksum instructions

## [0.2.0] - 2025-01-09

### Added
- CODE_OF_CONDUCT.md (simplified Contributor Covenant)
- CONTRIBUTING.md (expanded from README section)
- CHANGELOG.md
- SUPPORT.md with troubleshooting and help guidance
- Compatibility matrix in README (OS, Bash, jq, Claude Code versions)
- CI matrix testing on both Ubuntu and macOS
- CI idempotency test (run setup.sh twice)
- CI adopt.sh smoke test
- SHA256 checksums in release notes for script verification
- Checksum verification instructions in README
- Note clarifying `rm -rf` in Uninstall section is for humans
- Signed tag documentation in CONTRIBUTING.md

### Changed
- Improved 5 Minute Tour to be fully copy-paste runnable
- Simplified README Contributing section (details moved to CONTRIBUTING.md)
- Added Community section to README with links to Code of Conduct and Changelog

## [0.1.2] - 2025-01-09

### Fixed
- Release workflow now correctly marks only `-alpha`, `-beta`, `-rc` suffixed versions as pre-release
- `v0.x.y` releases are now marked as latest (not pre-release)

## [0.1.1] - 2025-01-09

### Added
- Automated release workflow via GitHub Actions
- Release notes auto-generated from commit history

## [0.1.0] - 2025-01-09

Initial release.

### Added
- Interactive setup script (`setup.sh`) with stack detection
- Adopt script (`adopt.sh`) for existing projects
- Stack presets: TypeScript, Python, Go, Rust, Ruby, Elixir
- Custom skills: code-review, explain-code, generate-tests, refactor-code, review-mr, install-precommit
- Specialized agents: researcher, code-reviewer, test-writer
- Hooks: validate-bash (PreToolUse), auto-format (PostToolUse), pre-commit-review
- Security defaults blocking `.env`, `rm -rf`, `sudo`, `curl | bash`
- CI workflow with shellcheck, syntax validation, JSON validation
- PR review automation (`review-mr.sh`, GitHub Actions workflow)
- Comprehensive documentation in README and docs/

### Security
- SECURITY.md with vulnerability reporting process
- Security model documentation in `.claude/rules/security-model.md`

[Unreleased]: https://github.com/zbruhnke/claude-code-starter/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/zbruhnke/claude-code-starter/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/zbruhnke/claude-code-starter/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/zbruhnke/claude-code-starter/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/zbruhnke/claude-code-starter/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/zbruhnke/claude-code-starter/releases/tag/v0.1.0
