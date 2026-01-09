# Go Rules

## Error Handling

```go
// Always handle errors explicitly
result, err := doSomething()
if err != nil {
    return fmt.Errorf("doSomething failed: %w", err)
}

// Use errors.Is and errors.As for error checking
if errors.Is(err, ErrNotFound) {
    // Handle not found
}

var pathErr *os.PathError
if errors.As(err, &pathErr) {
    // Handle path error specifically
}

// Wrap errors with context
return fmt.Errorf("processing user %d: %w", userID, err)
```

## Naming Conventions

```go
// Package names: short, lowercase, no underscores
package user  // Good
package userService  // Bad

// Exported names: PascalCase
func ProcessOrder(order Order) error

// Unexported names: camelCase
func validateInput(input string) error

// Interfaces: often end in -er
type Reader interface {
    Read(p []byte) (n int, err error)
}

// Acronyms: consistent casing
var userID string  // Good
var userId string  // Bad
var HTTPClient *http.Client  // Good
```

## Struct Design

```go
// Group related fields
type User struct {
    // Identity
    ID        string
    Email     string

    // Profile
    Name      string
    Bio       string

    // Metadata
    CreatedAt time.Time
    UpdatedAt time.Time
}

// Use constructor functions for complex initialization
func NewUser(email string) (*User, error) {
    if !isValidEmail(email) {
        return nil, ErrInvalidEmail
    }
    return &User{
        ID:        uuid.New().String(),
        Email:     email,
        CreatedAt: time.Now(),
    }, nil
}

// Prefer value receivers for small structs
func (u User) FullName() string {
    return u.FirstName + " " + u.LastName
}

// Use pointer receivers when mutating or for large structs
func (u *User) SetName(name string) {
    u.Name = name
    u.UpdatedAt = time.Now()
}
```

## Concurrency

```go
// Use channels for communication
results := make(chan Result)
go func() {
    results <- doWork()
}()

// Use sync.WaitGroup for coordination
var wg sync.WaitGroup
for _, item := range items {
    wg.Add(1)
    go func(item Item) {
        defer wg.Done()
        process(item)
    }(item)
}
wg.Wait()

// Use context for cancellation
func ProcessWithTimeout(ctx context.Context) error {
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    select {
    case result := <-doWork():
        return handleResult(result)
    case <-ctx.Done():
        return ctx.Err()
    }
}

// Protect shared state with sync.Mutex
type Counter struct {
    mu    sync.Mutex
    count int
}

func (c *Counter) Increment() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}
```

## Testing

```go
// Table-driven tests
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"positive", 1, 2, 3},
        {"negative", -1, -2, -3},
        {"zero", 0, 0, 0},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := Add(tt.a, tt.b)
            if result != tt.expected {
                t.Errorf("Add(%d, %d) = %d; want %d",
                    tt.a, tt.b, result, tt.expected)
            }
        })
    }
}

// Use testify for cleaner assertions
func TestUser(t *testing.T) {
    user, err := NewUser("test@example.com")
    require.NoError(t, err)
    assert.Equal(t, "test@example.com", user.Email)
    assert.NotEmpty(t, user.ID)
}

// Parallel tests when safe
func TestParallel(t *testing.T) {
    t.Parallel()
    // test code
}
```

## Project Structure

```
cmd/
├── api/
│   └── main.go           # API server entry point
└── worker/
    └── main.go           # Background worker entry point

internal/
├── user/                 # User domain
│   ├── user.go          # Domain types
│   ├── service.go       # Business logic
│   ├── repository.go    # Data access interface
│   └── handler.go       # HTTP handlers
├── order/
│   └── ...
└── pkg/                  # Shared internal packages
    └── database/

pkg/                      # Public packages (importable by others)
└── client/

config/
└── config.go

scripts/
└── migrate.sh
```

## Common Patterns

```go
// Options pattern for flexible configuration
type ServerOption func(*Server)

func WithPort(port int) ServerOption {
    return func(s *Server) {
        s.port = port
    }
}

func NewServer(opts ...ServerOption) *Server {
    s := &Server{port: 8080}
    for _, opt := range opts {
        opt(s)
    }
    return s
}

// Dependency injection via constructor
type UserService struct {
    repo   UserRepository
    cache  Cache
    logger Logger
}

func NewUserService(repo UserRepository, cache Cache, logger Logger) *UserService {
    return &UserService{repo: repo, cache: cache, logger: logger}
}
```

## Common Libraries

- **Gin/Echo/Chi**: HTTP routers
- **GORM/sqlx**: Database access
- **Viper**: Configuration
- **Zap/Zerolog**: Structured logging
- **testify**: Testing assertions
- **mockery**: Mock generation
- **golangci-lint**: Linting
