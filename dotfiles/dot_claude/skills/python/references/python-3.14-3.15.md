# Python 3.14 and 3.15

What changed after Python 3.13 and is worth using in new code. Python 3.14 shipped 2025-10-07, 3.15 on 2026-10-09. Check `requires-python` in `pyproject.toml` before using a feature: a library that supports 3.13 cannot use any of this.

## Language

- Annotations are evaluated lazily (PEP 649, 749). Forward references and self-referencing types work without quotes or `from __future__ import annotations`. Runtime introspection goes through `annotationlib.get_annotations()`.
- Template strings (PEP 750): `t"Hello {name}"` gives a `string.templatelib.Template` with `.strings` and `.interpolations`, not a `str`. For building SQL, HTML or shell commands where the consumer must see the values separately from the literal text. An f-string stays the default for plain formatting.
- `except A, B:` without parentheses (PEP 758) when there is no `as`.
- `return`, `break` and `continue` inside `finally` raise a `SyntaxWarning` (PEP 765). Restructure instead.
- 3.15: `lazy import json` and `lazy from pathlib import Path` (PEP 810) at module scope only. The module loads on first use. For a CLI with heavy optional dependencies, this replaces imports inside functions. `-X lazy_imports` and `PYTHON_LAZY_IMPORTS=1` apply it globally, `__lazy_modules__ = [...]` keeps a module compatible with older interpreters.
- 3.15: `frozendict` built-in (PEP 814), hashable and immutable. For constants and default mappings where a `dict` would be mutated by accident. `isinstance(x, (dict, frozendict))` or `collections.abc.Mapping` where code accepted `dict` before.
- 3.15: `sentinel` built-in (PEP 661) for unique markers such as "argument not given", with a readable repr, identity preserved through copy and pickle, and usable in type expressions. Replaces `_MISSING = object()`.
- 3.15: `*` and `**` unpacking inside comprehensions (PEP 798): `[*row for row in rows]` flattens, `{**d for d in dicts}` merges.
- 3.15: UTF-8 is the default encoding everywhere (PEP 686). Still pass `encoding=` explicitly in code that runs on older interpreters.
- 3.15: `bytearray.take_bytes()` moves bytes out of a buffer without a copy.
- Error messages keep improving: wrong keyword arguments suggest the right one, unclosed brackets and `elif` after `else` get precise hints, unraisable exceptions and `--help` are colored.

## Typing

- 3.14: `typing.Union` and `X | Y` are the same type. Compare unions with `==`, never `is`.
- 3.15: `TypedDict(closed=True)` and `extra_items=` (PEP 728) for dictionaries whose keys are fully known.
- 3.15: `TypeForm[T]` (PEP 747) for parameters that take a type expression, such as a `cast`-like helper.
- 3.15: `@typing.disjoint_base` (PEP 800), for type checkers only, rarely needed in application code.
- 3.15: `TypeVarTuple` takes `bound`, `covariant`, `contravariant` and `infer_variance`.
- Removed in 3.15: `typing.ByteString` from `__all__`, `NamedTuple("P", x=int)` keyword form, zero-field `TypedDict("TD")`, `@no_type_check_decorator`.

## Standard library

- `compression.zstd` (3.14, PEP 784): Zstandard in the standard library. Prefer it to gzip for new archives and caches.
- `concurrent.interpreters` (3.14, PEP 734): multiple interpreters in one process, each with its own GIL. `InterpreterPoolExecutor` in `concurrent.futures` runs CPU-bound Python without multiprocessing.
- Free-threaded builds are officially supported from 3.14 (PEP 779) and installed by default by the macOS installer in 3.15. A `python3.15t` binary runs without the GIL. Code that relies on the GIL for thread safety needs its own locks.
- asyncio: `python -m asyncio ps <pid>` and `pstree` show the task tree of a running process (3.14). `TaskGroup.cancel()` ends a group early (3.15).
- `profiling` package (3.15, PEP 799): `profiling.tracing` is the old `cProfile`, `profiling.sampling` (Tachyon) is a sampling profiler that attaches to a running process. `cProfile` stays as an alias, `profile` is deprecated.
- `pathlib.Path.mkdir(parent_mode=...)` sets the mode of intermediate directories (3.15).
- `math.integer` module (3.15) for integer-only functions.
- PEP 768 (3.14): a safe external debugger interface, `sys.remote_exec()`, used by the sampling profiler and `pdb -p <pid>`.
- The default REPL is the new one with color, multiline editing and history from 3.13, and 3.14 adds syntax highlighting.

## Removed in 3.15

`sre_compile`, `sre_constants`, `sre_parse` modules, `CGIHTTPRequestHandler`, `Loader.load_module()`, `platform.java_ver()`, `glob.glob0/glob1`, `pathlib.PurePath.is_reserved()`, the `package` parameter of `importlib.resources.files()`. `datetime.strptime()` now raises `ValueError` on a format it previously accepted silently.
