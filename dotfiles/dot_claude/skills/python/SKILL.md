---
name: python
description: Python standards for this machine: uv, ruff, ty and pytest, strict typing, small typed signatures, private-by-default modules, async with anyio and httpx, function-based tests. Loads for .py files. Patterns and module layout are in references/architecture.md, the 3.14 and 3.15 features in references/python-3.14-3.15.md.
paths:
  - "**/*.py"
  - "**/pyproject.toml"
user-invocable: false
---

# Python standards

Target the interpreter `requires-python` in `pyproject.toml` names. For anything newer than 3.13 (lazy imports, t-strings, frozendict, closed TypedDict, free threading) read `references/python-3.14-3.15.md`.

## Tooling

- **Package management**: `uv` only, never `pip` directly
- **Linting/formatting**: `ruff` (replaces black, isort, flake8)
- **Type checking**: `ty` from Astral (`uvx ty check`)
- **Testing**: `pytest` with function-based tests only

## Type System

```python
# Modern syntax (3.10+)
def process(items: list[str], config: dict[str, int] | None = None) -> tuple[str, int]: ...

# Union types
def fetch(url: str) -> bytes | None: ...  # NOT Optional[bytes]

# Generics with PEP 695 syntax, no TypeVar declarations
from typing import Protocol
from collections.abc import Callable

class Repository[T](Protocol):
    def get(self, id: str) -> T | None: ...
    def save(self, item: T) -> None: ...

def retry[**P, T](fn: Callable[P, T]) -> Callable[P, T]: ...
```

No `Any`, no `Optional[T]`, no `List`/`Dict`/`Tuple` from `typing`, no `TypeVar()` where PEP 695 syntax works.

## Code Style

### Naming

```python
# Variables: descriptive, reveal intent
user_count = len(users)           # not: n, cnt, uc
is_authenticated = token.valid    # not: auth, flag
max_retry_attempts = 3            # not: MAX, retries

# Functions: verb + noun, describe action
def fetch_user_orders(user_id: str) -> list[Order]: ...    # not: get_data, process
def validate_email_format(email: str) -> bool: ...         # not: check, do_validation
def send_welcome_notification(user: User) -> None: ...     # not: notify, handle_user

# Classes: noun, represent entity
class OrderProcessor: ...      # not: ProcessOrders, OrderHelper
class PaymentGateway: ...      # not: PaymentManager, PaymentUtils

# Booleans: is_, has_, can_, should_
is_active = user.status == "active"
has_permission = "admin" in user.roles
can_edit = document.owner_id == current_user.id
```

### Self-Documenting Code

```python
# Bad: comment explains unclear code
# Check if user can access premium features
if u.s == 'p' or u.s == 'e' or (u.t and u.t > now):

# Good: code explains itself
def has_premium_access(user: User) -> bool:
    return user.is_premium or user.is_enterprise or user.has_active_trial

if has_premium_access(user):
    ...
```

### Function Design

```python
# Single responsibility - do one thing well
def calculate_order_total(items: list[Item]) -> Decimal: ...
def apply_discount(total: Decimal, code: str) -> Decimal: ...
def format_price_display(amount: Decimal) -> str: ...

# Not: calculate_total_apply_discount_and_format()

# Small functions over long ones
# Extract when logic has a clear name
def process_order(order: Order) -> Result:
    if not validate_inventory(order):
        return Result(error="insufficient stock")

    charge_result = charge_payment(order)
    if not charge_result.success:
        return Result(error=charge_result.message)

    return fulfill_order(order)
```

### Avoid Abbreviations

```python
# Bad
def calc_ttl_amt(tx_lst: list) -> float: ...
usr_mgr = UserMgr()
btn_clk_hndlr = lambda: ...

# Good
def calculate_total_amount(transactions: list[Transaction]) -> Decimal: ...
user_manager = UserManager()
handle_button_click = lambda: ...
```

### No Global State

```python
# Bad: global variables create hidden dependencies
_db_connection = None
_config = {}

def get_user(user_id: str) -> User:
    global _db_connection
    return _db_connection.query(User).get(user_id)

def init():
    global _db_connection, _config
    _db_connection = create_connection()
    _config = load_config()

# Good: explicit dependencies via injection
@dataclass
class AppContext:
    db: Database
    config: Config

def get_user(ctx: AppContext, user_id: str) -> User:
    return ctx.db.query(User).get(user_id)

# Or pass directly
def get_user(db: Database, user_id: str) -> User:
    return db.query(User).get(user_id)
```

**Acceptable module-level constants:**
```python
DEFAULT_TIMEOUT = 30
MAX_RETRIES = 3
API_VERSION = "v2"
```

## Hard rules

The gate before a task is marked complete. A violated rule means the task is not done.

**Signatures:**
- No function or method has 4+ parameters (`self`/`cls` do not count). Past the budget, pass a `@dataclass` or `TypedDict` of options.
- A function returning 3+ values returns a `@dataclass`/`NamedTuple`, not a bare tuple unpacked at call sites.
- Adjacent same-type parameters (`start: int, end: int`) are a swap hazard - use a small dataclass or keyword-only params (`*,`).
- Public callables are fully type-annotated (params + return).

