---
name: rust-style
description: Rust style for this machine, edition 2024: for loops over iterator chains, let-else and let chains over nested if let, shadowing over renaming, newtypes and two-variant enums over strings and bools, exhaustive matches, no narrating comments, thiserror in libraries and anyhow in binaries, clippy clean with no silenced lints. Loads for .rs files and Cargo.toml.
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
user-invocable: false
---

# Rust style

Edition 2024 on a current stable toolchain. The control-flow rules come from David Barsky's gist, the error and lint rules from Apollo's Rust handbook and the Google Rust style guide.

## Control flow: `for` loops, not iterator chains

Write `for` loops with mutable accumulators instead of iterator combinators.

```rust
// DO
let mut results = Vec::new();
for item in items {
    if item.is_valid() {
        results.push(item.process());
    }
}

// DON'T
let results: Vec<_> = items
    .iter()
    .filter(|item| item.is_valid())
    .map(|item| item.process())
    .collect();
```

```rust
// DO
let mut total = 0;
for value in values {
    total += value.amount();
}

// DON'T
let total: i64 = values.iter().map(|v| v.amount()).sum();
```

```rust
// DO
let mut found = None;
for item in items {
    if item.matches(query) {
        found = Some(item);
        break;
    }
}

// DON'T
let found = items.iter().find(|item| item.matches(query));
```

## Early returns: `let ... else`

Use `let ... else` to extract values and exit early on failure. This keeps the happy path unindented.

```rust
// DO
let Some(user) = get_user(id) else {
    return Err(Error::NotFound);
};
let Ok(session) = user.active_session() else {
    return Err(Error::NoSession);
};
// continue with user and session

// DON'T
if let Some(user) = get_user(id) {
    if let Ok(session) = user.active_session() {
        // deeply nested code
    } else {
        return Err(Error::NoSession);
    }
} else {
    return Err(Error::NotFound);
}
```

```rust
// DO
let Some(value) = maybe_value else { continue };
let Ok(parsed) = input.parse::<i32>() else { continue };

// DON'T
if let Some(value) = maybe_value {
    if let Ok(parsed) = input.parse::<i32>() {
        // ...
    }
}
```

## Pattern matching: `if let` only for a short branch

`if let` is for a short `Some`/`Ok` branch with no else. A value needed afterwards is a `let ... else`. Several conditions on one value are one let chain (`if let ... && ...`), stable since 1.88 in edition 2024, never nested `if let`. A match arm that needs a binding plus a condition uses an `if let` guard (1.95).

```rust
// ACCEPTABLE: short action, no else
if let Some(callback) = self.on_change {
    callback();
}

// DO: use let-else when you need the value
let Some(config) = load_config() else {
    return default_config();
};

// DO: use match for multiple cases
match result {
    Ok(value) => process(value),
    Err(Error::NotFound) => use_default(),
    Err(e) => return Err(e),
}

// DO: one let chain instead of nested if let
if let Some(user) = session.user() && user.is_admin() && let Ok(token) = user.token() {
    grant(token);
}

// DON'T
if let Some(user) = session.user() {
    if user.is_admin() {
        if let Ok(token) = user.token() {
            grant(token);
        }
    }
}
```

## Variable naming: shadow, don't rename

Shadow variables through transformations. Avoid prefixes like `raw_`, `parsed_`, `trimmed_`.

```rust
// DO
let input = get_raw_input();
let input = input.trim();
let input = input.to_lowercase();
let input = parse(input)?;

// DON'T
let raw_input = get_raw_input();
let trimmed_input = raw_input.trim();
let lowercase_input = trimmed_input.to_lowercase();
let parsed_input = parse(lowercase_input)?;
```

```rust
// DO
let path = args.path;
let path = path.canonicalize()?;
let path = path.join("config.toml");

// DON'T
let input_path = args.path;
let canonical_path = input_path.canonicalize()?;
let config_path = canonical_path.join("config.toml");
```

## Comments

The global comments rule applies: no narration, no section dividers, no TODO comments, no commented-out code. An `unsafe` block carries a `// SAFETY:` line, that is the one comment Rust asks for.

```rust
// DON'T
// Check if user is valid
if user.is_valid() {
    // Update the timestamp
    user.touch();
}

// --- Helper functions ---

// TODO: refactor this later
fn helper() { }

// Old implementation:
// fn old_way() { }

// DO
if user.is_valid() {
    user.touch();
}

fn helper() { }
```

## Type safety: newtypes over strings

Wrap strings in newtypes to add semantic meaning and prevent mixing different string types.

```rust
// DO
struct UserId(String);
struct Email(String);

fn send_email(to: Email, from: UserId) { }

// DON'T
fn send_email(to: String, from: String) { }
```

## Type safety: two-variant enums over bools

