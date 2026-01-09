# {{PROJECT_NAME}}

{{PROJECT_DESC}}

## Tech Stack

- **Rust**: {{RUST_VERSION}}
- **Framework**: {{FRAMEWORK}}
- **Database**: {{DATABASE}}

## Commands

```bash
cargo run             # Run the application
cargo test            # Run all tests
cargo build --release # Build release binary
cargo clippy          # Run linter
cargo fmt             # Format code
cargo doc --open      # Generate and view docs
```

## Code Conventions

### Style
- Follow Rust API Guidelines
- Use `rustfmt` for formatting
- Use `clippy` for linting (deny warnings in CI)

### Naming
- `snake_case` for functions, variables, modules, crates
- `PascalCase` for types, traits
- `SCREAMING_SNAKE_CASE` for constants
- Prefix unused variables with `_`

### Error Handling
```rust
// Use Result for recoverable errors
fn parse_config(path: &Path) -> Result<Config, ConfigError> {
    let content = fs::read_to_string(path)
        .map_err(ConfigError::ReadFailed)?;
    toml::from_str(&content)
        .map_err(ConfigError::ParseFailed)
}

// Use thiserror for custom errors
#[derive(Debug, thiserror::Error)]
enum ConfigError {
    #[error("failed to read config: {0}")]
    ReadFailed(#[from] std::io::Error),
    #[error("failed to parse config: {0}")]
    ParseFailed(#[from] toml::de::Error),
}

// Use anyhow for application code
use anyhow::{Context, Result};

fn main() -> Result<()> {
    let config = parse_config(path)
        .context("loading configuration")?;
    Ok(())
}
```

## Do Not

- Never use `unwrap()` or `expect()` in library code
- Never use `unsafe` without thorough justification
- Never ignore `#[must_use]` warnings
- Never use `clone()` without considering ownership
- Never commit `todo!()` or `unimplemented!()`

## Testing

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic() {
        assert_eq!(add(1, 2), 3);
    }

    #[test]
    #[should_panic(expected = "divide by zero")]
    fn test_panic() {
        divide(1, 0);
    }

    // Use proptest for property-based testing
    proptest! {
        #[test]
        fn test_roundtrip(s in ".*") {
            assert_eq!(decode(encode(&s)), s);
        }
    }
}
```

## Project Structure

```
.
├── src/
│   ├── main.rs           # Binary entry point
│   ├── lib.rs            # Library entry point
│   ├── config.rs         # Configuration
│   ├── handlers/         # HTTP handlers
│   ├── services/         # Business logic
│   └── models/           # Domain types
├── tests/                # Integration tests
├── benches/              # Benchmarks
├── Cargo.toml
└── Cargo.lock
```

## Dependencies

- Prefer well-maintained crates from the ecosystem
- Check crate security: `cargo audit`
- Pin major versions in Cargo.toml
- Keep `Cargo.lock` in version control for binaries
