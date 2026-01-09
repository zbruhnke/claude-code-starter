# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly:

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Email the maintainer directly or use GitHub's private vulnerability reporting
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Security Model

This project provides **safety guardrails**, not a security boundary. The protections are designed to prevent accidental mistakes, not to defend against adversarial use.

### What We Protect Against

- Accidental exposure of `.env` files
- Recursive deletion commands (`rm -rf`)
- Privilege escalation (`sudo`)
- Pipe-to-shell patterns (`curl | bash`)
- Overly permissive file modes (`chmod 777`)

### Known Limitations

The following are **not** protected and are considered out of scope:

- **Variable-based bypass**: `X=/; rm -rf $X`
- **Encoded/obfuscated commands**: Using base64 or other encoding
- **Indirect file access**: Reading files through allowed commands
- **Secrets in output**: If your code logs secrets, Claude sees them
- **Network exfiltration**: If your app makes API calls

See `.claude/rules/security-model.md` for full details.

## Scope

This security policy applies to:

- The shell scripts (`setup.sh`, `adopt.sh`, `review-mr.sh`)
- The hook scripts (`.claude/hooks/*.sh`)
- The default permission configurations

It does **not** apply to:

- Claude Code itself (report to Anthropic)
- Projects created using this template (their own responsibility)
- Third-party dependencies