**Visibility (private by default):**
- Prefix internal names with a single underscore (`_helper`, `_State`); the public API is the non-underscore names.
- Pin each module's public surface with `__all__`; nothing outside it is API.
- Before making a new name public (no underscore), confirm an out-of-module caller; if none, underscore it.

**Functions vs methods:**
- Prefer free module-level functions for stateless logic. If a function only manipulates one class's internals (reaches into several of its attributes), make it a method on that class.
- Do not create a class just to hold one function - a module function is enough.

**Comments / docstrings (default: none):**
- No comments or docstrings unless the WHY is non-obvious; clear names over comments.
- Comments never restate what the code does.

**Per-task gate (before marking a checkbox `[x]`):**
1. `ruff format` clean, `ruff check` zero issues, `ty check` clean, `pytest` passes.
2. Grep new code: `grep -nE 'def [^(]*\(([^)]*,){3,}'` for 4+ params (drop `self`/`cls`); for each new public (non-underscore) name confirm a cross-module caller or a deliberate `__all__` entry.
3. Only after 1-2 pass: mark complete.

## Code Patterns

### Data Structures

```python
from dataclasses import dataclass, field

@dataclass(slots=True, frozen=True, kw_only=True)
class Config:
    host: str
    port: int = 8080
    tags: list[str] = field(default_factory=list)
```

### Context Managers

```python
from contextlib import contextmanager, asynccontextmanager
from collections.abc import Generator, AsyncGenerator

@contextmanager
def temp_directory() -> Generator[Path, None, None]:
    path = Path(tempfile.mkdtemp())
    try:
        yield path
    finally:
        shutil.rmtree(path)

@asynccontextmanager
async def db_transaction() -> AsyncGenerator[Connection, None]:
    conn = await pool.acquire()
    try:
        yield conn
        await conn.commit()
    except Exception:
        await conn.rollback()
        raise
    finally:
        await pool.release(conn)
```

## Async Patterns

### Fully Async Stack

```python
import anyio
from httpx import AsyncClient

async def fetch_all(urls: list[str]) -> list[bytes]:
    async with AsyncClient() as client:
        async with anyio.create_task_group() as tg:
            results: list[bytes] = []

            async def fetch_one(url: str) -> None:
                response = await client.get(url)
                results.append(response.content)

            for url in urls:
                tg.start_soon(fetch_one, url)

        return results
```

### File I/O in Async Context

```python
import anyio

async def read_config(path: Path) -> dict:
    content = await anyio.Path(path).read_text()
    return json.loads(content)
```

No synchronous I/O (`open()`, `requests`, `time.sleep`) inside async functions.

## Performance

### O(1) Lookups Over Conditionals

```python
# Bad: O(n)
def get_handler(event_type: str) -> Handler:
    if event_type == "click":
        return click_handler
    elif event_type == "key":
        return key_handler
    elif event_type == "scroll":
        return scroll_handler
    return default_handler

# Good: O(1)
HANDLERS: dict[str, Handler] = {
    "click": click_handler,
    "key": key_handler,
    "scroll": scroll_handler,
}

def get_handler(event_type: str) -> Handler:
    return HANDLERS.get(event_type, default_handler)
```

### Generators for Large Data

```python
from collections.abc import Iterator

def read_large_file(path: Path) -> Iterator[str]:
    with path.open() as f:
        for line in f:
            yield line.strip()
```

## Testing

```python
import pytest
from collections.abc import AsyncGenerator

@pytest.fixture
async def db_conn() -> AsyncGenerator[Connection, None]:
    conn = await create_test_connection()
    yield conn
    await conn.close()

async def test_user_creation(db_conn: Connection) -> None:
    user = await create_user(db_conn, name="test")
    assert user.id is not None
    assert user.name == "test"

@pytest.mark.parametrize("input,expected", [
    ("hello", "HELLO"),
    ("world", "WORLD"),
])
def test_uppercase(input: str, expected: str) -> None:
    assert input.upper() == expected
```

Function-based tests only. Internal services are not mocked, use real objects and fixtures.

## Error Handling

```python
class ValidationError(Exception):
    def __init__(self, field: str, message: str) -> None:
        self.field = field
        self.message = message
        super().__init__(f"{field}: {message}")

def parse_config(data: dict) -> Config:
    try:
        return Config(**data)
    except KeyError as e:
        raise ValidationError("config", f"missing field: {e}") from e
```

**Rules**:
- Catch specific exceptions, no bare `except:`
- Chain exceptions with `from e`
- No exception handling for impossible scenarios

## Architecture

For patterns (factory, protocol, dependency injection, layering), module layout and the decision guide, read `references/architecture.md`.

## Anti-Patterns to Avoid

- **Inheritance for code reuse** → Use composition
- **Global state** → Use dependency injection
- **Magic numbers** → Use named constants
- **Getter/setter methods** → Use `@property` when needed
- **f-strings in logging** → Use structured logging: `logger.info("user created", extra={"user_id": user.id})`
- **Blocking I/O in async** → Use anyio.Path, httpx AsyncClient
- **Manual dependency management** → Use lock files (uv.lock)
