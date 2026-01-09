# Rust Rules

## Error Handling

```rust
// Use Result for recoverable errors
fn parse_config(path: &str) -> Result<Config, ConfigError> {
    let contents = fs::read_to_string(path)?;
    let config: Config = toml::from_str(&contents)?;
    Ok(config)
}

// Use custom error types with thiserror
#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("Configuration error: {0}")]
    Config(#[from] ConfigError),

    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),

    #[error("User not found: {0}")]
    NotFound(String),
}

// Use anyhow for application code
fn main() -> anyhow::Result<()> {
    let config = parse_config("config.toml")
        .context("Failed to load configuration")?;
    Ok(())
}

// Pattern match on errors
match do_something() {
    Ok(value) => handle_success(value),
    Err(AppError::NotFound(id)) => handle_not_found(id),
    Err(e) => return Err(e.into()),
}
```

## Ownership and Borrowing

```rust
// Prefer borrowing over ownership transfer
fn process(data: &str) -> String {  // Good: borrows
    data.to_uppercase()
}

fn process(data: String) -> String {  // Usually unnecessary
    data.to_uppercase()
}

// Use &mut for mutable borrowing
fn append_suffix(s: &mut String) {
    s.push_str("_processed");
}

// Clone explicitly when needed
let owned = borrowed_str.to_string();
let cloned = data.clone();

// Use Cow for flexible ownership
use std::borrow::Cow;

fn process(input: Cow<str>) -> Cow<str> {
    if needs_modification(&input) {
        Cow::Owned(modify(input.into_owned()))
    } else {
        input
    }
}
```

## Structs and Enums

```rust
// Derive common traits
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct User {
    pub id: UserId,
    pub email: String,
    pub name: String,
}

// Use builder pattern for complex construction
#[derive(Debug, Default)]
pub struct RequestBuilder {
    url: Option<String>,
    headers: HashMap<String, String>,
    timeout: Duration,
}

impl RequestBuilder {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn url(mut self, url: impl Into<String>) -> Self {
        self.url = Some(url.into());
        self
    }

    pub fn header(mut self, key: &str, value: &str) -> Self {
        self.headers.insert(key.to_string(), value.to_string());
        self
    }

    pub fn build(self) -> Result<Request, BuildError> {
        let url = self.url.ok_or(BuildError::MissingUrl)?;
        Ok(Request { url, headers: self.headers })
    }
}

// Use enums for state machines
#[derive(Debug)]
pub enum OrderStatus {
    Pending,
    Processing { started_at: DateTime<Utc> },
    Shipped { tracking: String },
    Delivered { delivered_at: DateTime<Utc> },
    Cancelled { reason: String },
}
```

## Iterators and Functional Style

```rust
// Chain iterator methods
let result: Vec<_> = items
    .iter()
    .filter(|item| item.is_valid())
    .map(|item| item.transform())
    .collect();

// Use filter_map for combined filter + map
let valid_numbers: Vec<i32> = strings
    .iter()
    .filter_map(|s| s.parse().ok())
    .collect();

// Early return with find/any
if items.iter().any(|item| item.is_expired()) {
    return Err(Error::ExpiredItems);
}

// Use fold for accumulation
let total = orders.iter().fold(0, |acc, order| acc + order.amount);
```

## Async Rust

```rust
// Use async/await with tokio
#[tokio::main]
async fn main() -> Result<()> {
    let result = fetch_data().await?;
    process(result).await
}

// Concurrent execution with join
let (users, orders) = tokio::join!(
    fetch_users(),
    fetch_orders()
);

// Use select for racing futures
tokio::select! {
    result = fetch_data() => handle_data(result),
    _ = tokio::time::sleep(Duration::from_secs(5)) => {
        return Err(Error::Timeout);
    }
}

// Stream processing
use futures::StreamExt;

let mut stream = get_events();
while let Some(event) = stream.next().await {
    process_event(event)?;
}
```

## Testing

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }

    #[test]
    fn test_with_setup() {
        let user = User::new("test@example.com");
        assert!(user.is_valid());
        assert_eq!(user.email, "test@example.com");
    }

    #[test]
    #[should_panic(expected = "invalid email")]
    fn test_invalid_email() {
        User::new("invalid");
    }

    #[tokio::test]
    async fn test_async() {
        let result = fetch_user(1).await;
        assert!(result.is_ok());
    }
}

// Property-based testing with proptest
proptest! {
    #[test]
    fn test_roundtrip(s in "\\PC*") {
        let encoded = encode(&s);
        let decoded = decode(&encoded)?;
        prop_assert_eq!(s, decoded);
    }
}
```

## Project Structure

```
src/
├── main.rs              # Binary entry point
├── lib.rs               # Library root (if both bin and lib)
├── config.rs            # Configuration
├── error.rs             # Error types
├── domain/              # Domain types
│   ├── mod.rs
│   ├── user.rs
│   └── order.rs
├── service/             # Business logic
│   ├── mod.rs
│   └── user_service.rs
├── repository/          # Data access
│   ├── mod.rs
│   └── user_repo.rs
└── api/                 # HTTP handlers
    ├── mod.rs
    └── routes.rs

tests/                   # Integration tests
├── common/
│   └── mod.rs
└── api_tests.rs

benches/                 # Benchmarks
└── bench.rs
```

## Common Patterns

```rust
// Newtype pattern for type safety
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct UserId(pub i64);

impl From<i64> for UserId {
    fn from(id: i64) -> Self {
        Self(id)
    }
}

// Type state pattern
pub struct Request<S: State> {
    url: String,
    state: S,
}

pub struct NotSent;
pub struct Sent {
    response: Response,
}

impl Request<NotSent> {
    pub async fn send(self) -> Result<Request<Sent>> {
        let response = http::send(&self.url).await?;
        Ok(Request { url: self.url, state: Sent { response } })
    }
}

impl Request<Sent> {
    pub fn status(&self) -> StatusCode {
        self.state.response.status()
    }
}
```

## Common Libraries

- **tokio**: Async runtime
- **serde**: Serialization
- **thiserror/anyhow**: Error handling
- **tracing**: Structured logging
- **axum/actix-web**: Web frameworks
- **sqlx**: Async database
- **reqwest**: HTTP client
- **clap**: CLI arguments
- **config**: Configuration
