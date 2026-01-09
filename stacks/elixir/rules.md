# Elixir Rules

## Pattern Matching

```elixir
# Match in function heads (preferred)
def handle_response({:ok, data}), do: process(data)
def handle_response({:error, reason}), do: log_error(reason)

# Match in case statements
case fetch_user(id) do
  {:ok, user} -> {:ok, format_user(user)}
  {:error, :not_found} -> {:error, "User not found"}
  {:error, reason} -> {:error, "Failed: #{reason}"}
end

# Match in with statements (for multiple operations)
with {:ok, user} <- fetch_user(id),
     {:ok, profile} <- fetch_profile(user),
     {:ok, _} <- authorize(user) do
  {:ok, %{user: user, profile: profile}}
else
  {:error, reason} -> {:error, reason}
end
```

## Pipelines

```elixir
# Good: Clear data transformation
def process_order(params) do
  params
  |> validate_params()
  |> create_order()
  |> calculate_total()
  |> apply_discount()
  |> persist()
end

# Avoid: Pipelines that don't flow naturally
# Bad: starting with a function call result that isn't data
process() |> something()  # What is being transformed?

# Good: Start with the data being transformed
data |> process() |> something()
```

## Error Handling

```elixir
# Use tagged tuples consistently
{:ok, result}
{:error, reason}

# Use with for happy path, handle errors in else
def create_user(attrs) do
  with {:ok, validated} <- validate(attrs),
       {:ok, user} <- Repo.insert(validated),
       {:ok, _} <- send_welcome_email(user) do
    {:ok, user}
  else
    {:error, %Ecto.Changeset{} = changeset} ->
      {:error, changeset}
    {:error, :email_failed} ->
      # User created but email failed - still success
      {:ok, user}
    error ->
      error
  end
end

# Bang functions for "should never fail" cases
user = Repo.get!(User, id)  # Raises if not found
```

## Ecto

```elixir
# Changesets for data validation
defmodule MyApp.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :name, :string
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name])
    |> validate_required([:email])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
  end
end

# Queries with Ecto.Query
import Ecto.Query

def list_active_users do
  User
  |> where([u], u.active == true)
  |> order_by([u], desc: u.inserted_at)
  |> Repo.all()
end

# Preload associations to avoid N+1
User
|> preload(:posts)
|> Repo.all()
```

## Phoenix Conventions

```elixir
# Controllers: thin, delegate to contexts
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  alias MyApp.Accounts

  def show(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    render(conn, :show, user: user)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User created")
        |> redirect(to: ~p"/users/#{user}")

      {:error, changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end

# Contexts: business logic layer
defmodule MyApp.Accounts do
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
```

## Testing

```elixir
# Use async: true when tests don't share state
use MyApp.DataCase, async: true

# Describe blocks for organization
describe "create_user/1" do
  test "with valid attrs" do
    # ...
  end

  test "with invalid attrs" do
    # ...
  end
end

# Setup blocks for shared data
setup do
  user = insert(:user)
  {:ok, user: user}
end

test "something with user", %{user: user} do
  # user is available here
end
```

## Commanded / CQRS Pattern

### Commands

```elixir
# Commands are value objects representing intent
defmodule MyApp.Accounts.Commands.RegisterUser do
  defstruct [:user_id, :email, :name, :password]
end

# Dispatch commands through the application router
defmodule MyApp.Router do
  use Commanded.Commands.Router

  dispatch RegisterUser, to: UserAggregate, identity: :user_id
  dispatch UpdateProfile, to: UserAggregate, identity: :user_id
end
```

### Aggregates

