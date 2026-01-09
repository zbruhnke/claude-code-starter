# Testing Rules

## Test Coverage

- Write tests for new functionality
- Test edge cases and error conditions
- Don't just test the happy path
- Aim for meaningful coverage, not 100% coverage

## Test Structure

- Use descriptive test names that explain the scenario
- Follow Arrange-Act-Assert (AAA) pattern
- One assertion per test when practical
- Keep tests independent - no shared mutable state

## Test Naming

Use this pattern: `[unit]_[scenario]_[expected result]`

Examples:
- `calculateTotal_emptyCart_returnsZero`
- `validateEmail_invalidFormat_throwsValidationError`
- `fetchUser_notFound_returnsNull`

## Mocking

- Mock external dependencies (APIs, databases, file system)
- Don't mock the thing you're testing
- Prefer fakes and stubs over complex mocks
- Verify mocks are called correctly

## Test Data

- Use realistic but fake data
- Don't use production data in tests
- Create test fixtures for complex data structures
- Use factories or builders for test object creation

## Running Tests

- Run tests before committing
- Keep tests fast (mock slow dependencies)
- Fix flaky tests immediately
- Don't skip tests without a documented reason
