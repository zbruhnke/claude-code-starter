# Code Style Rules

## General Principles

- Write clear, readable code over clever code
- Keep functions small and focused (under 50 lines)
- Use descriptive names that reveal intent
- Prefer composition over inheritance

## Naming Conventions

- **Files**: Use kebab-case for files (`user-service.ts`, `api-client.py`)
- **Classes**: Use PascalCase (`UserService`, `ApiClient`)
- **Functions**: Use camelCase (`getUserById`, `validateInput`)
- **Constants**: Use SCREAMING_SNAKE_CASE (`MAX_RETRIES`, `API_BASE_URL`)
- **Boolean variables**: Prefix with `is`, `has`, `should` (`isValid`, `hasPermission`)

## Code Organization

- Group imports: external dependencies first, then internal modules
- Order class members: static fields, instance fields, constructor, public methods, private methods
- Keep related code close together
- Extract magic numbers into named constants

## Comments

- Don't comment what the code does; comment why
- Use TODO comments for planned improvements: `// TODO: Add retry logic`
- Document non-obvious behavior or edge cases
- Keep comments up to date when code changes

## Error Handling

- Fail fast and explicitly
- Use specific error types, not generic errors
- Include context in error messages
- Don't swallow errors silently