```elixir
# Aggregates handle commands and emit events
defmodule MyApp.Accounts.Aggregates.User do
  defstruct [:user_id, :email, :name, :status]

  alias MyApp.Accounts.Commands.{RegisterUser, UpdateProfile}
  alias MyApp.Accounts.Events.{UserRegistered, ProfileUpdated}

  # Command handlers return events
  def execute(%__MODULE__{user_id: nil}, %RegisterUser{} = cmd) do
    %UserRegistered{
      user_id: cmd.user_id,
      email: cmd.email,
      name: cmd.name
    }
  end

  # Reject if already registered
  def execute(%__MODULE__{user_id: id}, %RegisterUser{}) when not is_nil(id) do
    {:error, :user_already_registered}
  end

  # State mutations via apply
  def apply(%__MODULE__{} = user, %UserRegistered{} = event) do
    %{user |
      user_id: event.user_id,
      email: event.email,
      name: event.name,
      status: :active
    }
  end
end
```

### Events

```elixir
# Events are immutable facts
defmodule MyApp.Accounts.Events.UserRegistered do
  @derive Jason.Encoder
  defstruct [:user_id, :email, :name, :registered_at]
end

# Use Commanded.Event.Upcaster for event versioning
defimpl Commanded.Event.Upcaster, for: MyApp.Events.UserRegisteredV1 do
  def upcast(%{} = event, _metadata) do
    %MyApp.Events.UserRegistered{
      user_id: event.user_id,
      email: event.email,
      name: event.name || "Unknown",
      registered_at: event.registered_at
    }
  end
end
```

### Event Handlers (Projections)

```elixir
# Project events to read models
defmodule MyApp.Accounts.Projectors.User do
  use Commanded.Projections.Ecto,
    application: MyApp.App,
    repo: MyApp.Repo,
    name: "Accounts.Projectors.User"

  project(%UserRegistered{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :user, %User{
      id: event.user_id,
      email: event.email,
      name: event.name
    })
  end)

  project(%ProfileUpdated{} = event, _metadata, fn multi ->
    Ecto.Multi.update_all(multi, :user,
      from(u in User, where: u.id == ^event.user_id),
      set: [name: event.name]
    )
  end)
end
```

### Process Managers (Use Sparingly)

Process managers orchestrate workflows across multiple aggregates. Consider simpler alternatives first:
- Event handlers for one-way reactions
- Oban jobs for async work with retries

```elixir
# Only use when you truly need stateful cross-aggregate coordination
defmodule MyApp.Workflows.OrderFulfillment do
  use Commanded.ProcessManagers.ProcessManager,
    application: MyApp.App,
    name: __MODULE__

  defstruct [:order_id, :payment_confirmed, :shipped]

  def interested?(%OrderPlaced{order_id: id}), do: {:start, id}
  def interested?(%PaymentConfirmed{order_id: id}), do: {:continue, id}
  def interested?(%OrderShipped{order_id: id}), do: {:stop, id}
  def interested?(_event), do: false
end
```

### Testing CQRS

```elixir
defmodule MyApp.Accounts.UserAggregateTest do
  use MyApp.AggregateCase, aggregate: MyApp.Accounts.Aggregates.User

  describe "RegisterUser" do
    test "succeeds with valid data" do
      assert_events(
        %RegisterUser{user_id: "123", email: "test@example.com"},
        [%UserRegistered{user_id: "123", email: "test@example.com"}]
      )
    end

    test "fails if already registered" do
      assert_error(
        [%UserRegistered{user_id: "123", email: "test@example.com"}],
        %RegisterUser{user_id: "123", email: "other@example.com"},
        {:error, :user_already_registered}
      )
    end
  end
end
```

## Common Libraries

- **Phoenix**: Web framework
- **Ecto**: Database wrapper and query DSL
- **Plug**: HTTP middleware
- **Commanded**: CQRS/ES framework
- **Commanded.Scheduler**: Scheduled commands
- **Eventstore**: Event persistence
- **Oban**: Background jobs
- **Tesla**: HTTP client
- **Jason**: JSON encoding/decoding
- **ExUnit**: Testing
- **Credo**: Static analysis
- **Dialyzer**: Type checking