Use enums with meaningful variant names instead of `bool` parameters.

```rust
// DO
enum Visibility {
    Public,
    Private,
}

fn create_repo(name: &str, visibility: Visibility) { }

// DON'T
fn create_repo(name: &str, is_public: bool) { }
```

```rust
// DO
enum Direction {
    Forward,
    Backward,
}

fn traverse(dir: Direction) { }

// DON'T
fn traverse(forward: bool) { }
```

## Pattern matching: no wildcard arms

Always match all variants explicitly to get compiler errors when variants are added.

```rust
// DO
match status {
    Status::Pending => handle_pending(),
    Status::Active => handle_active(),
    Status::Completed => handle_completed(),
}

// DON'T
match status {
    Status::Pending => handle_pending(),
    _ => handle_other(),
}
```

A foreign `#[non_exhaustive]` enum is the exception: list every known variant and fold the rest into the wildcard. Anywhere else a wildcard seems needed, ask first.

## Pattern matching: no `matches!`

Use full `match` expressions instead of `matches!`. Full matches provide better compiler diagnostics when the matched type changes.

```rust
// DO
let is_ready = match state {
    State::Ready => true,
    State::Pending => false,
    State::Failed => false,
};

// DON'T
let is_ready = matches!(state, State::Ready);
```

## Destructuring: explicit, every field

Destructure structs and tuples explicitly to get compiler errors when fields change.

```rust
// DO
let User { id, name, email } = user;
process(id, name, email);

// DON'T
process(user.id, user.name, user.email);
```

```rust
// DO
for Entry { key, value } in entries {
    map.insert(key, value);
}

// DON'T
for entry in entries {
    map.insert(entry.key, entry.value);
}
```

## Code navigation: rust-analyzer through the LSP tool

Navigate Rust through the LSP tool, not grep:

- `goToDefinition` - Find where a symbol is defined
- `findReferences` - Find all references to a symbol
- `hover` - Get type info and documentation
- `documentSymbol` - Get all symbols in a file
- `goToImplementation` - Find trait implementations

## Errors

- A fallible function returns `Result`. `panic!`, `unreachable!` and `assert!` are for bugs and broken invariants, with a message that names the invariant.
- `unwrap()` only in tests. In code, `expect("invariant that holds here")` when failure is a bug, `let ... else`, `?`, `unwrap_or_else` or `ok_or` otherwise.
- A library crate defines its error enum with `thiserror`, one variant per cause, `#[from]` for wrapped errors, `#[error(transparent)]` for pass-through. A binary uses `anyhow` with `.context("what was being done")` on every `?` that crosses a boundary.
- `?` bubbles. `map_err` and `or_else` recover, `inspect_err` logs. A test asserts the error with a match on the variant, or on `to_string()` when the type has no `PartialEq`.

```rust
#[derive(Debug, thiserror::Error)]
pub enum StoreError {
    #[error("record {0} not found")]
    NotFound(RecordId),
    #[error(transparent)]
    Io(#[from] std::io::Error),
}

fn main() -> anyhow::Result<()> {
    let config = std::fs::read_to_string(path).context("reading the config")?;
    Ok(())
}
```

## Lints

The gate is `cargo clippy --all-targets --all-features --locked -- -D warnings`, plus `cargo fmt --check`. A new crate gets this block in `Cargo.toml` (`[workspace.lints.*]` in a workspace, with `lints.workspace = true` in the members):

```toml
[lints.rust]
unsafe_code = "forbid"

[lints.clippy]
all = { level = "deny", priority = 10 }
pedantic = { level = "warn", priority = 3 }
unwrap_used = "deny"
wildcard_imports = "deny"
needless_for_each = "deny"
undocumented_unsafe_blocks = "deny"
```

A finding is fixed in code. When one genuinely cannot be, the suppression is `#[expect(clippy::lint, reason = "...")]` on the smallest item, after asking, never `#[allow]` and never a crate-wide override. `#[expect]` fails the build once the lint stops firing, so a stale exception cannot linger.

## Edition 2024

Facts worth remembering because they changed:

- `impl Trait` in return position captures every in-scope lifetime. `use<'a, T>` narrows the capture when a caller needs the value to outlive an argument.
- A temporary in a tail expression drops before the locals of the block, so `lock().value.clone()` at the end of a function no longer holds the guard past the locals.
- `if let` scrutinee temporaries drop before the else branch.
- `unsafe extern` blocks, and `unsafe` on `#[no_mangle]` and `#[export_name]`.
- `gen` is reserved. `expr` fragments in `macro_rules!` match `const {}` and `_`.
- Let chains (1.88) and `if let` guards in match arms (1.95), see the pattern matching rule above. `LazyLock` and `LazyCell` replace `once_cell` and `lazy_static`. `#[expect]` (1.81) replaces `#[allow]`.
