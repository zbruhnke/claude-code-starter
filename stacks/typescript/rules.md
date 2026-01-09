# TypeScript Rules

## Type Safety

- Enable `strict: true` in tsconfig.json
- Never use `any` - prefer `unknown` with type guards
- Use `as const` for literal types
- Prefer `interface` for object shapes, `type` for unions/intersections

## Null Handling

- Use optional chaining: `obj?.prop?.nested`
- Use nullish coalescing: `value ?? defaultValue`
- Avoid `!` non-null assertion - handle null explicitly
- Use discriminated unions for complex state

## Functions

```typescript
// Good: explicit return types for public functions
function calculateTotal(items: Item[]): number {
  return items.reduce((sum, item) => sum + item.price, 0);
}

// Good: use generics for reusable functions
function first<T>(arr: T[]): T | undefined {
  return arr[0];
}

// Bad: implicit any through lack of types
function process(data) { ... }
```

## Error Handling

```typescript
// Define error types
class ValidationError extends Error {
  constructor(public field: string, message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

// Use Result types for expected failures
type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };
```

## Imports

```typescript
// External dependencies first
import { z } from 'zod';
import React from 'react';

// Internal modules (use path aliases)
import { UserService } from '@/services/user';
import { formatDate } from '@/lib/utils';

// Relative imports last
import { Button } from './Button';
import type { ButtonProps } from './types';
```

## Exports

- Use named exports, not default exports
- Export types separately: `export type { MyType }`
- Re-export from index files for public API
