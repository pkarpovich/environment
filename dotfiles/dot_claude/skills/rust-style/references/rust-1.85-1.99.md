# Rust 1.85 to 1.99

What landed on stable after Rust 1.84, from the release notes, and is worth using in application code. 1.85 shipped 2025-02-20 with edition 2024, 1.99 on 2026-10-01. Check `rust-version` in `Cargo.toml` and the toolchain mise pins before using a feature.

## Language

- Edition 2024 (1.85): `impl Trait` captures all in-scope lifetimes, `use<..>` narrows it. Tail-expression temporaries and `if let` scrutinee temporaries drop earlier. `unsafe extern` blocks. `gen` reserved. Cargo resolver 3.
- Async closures (1.85): `async |x| ...`, with `AsyncFn`, `AsyncFnMut`, `AsyncFnOnce` bounds. An async closure can borrow from its captures across the await, which `|x| async move { ... }` could not.
- Trait upcasting (1.86): `&dyn Sub` coerces to `&dyn Super` without a helper method.
- Let chains (1.88, edition 2024 only): `if let Some(a) = x && a > 0 && let Ok(b) = f(a)`. Also in `while let`.
- `#[expect(lint, reason = "...")]` (1.81) fails the build when the lint stops firing, use it instead of `#[allow]`.
- Explicitly inferred const arguments (1.89): `[0u8; _]` and `Foo::<_, 3>`.
- `if let` guards on match arms (1.95): `Some(x) if let Ok(y) = parse(x) => ...`.
- `cfg_select!` (1.95): a `match`-like replacement for `cfg_if`, in the standard library.
- `assert_matches!` and `debug_assert_matches!` (1.96) for tests, with the pattern in the failure message.
- `#[my_attr] mod foo;` (1.99): attribute macros on outlined modules.

## Standard library

- `LazyLock` and `LazyCell` (1.80) replace `once_cell::sync::Lazy` and `lazy_static!`. 1.94 adds `get`, `get_mut` and `force_mut`.
- `Vec::extract_if` and `HashMap::extract_if` (1.87, 1.88): remove and yield the elements a predicate selects, in one pass, instead of `retain` plus a second collection.
- `Vec::pop_if` (1.86), `VecDeque::pop_front_if` and `pop_back_if` (1.93).
- `Vec::push_mut` and `insert_mut` (1.95) return `&mut` to the new element.
- Slices: `split_off_first`, `split_off_last`, `split_off` (1.87), `as_chunks` and `as_rchunks` (1.88), `get_disjoint_mut` (1.86), `as_array` (1.93), `element_offset` (1.94), `subslice_range` (1.98), `array_windows` (1.94).
- `Result::flatten` (1.89). `Option::map_or_default` and `Result::map_or_default` (1.98). `bool::ok_or` and `ok_or_else` (1.98).
- `str::strip_circumfix` and `substr_range` (1.98), `str::eq_ignore_ascii_case` (1.89), `String::from_utf8_lossy_owned` (1.99).
- `Path::file_prefix`, `PathBuf::add_extension` and `with_added_extension` (1.91), `Path` and `PathBuf` compare with `str` and `String` (1.91), `Path::is_empty` (1.98). `OsString::display` (1.87).
- `File::lock`, `lock_shared`, `try_lock`, `unlock` (1.89): advisory file locks without a crate. `std::fs::set_times` (1.99).
- `Duration::from_mins` and `from_hours` (1.91), `from_nanos_u128` (1.93).
- `Ipv4Addr::from_octets`, `Ipv6Addr::from_segments` (1.91).
- `Peekable::next_if_map` (1.94). `core::iter::chain` and `core::array::repeat` (1.91).
- `RwLockWriteGuard::downgrade` (1.92). `AtomicBool::update` and `try_update` (1.95). `Cell::update` (1.88).
- `fmt::from_fn` (1.93): a `Display` value from a closure, for ad-hoc formatting without a newtype.
- `<[T]>::rotate_left` and `rotate_right` are `const` (1.92), `f32`/`f64` rounding functions are `const` (1.90).
- Integer bit helpers (1.97): `highest_one`, `lowest_one`, `isolate_highest_one`, `isolate_lowest_one`, `bit_width`. `<integer>::format_into` with `fmt::NumBuffer` (1.98) formats without allocating.
- `core::range::Range` family (1.95, 1.96): the new range types that are `Copy` and not iterators themselves (`.iter()` gives the iterator). Legacy `ops::Range` stays for `..` syntax.
- `PanicHookInfo::payload_as_str` (1.91).

## Tooling

- `cargo clippy` and `rustfmt` ship with every stable, the gate in the skill body applies to all of these.
- `rustc` uses lld as the default linker on x86_64 Linux (1.90).
- Frame pointers are not on by default in Rust, unlike Python 3.15.
