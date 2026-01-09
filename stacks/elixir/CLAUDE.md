# {{PROJECT_NAME}}

{{PROJECT_DESC}}

## Tech Stack

- **Elixir**: {{ELIXIR_VERSION}}
- **Framework**: {{FRAMEWORK}}
- **Database**: {{DATABASE}}
- **EventStore**: PostgreSQL (Commanded EventStore)

## Commands

```bash
{{CMD_DEV}}           # Start development server
{{CMD_TEST}}          # Run tests
{{CMD_FORMAT}}        # Format code
iex -S mix            # Start interactive shell
mix deps.get          # Install dependencies

# EventStore / Commanded
mix event_store.create    # Create event store database
mix event_store.init      # Initialize event store schema
mix event_store.drop      # Drop event store database
mix commanded.reset       # Reset projections (dev only)
```

## Code Conventions

### Style
- Follow Elixir Style Guide
- Use `mix format` for formatting
- Use Credo for linting

### Naming
- `snake_case` for functions, variables, atoms, module attributes
- `PascalCase` for modules
- `SCREAMING_SNAKE_CASE` for module attributes used as constants
- Predicate functions end with `?` (`valid?/1`, `empty?/1`)
- Functions that raise end with `!` (`fetch!/2`)

### Functions
```elixir
# Good: Pattern matching in function heads
def process(%User{active: true} = user), do: activate(user)
def process(%User{active: false} = user), do: {:error, :inactive}

# Good: Use guards for type checks
def calculate(value) when is_number(value), do: value * 2
def calculate(_), do: {:error, :invalid_input}

# Good: Pipeline operator for data transformations
user
|> validate()
|> transform()
|> persist()
```

### Modules
```elixir
defmodule MyApp.Users do
  @moduledoc """
  Context module for user-related operations.
  """

  alias MyApp.{Repo, User}

  def list_users do
    Repo.all(User)
  end

  def get_user!(id), do: Repo.get!(User, id)

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
```

## Security

This preset includes Elixir-specific protections:
- `config/prod.secret.exs` - Blocked from reading/editing (production secrets)

Use `config/runtime.exs` or environment variables for secrets. Never expose credentials to Claude.

## Do Not

- Never use `String.to_atom/1` with user input (atom table exhaustion)
- Never ignore `{:error, _}` tuples
- Never use `try/rescue` for control flow
- Never commit `IEx.pry` statements
- Avoid mutable state outside GenServers/Agents

### CQRS-Specific
- Never mutate aggregate state directly (only via `apply/2` from events)
- Never perform side effects in aggregate `execute/2` (dispatch events instead)
- Never query read models from within aggregates
- Never skip event versioning when changing event schemas (use upcasters)
- Avoid process managers unless truly needed for cross-aggregate coordination

## Testing

- ExUnit for all tests
- Use `describe` blocks to group related tests
- Use `setup` for shared test setup
- Test files mirror source structure: `lib/app/user.ex` → `test/app/user_test.exs`

```elixir
defmodule MyApp.UsersTest do
  use MyApp.DataCase, async: true

  alias MyApp.Users

  describe "create_user/1" do
    test "with valid data creates a user" do
      attrs = %{email: "test@example.com", name: "Test"}

      assert {:ok, %User{} = user} = Users.create_user(attrs)
      assert user.email == "test@example.com"
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_user(%{})
    end
  end
end
```

## Project Structure (Phoenix)

```
lib/
├── my_app/           # Business logic (contexts)
│   ├── accounts/     # Accounts context
│   │   ├── user.ex
│   │   └── accounts.ex
│   └── repo.ex
├── my_app_web/       # Web layer
│   ├── controllers/
│   ├── views/ or components/
│   ├── templates/
│   ├── channels/
│   └── router.ex
config/
priv/
  └── repo/migrations/
test/
```

## Project Structure (Commanded/CQRS)

```
lib/
├── my_app/
│   ├── app.ex                    # Commanded application
│   ├── router.ex                 # Command routing
│   │
│   ├── accounts/                 # Bounded context
│   │   ├── commands/             # Command structs
│   │   │   ├── register_user.ex
│   │   │   └── update_profile.ex
│   │   ├── events/               # Event structs
│   │   │   ├── user_registered.ex
│   │   │   └── profile_updated.ex
│   │   ├── aggregates/           # Aggregate roots
│   │   │   └── user.ex
│   │   ├── projectors/           # Read model projections
│   │   │   └── user_projector.ex
│   │   ├── projections/          # Read models (Ecto schemas)
│   │   │   └── user.ex
│   │   └── queries/              # Query modules
│   │       └── user_queries.ex
│   │
│   ├── workflows/                # Process managers (optional, use sparingly)
│   │   └── order_fulfillment.ex
│   │
│   └── repo.ex
│
├── my_app_web/                   # Phoenix web layer
test/
├── my_app/
│   ├── accounts/
│   │   ├── aggregates/
│   │   │   └── user_test.exs
│   │   └── projectors/
│   │       └── user_projector_test.exs
│   └── workflows/                 # (if using process managers)
│       └── order_fulfillment_test.exs
└── support/
    └── aggregate_case.ex         # Test helpers
```

## CQRS Conventions

### Commands
- Structs representing user intent
- Named imperatively: `RegisterUser`, `UpdateProfile`, `PlaceOrder`
- Validated before dispatch (use Ecto changesets or custom validation)

### Events
- Immutable facts that occurred
- Named in past tense: `UserRegistered`, `ProfileUpdated`, `OrderPlaced`
- Include `@derive Jason.Encoder` for serialization

### Aggregates
- Handle commands via `execute/2`
- Apply events via `apply/2`
- Keep aggregate state minimal
- Return `{:error, reason}` for business rule violations

### Projections
- Build read models from events
- Use `Commanded.Projections.Ecto` for database projections
- Name projectors after what they build: `UserProjector`, `OrderSummaryProjector`

### Process Managers (Advanced)
- Use sparingly - only for true cross-aggregate orchestration
- Consider simpler alternatives first (event handlers, Oban jobs)
- Implement `interested?/1` to route events
- Keep process state minimal

## OTP Patterns

```elixir
# GenServer for stateful processes
defmodule MyApp.Counter do
  use GenServer

  def start_link(initial) do
    GenServer.start_link(__MODULE__, initial, name: __MODULE__)
  end

  def increment, do: GenServer.call(__MODULE__, :increment)

  @impl true
  def init(initial), do: {:ok, initial}

  @impl true
  def handle_call(:increment, _from, count) do
    {:reply, count + 1, count + 1}
  end
end
```
