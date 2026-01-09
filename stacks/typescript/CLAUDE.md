# {{PROJECT_NAME}}

{{PROJECT_DESC}}

## Tech Stack

- **Runtime**: Node.js {{NODE_VERSION}}
- **Language**: TypeScript {{TS_VERSION}}
- **Framework**: {{FRAMEWORK}}
- **Package Manager**: {{PACKAGE_MANAGER}}

## Commands

```bash
{{CMD_DEV}}           # Start development server
{{CMD_TEST}}          # Run tests
{{CMD_BUILD}}         # Build for production
{{CMD_LINT}}          # Run ESLint
{{CMD_TYPECHECK}}     # Run type checker
```

## Code Conventions

### TypeScript
- Strict mode enabled (`strict: true` in tsconfig)
- No `any` type - use `unknown` and type guards
- Prefer `interface` over `type` for object shapes
- Use `readonly` for immutable properties

### Imports
- Use named exports, not default exports
- Group imports: external → internal → relative
- Use path aliases (`@/` for src)

### Naming
- `PascalCase` for types, interfaces, classes, React components
- `camelCase` for variables, functions, methods
- `SCREAMING_SNAKE_CASE` for constants
- `kebab-case` for file names

### Async
- Always use `async/await` over `.then()` chains
- Handle errors with try/catch, not `.catch()`
- Use `Promise.all()` for parallel operations

### React (if applicable)
- Functional components only
- Custom hooks for shared logic
- Props interface named `{Component}Props`

## Do Not

- Never use `any` - use `unknown` and narrow
- Never use `@ts-ignore` - fix the types
- Never commit `console.log` - use logger
- Never use `var` - use `const` or `let`
- Never mutate function parameters

## Testing

- Jest/Vitest for unit tests
- React Testing Library for components
- Test files: `*.test.ts` or `*.spec.ts`
- Coverage threshold: 80%

## Project Structure

```
src/
├── components/     # React components
├── hooks/          # Custom hooks
├── lib/            # Utilities and helpers
├── services/       # API clients, external services
├── types/          # Shared TypeScript types
└── __tests__/      # Test files
```
