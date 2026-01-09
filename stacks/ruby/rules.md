# Ruby Rules

## Idioms

```ruby
# Use safe navigation operator
user&.profile&.avatar

# Use || for defaults (not if/else)
name = params[:name] || "Anonymous"

# Use &. with blocks
users.map(&:name)
numbers.select(&:positive?)

# Use symbols for hash keys
{ name: "Alice", age: 30 }  # Good
{ "name" => "Alice" }        # Avoid unless needed
```

## Error Handling

```ruby
# Good: Custom error classes
class UserNotFoundError < StandardError
  attr_reader :user_id

  def initialize(user_id)
    @user_id = user_id
    super("User #{user_id} not found")
  end
end

# Good: Rescue specific errors
begin
  user = User.find!(id)
rescue ActiveRecord::RecordNotFound => e
  Rails.logger.error("User lookup failed: #{e.message}")
  nil
end

# Bad: Rescue Exception (catches everything including syntax errors)
rescue Exception => e  # Never do this
```

## ActiveRecord (Rails)

```ruby
# Use scopes for reusable queries
class User < ApplicationRecord
  scope :active, -> { where(active: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :admins, -> { where(role: 'admin') }
end

# Chain scopes
User.active.recent.admins

# Use find_each for large datasets
User.find_each(batch_size: 1000) do |user|
  process(user)
end

# Avoid N+1 queries
User.includes(:posts).each { |u| u.posts.count }  # Good
User.all.each { |u| u.posts.count }                # Bad: N+1
```

## Service Objects

```ruby
# Extract complex logic into service objects
class CreateOrder
  def initialize(user:, items:)
    @user = user
    @items = items
  end

  def call
    ActiveRecord::Base.transaction do
      order = Order.create!(user: @user)
      @items.each { |item| order.line_items.create!(item) }
      OrderMailer.confirmation(order).deliver_later
      order
    end
  end
end

# Usage
CreateOrder.new(user: current_user, items: cart_items).call
```

## Testing with RSpec

```ruby
RSpec.describe User do
  # Use let for lazy evaluation
  let(:user) { create(:user) }

  # Use subject for the thing being tested
  subject { described_class.new(attributes) }

  describe '#full_name' do
    it 'concatenates first and last name' do
      user = build(:user, first_name: 'John', last_name: 'Doe')
      expect(user.full_name).to eq('John Doe')
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:posts) }
    it { is_expected.to belong_to(:organization) }
  end
end
```

## Gems to Know

- **Devise**: Authentication
- **Pundit/CanCanCan**: Authorization
- **Sidekiq**: Background jobs
- **RuboCop**: Linting
- **FactoryBot**: Test factories
- **RSpec**: Testing
- **Pry**: Debugging
