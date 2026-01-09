# {{PROJECT_NAME}}

{{PROJECT_DESC}}

## Tech Stack

- **Ruby**: {{RUBY_VERSION}}
- **Framework**: {{FRAMEWORK}}
- **Database**: {{DATABASE}}

## Commands

```bash
{{CMD_DEV}}           # Start development server
{{CMD_TEST}}          # Run tests
{{CMD_LINT}}          # Run RuboCop
{{CMD_CONSOLE}}       # Start console/REPL
```

## Code Conventions

### Style
- Follow Ruby Style Guide
- Use RuboCop for linting
- 2-space indentation

### Naming
- `snake_case` for methods, variables, files
- `PascalCase` for classes and modules
- `SCREAMING_SNAKE_CASE` for constants
- Predicate methods end with `?` (`valid?`, `empty?`)
- Dangerous methods end with `!` (`save!`, `update!`)

### Methods
```ruby
# Good: Short methods with clear purpose
def full_name
  "#{first_name} #{last_name}"
end

# Good: Use keyword arguments for clarity
def create_user(name:, email:, admin: false)
  # ...
end

# Good: Guard clauses over nested conditionals
def process(item)
  return unless item.valid?
  return if item.processed?

  # main logic
end
```

### Classes
```ruby
# Good: Small, focused classes
class UserCreator
  def initialize(params)
    @params = params
  end

  def call
    User.create!(@params)
  end
end
```

## Security

This preset includes Rails-specific protections:
- `config/master.key` - Blocked from reading/editing (encryption key)
- `config/credentials.yml.enc` - Blocked from reading (encrypted secrets)

Access secrets via `Rails.application.credentials` in code. Never expose credentials to Claude.

## Do Not

- Never use `and`/`or` for control flow - use `&&`/`||`
- Never rescue `Exception` - rescue `StandardError`
- Never use `eval` or `instance_eval` with user input
- Never commit `binding.pry` or `debugger` statements
- Avoid monkey-patching core classes

## Testing

- RSpec or Minitest
- Use factories (FactoryBot) over fixtures
- Test behavior, not implementation
- Use `let` for lazy-loaded test data
- Use `described_class` instead of repeating class name

```ruby
RSpec.describe UserCreator do
  describe '#call' do
    subject(:creator) { described_class.new(params) }

    let(:params) { { name: 'Test', email: 'test@example.com' } }

    it 'creates a user' do
      expect { creator.call }.to change(User, :count).by(1)
    end
  end
end
```

## Project Structure (Rails)

```
app/
├── controllers/
├── models/
├── views/
├── services/        # Business logic
├── jobs/            # Background jobs
└── mailers/
config/
db/
  └── migrate/
lib/
spec/ or test/
```
