---
name: python-architecture
description: Design patterns and architectural principles for maintainable Python code. Use when designing new components, refactoring existing code, choosing between patterns (factory vs simple dict, inheritance vs composition), planning module structure, or implementing dependency injection. Triggers on architecture discussions, "how should I structure", refactoring requests, or when complexity needs to be managed.
---

# Python Architecture Patterns

## Principles (When to Apply Patterns)

### KISS - Keep It Simple

```python
# Over-engineered: Factory for 2 types
class NotificationFactory:
    _registry: dict[str, type[Notifier]] = {}

    @classmethod
    def register(cls, name: str):
        def decorator(notifier_cls):
            cls._registry[name] = notifier_cls
            return notifier_cls
        return decorator

    @classmethod
    def create(cls, name: str) -> Notifier:
        return cls._registry[name]()

# Simple: Dict is enough
NOTIFIERS = {
    "email": EmailNotifier(),
    "slack": SlackNotifier(),
}

def notify(channel: str, message: str) -> None:
    NOTIFIERS[channel].send(message)
```

**Use factory when**: 3+ types, complex initialization, runtime registration needed

### Rule of Three

```python
# Two similar functions - don't abstract yet
def fetch_user_orders(user_id: str) -> list[Order]: ...
def fetch_user_payments(user_id: str) -> list[Payment]: ...

# Third instance appears - now abstract
def fetch_user_resource(user_id: str, resource: type[T]) -> list[T]: ...
```

**Wait for 3 instances before creating abstractions**

### Single Responsibility

```python
# Bad: Handler does everything
class OrderHandler:
    def handle(self, request):
        order = Order(**request.json)
        order.total = sum(i.price for i in order.items)
        self.db.save(order)
        self.email.send(order.user, "Order confirmed")
        return {"id": order.id}

# Good: Separated concerns
class OrderService:
    def __init__(self, repo: OrderRepository, notifier: Notifier):
        self._repo = repo
        self._notifier = notifier

    def create(self, data: OrderData) -> Order:
        order = Order.from_data(data)
        self._repo.save(order)
        self._notifier.order_created(order)
        return order
```

## Patterns

### Protocol-Based Abstractions

```python
from typing import Protocol, runtime_checkable

@runtime_checkable
class Repository(Protocol[T]):
    def get(self, id: str) -> T | None: ...
    def save(self, item: T) -> None: ...
    def delete(self, id: str) -> bool: ...

class UserService:
    def __init__(self, repo: Repository[User]):
        self._repo = repo  # Works with any implementation
```

**Prefer Protocol over ABC**: No inheritance required, structural typing

### Factory Pattern

```python
from typing import Protocol

class ModelFactory(Protocol):
    def create(self, config: Config) -> Model: ...

class TextModelFactory:
    def create(self, config: Config) -> Model:
        return LangChainModel(config.model_name)

class STTModelFactory:
    def __init__(self, s3: S3Service):
        self._s3 = s3

    def create(self, config: Config) -> Model:
        return WhisperModel(self._s3, config.model_name)

# Registry selects factory by type
class ModelProvider:
    def __init__(self, configs: dict[str, Config], factories: dict[ModelType, ModelFactory]):
        self._configs = configs
        self._factories = factories
        self._cache: dict[str, Model] = {}

    def get(self, alias: str) -> Model:
        if alias not in self._cache:
            config = self._configs[alias]
            factory = self._factories[config.type]
            self._cache[alias] = factory.create(config)
        return self._cache[alias]
```

### Composition Over Inheritance

```python
# Bad: Inheritance hierarchy
class BaseNotifier:
    def send(self, msg): ...

class EmailNotifier(BaseNotifier):
    def send(self, msg):
        # Can't easily add rate limiting without modifying all subclasses
        ...

# Good: Composition with wrappers
class RateLimitedNotifier:
    def __init__(self, inner: Notifier, rate_limiter: RateLimiter):
        self._inner = inner
        self._limiter = rate_limiter

    def send(self, msg: str) -> None:
        if self._limiter.allow():
            self._inner.send(msg)

# Flexible composition
notifier = RateLimitedNotifier(
    LoggingNotifier(EmailNotifier()),
    RateLimiter(max_per_minute=10)
)
```

### Dependency Injection

```python
# Constructor injection (preferred)
class OrderService:
    def __init__(self, repo: Repository, notifier: Notifier):
        self._repo = repo
        self._notifier = notifier

# Annotated markers for framework injection
from typing import Annotated

class InjectedRepo:
    pass

class InjectedNotifier:
    pass

def create_order(
    data: OrderData,
    repo: Annotated[Repository, InjectedRepo],
    notifier: Annotated[Notifier, InjectedNotifier],
) -> Order:
    ...

# Injection resolver
def resolve_injections(func, **context):
    hints = get_type_hints(func, include_extras=True)
    injected = {}
    for name, hint in hints.items():
        if hasattr(hint, "__metadata__"):
            for marker in hint.__metadata__:
                if isinstance(marker, InjectedRepo):
                    injected[name] = context["repo"]
                elif isinstance(marker, InjectedNotifier):
                    injected[name] = context["notifier"]
    return injected
```

## Project Structure

### Layered Architecture

```
service/
├── api/                 # HTTP layer (FastAPI routers)
│   ├── routers/
│   │   └── orders.py    # Request/response handling only
│   ├── schemas/         # Pydantic request/response models
│   └── dependencies.py  # DI setup
├── services/            # Business logic
│   └── order_service.py
├── repositories/        # Data access
│   └── order_repo.py
├── models/              # Domain models
│   └── order.py
└── config.py
```

**Flow**: Router → Service → Repository (never skip layers)

### Module Organization

```python
# feature/
# ├── __init__.py      # Public API only
# ├── models.py        # Data structures
# ├── service.py       # Business logic
# └── repository.py    # Data access

# __init__.py - explicit public API
from feature.models import Order, OrderStatus
from feature.service import OrderService

__all__ = ["Order", "OrderStatus", "OrderService"]
# Repository is internal, not exported
```

### Configuration

```python
from enum import StrEnum
from pydantic import BaseModel

class ModelType(StrEnum):
    TEXT = "text"
    STT = "stt"
    IMAGE = "image"

class ModelConfig(BaseModel):
    provider: str
    model: str
    type: ModelType = ModelType.TEXT
    model_kwargs: dict[str, Any] = {}

# Usage in app config
class AppConfig(BaseSettings):
    models: dict[str, ModelConfig] = {}
```

## Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Premature abstraction | Complexity without benefit | Rule of Three |
| God class | Too many responsibilities | Single Responsibility |
| Inheritance for reuse | Tight coupling | Composition |
| Exposing internals | Leaky abstraction | Clean `__init__.py` exports |
| Mixing I/O with logic | Hard to test | Separate service layer |
| Global registries | Hidden dependencies | Constructor injection |
| `isinstance` chains | Missed polymorphism | Protocol + dispatch dict |

## Decision Guide

```
Need new component?
├── How many variants exist?
│   ├── 1-2 → Simple dict/function
│   └── 3+  → Factory pattern
├── Need abstraction?
│   ├── < 3 usages → Wait (Rule of Three)
│   └── ≥ 3 usages → Create Protocol
├── Extend behavior?
│   ├── Via inheritance → Reconsider
│   └── Via composition → Wrapper class
└── Share code?
    ├── < 3 places → Duplicate is fine
    └── ≥ 3 places → Extract to shared module
```
