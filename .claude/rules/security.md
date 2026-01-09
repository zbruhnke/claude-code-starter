# Security Rules

## Secrets and Credentials

- NEVER commit secrets, API keys, or credentials
- NEVER hardcode secrets in source code
- Use environment variables for all sensitive configuration
- Use `.env.example` to document required variables (without real values)

## Input Validation

- Validate all external input (user input, API responses, file contents)
- Use allowlists over denylists when validating
- Sanitize data before using in SQL, HTML, or shell commands
- Set reasonable limits on input sizes

## File Operations

- Never construct file paths from user input without validation
- Use path joining functions, not string concatenation
- Validate file types before processing
- Be careful with symlinks and path traversal (`../`)

## Shell Commands

- Avoid shell commands when language-native solutions exist
- Never pass unsanitized input to shell commands
- Use parameterized commands, not string interpolation
- Prefer specific commands over shell interpreters

## Dependencies

- Keep dependencies up to date
- Review new dependencies before adding
- Prefer well-maintained packages with security policies
- Use lockfiles and verify checksums

## Logging

- Never log secrets, tokens, or passwords
- Be careful logging user data (PII concerns)
- Include enough context for debugging
- Use appropriate log levels
