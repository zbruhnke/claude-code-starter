# Python Rules

## Type Hints

Always use type hints:

```python
from typing import Optional, List, Dict, Union, Callable
from collections.abc import Iterable, Sequence

def process_user(user_id: int, options: Optional[Dict[str, str]] = None) -> User:
    ...

# Use | syntax for Python 3.10+
def get_value(key: str) -> str | None:
    ...
```

## Error Handling

```python
# Good: Specific exceptions with context
class UserNotFoundError(Exception):
    def __init__(self, user_id: int):
        self.user_id = user_id
        super().__init__(f"User {user_id} not found")

# Good: Catch specific exceptions
try:
    user = get_user(user_id)
except UserNotFoundError:
    return None
except DatabaseError as e:
    logger.error("Database error", exc_info=e)
    raise

# Bad: Bare except
try:
    ...
except:  # Never do this
    pass
```

## Logging

```python
import logging

logger = logging.getLogger(__name__)

# Good: Structured logging with context
logger.info("User created", extra={"user_id": user.id, "email": user.email})

# Good: Exception logging
try:
    process()
except Exception:
    logger.exception("Processing failed")  # Includes traceback

# Bad: Print statements
print(f"User created: {user}")  # Never use print for logging
```

## Dataclasses and Pydantic

```python
# For simple data containers
from dataclasses import dataclass

@dataclass
class Point:
    x: float
    y: float

# For validation and serialization
from pydantic import BaseModel, Field

class UserCreate(BaseModel):
    email: str = Field(..., regex=r"^[\w\.-]+@[\w\.-]+\.\w+$")
    name: str = Field(..., min_length=1, max_length=100)
```

## Async/Await

```python
import asyncio
import httpx

# Good: Use async context managers
async def fetch_data(url: str) -> dict:
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        return response.json()

# Good: Concurrent execution
async def fetch_all(urls: list[str]) -> list[dict]:
    async with httpx.AsyncClient() as client:
        tasks = [client.get(url) for url in urls]
        responses = await asyncio.gather(*tasks)
        return [r.json() for r in responses]
```

## Context Managers

```python
from contextlib import contextmanager

@contextmanager
def database_transaction():
    conn = get_connection()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

# Usage
with database_transaction() as conn:
    conn.execute(...)
```

## Testing

```python
import pytest

# Use fixtures for setup
@pytest.fixture
def user():
    return User(id=1, name="Test User")

# Use parametrize for multiple cases
@pytest.mark.parametrize("input,expected", [
    ("hello", "HELLO"),
    ("world", "WORLD"),
])
def test_uppercase(input: str, expected: str):
    assert input.upper() == expected

# Use pytest.raises for exceptions
def test_invalid_input():
    with pytest.raises(ValueError, match="Invalid"):
        process_input("")
```
