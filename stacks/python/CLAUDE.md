# {{PROJECT_NAME}}

{{PROJECT_DESC}}

## Tech Stack

- **Python**: {{PYTHON_VERSION}}
- **Framework**: {{FRAMEWORK}}
- **Package Manager**: {{PACKAGE_MANAGER}}
- **Database**: {{DATABASE}}

## Commands

```bash
{{CMD_DEV}}           # Start development server
{{CMD_TEST}}          # Run tests
{{CMD_LINT}}          # Run linter (ruff/flake8)
{{CMD_FORMAT}}        # Format code (black/ruff)
{{CMD_TYPECHECK}}     # Type check (mypy/pyright)
```

## Code Conventions

### Style
- Follow PEP 8
- Use Black for formatting (line length: 88)
- Use Ruff or Flake8 for linting
- Use type hints everywhere

### Naming
- `snake_case` for functions, variables, modules
- `PascalCase` for classes
- `SCREAMING_SNAKE_CASE` for constants
- `_private` prefix for internal use

### Imports
```python
# Standard library
import os
from pathlib import Path

# Third-party
import httpx
from pydantic import BaseModel

# Local
from app.services import UserService
from app.models import User
```

### Type Hints
```python
from typing import Optional, List, Dict

def get_user(user_id: int) -> Optional[User]:
    ...

def process_items(items: List[Item]) -> Dict[str, int]:
    ...
```

## Do Not

- Never use `print()` for logging - use `logging` module
- Never use mutable default arguments: `def fn(items=[])`
- Never catch bare `except:` - catch specific exceptions
- Never use `from module import *`
- Never commit commented-out code

## Testing

- pytest for all tests
- Test files: `test_*.py` or `*_test.py`
- Use fixtures for shared setup
- Use parametrize for multiple test cases

## Project Structure

```
src/
├── app/
│   ├── __init__.py
│   ├── main.py           # Entry point
│   ├── config.py         # Configuration
│   ├── models/           # Data models
│   ├── services/         # Business logic
│   ├── api/              # API routes
│   └── utils/            # Helpers
├── tests/
│   ├── conftest.py       # Shared fixtures
│   ├── test_services/
│   └── test_api/
├── pyproject.toml
└── requirements.txt
```

## Virtual Environment

Always use a virtual environment:
```bash
python -m venv .venv
source .venv/bin/activate  # Unix
.venv\Scripts\activate     # Windows
```
