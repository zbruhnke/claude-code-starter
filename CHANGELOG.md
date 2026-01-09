# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/zbruhnke/claude-code-starter/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/zbruhnke/claude-code-starter/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/zbruhnke/claude-code-starter/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/zbruhnke/claude-code-starter/releases/tag/v0.1.0
