# Git Rules

## Commits

- Write clear, descriptive commit messages
- Use imperative mood: "Add feature" not "Added feature"
- Keep commits focused on a single change
- Reference issue numbers when applicable

## Commit Message Format

```
<type>: <short description>

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Examples:
- `feat: add user authentication`
- `fix: resolve race condition in cache`
- `docs: update API documentation`

## Branches

- Use descriptive branch names: `feature/user-auth`, `fix/login-bug`
- Keep branches short-lived
- Delete branches after merging
- Keep main/master always deployable

## Pull Requests

- Keep PRs focused and reviewable (under 400 lines when possible)
- Write clear PR descriptions
- Include testing instructions
- Respond to review feedback promptly

## What NOT to Commit

- `.env` files with real secrets
- Build artifacts and compiled code
- IDE/editor configuration (unless team-wide)
- Large binary files
- Credentials, keys, or tokens
