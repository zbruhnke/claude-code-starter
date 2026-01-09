# {{PROJECT_NAME}}

{{PROJECT_DESC}}

## Tech Stack

- **Go**: {{GO_VERSION}}
- **Framework**: {{FRAMEWORK}}
- **Database**: {{DATABASE}}

## Commands

```bash
go run .              # Run the application
go test ./...         # Run all tests
go build -o bin/app   # Build binary
go mod tidy           # Clean up dependencies
golangci-lint run     # Run linter
```

## Code Conventions

### Style
- Follow Effective Go and Go Code Review Comments
- Use `gofmt` / `goimports` for formatting
- Use `golangci-lint` for linting

### Naming
- `PascalCase` for exported identifiers
- `camelCase` for unexported identifiers
- Short names for short-lived variables (`i`, `err`, `ctx`)
- Descriptive names for package-level declarations

### Packages
- Package names: short, lowercase, no underscores
- Avoid `util`, `common`, `misc` packages
- One package per directory

### Error Handling
```go
// Always check errors
result, err := doSomething()
if err != nil {
    return fmt.Errorf("doing something: %w", err)
}

// Use sentinel errors for expected conditions
var ErrNotFound = errors.New("not found")

// Wrap errors with context
if err != nil {
    return fmt.Errorf("fetching user %d: %w", userID, err)
}
```

## Do Not

- Never ignore errors with `_`
- Never use `panic` for normal error handling
- Never use `init()` unless absolutely necessary
- Never use global mutable state
- Never use `interface{}` / `any` without good reason

## Testing

- Table-driven tests for multiple cases
- Use `testify` for assertions if preferred
- Test files: `*_test.go` in same package
- Use `t.Parallel()` for independent tests

```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name string
        a, b int
        want int
    }{
        {"positive", 1, 2, 3},
        {"negative", -1, -2, -3},
        {"zero", 0, 0, 0},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            if got := Add(tt.a, tt.b); got != tt.want {
                t.Errorf("Add(%d, %d) = %d, want %d", tt.a, tt.b, got, tt.want)
            }
        })
    }
}
```

## Project Structure

```
.
├── cmd/
│   └── app/
│       └── main.go       # Entry point
├── internal/
│   ├── config/           # Configuration
│   ├── handlers/         # HTTP handlers
│   ├── services/         # Business logic
│   ├── repository/       # Data access
│   └── models/           # Domain models
├── pkg/                  # Public packages
├── go.mod
├── go.sum
└── Makefile
```
