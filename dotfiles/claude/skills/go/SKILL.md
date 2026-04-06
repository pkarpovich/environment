---
name: go
description: Go 1.25+ development standards and coding conventions. Use when writing, reviewing, or refactoring Go code. Triggers on Go file creation/editing, code reviews, architecture decisions, testing strategies, error handling patterns, concurrency, or when user asks about Go best practices.
---

# Go

## Before Writing Code

- Read `go.mod` to check Go version and installed dependencies
- Use existing libraries from `go.mod` instead of reimplementing
- Never add new dependencies unless directly needed for the task

## Code Style

### Naming

- All comments lowercase except godoc on exported symbols
- Clear names over comments — code should be self-documenting
- No comments or docstrings unless absolutely necessary for non-obvious logic

### Structure

- Early return pattern: check failures first with `if err != nil { return }`, then main logic flows flat
- Imports at top of file, never inside functions; group: stdlib, external, internal
- Private struct fields; add accessor methods only when needed outside package
- Compile regex once at package level: `var reToken = regexp.MustCompile(...)`
- Deferred cleanup: `defer f.Close()` immediately after acquiring resource

### Error Handling

- Wrap errors with context: `fmt.Errorf("load config: %w", err)`
- Return errors, don't panic — panic only for programmer bugs (impossible states)
- Check errors immediately, never ignore with `_`
- Add linter exclusions to `.golangci.yml` instead of `_, _ =` prefixes

## Constructors

- **≤3 positional args**: fine as-is
- **4+ args, or 2+ adjacent same-typed args**: use a config struct
- `context.Context` stays as first positional param — never in config struct
- Required args without sensible defaults may stay positional alongside the config struct
- Name config structs `ThingConfig` (e.g., `ManagerConfig`, `UploaderConfig`); if package has one main type, just `Config`
- Use config structs for internal code; functional options (`...Option`) only for public library APIs where backward compat matters

```go
type ManagerConfig struct {
    CLI        DockerClient
    ImageName  string
    DataDir    string
    Logger     *slog.Logger
}

func NewManager(cfg ManagerConfig) *Manager {
    return &Manager{
        cli:       cfg.CLI,
        imageName: cfg.ImageName,
        dataDir:   cfg.DataDir,
        logger:    cfg.Logger,
    }
}
```

## Interfaces

- Define interfaces at consumer side, not provider side
- Keep interfaces small — one or two methods is ideal
- Accept interfaces, return concrete types:

```go
// consumer defines what it needs
type Storage interface {
    Save(ctx context.Context, key string, data []byte) error
}

type Service struct {
    store Storage
}
```

## Concurrency

- `context.Context` as first parameter for blocking/cancellable operations
- Use `errgroup` for parallel work with error propagation
- Protect shared state with `sync.Mutex`; prefer `atomic` for simple counters
- Channel direction in signatures: `func process(in <-chan Item, out chan<- Result)`
- Never start goroutines without a way to stop them (context, done channel, or WaitGroup)

## Testing

- Table-driven tests with `testify/assert` and `testify/require`
- One `_test.go` per source file, same package
- Never `foo_something_test.go` — just `foo_test.go`
- Use `t.TempDir()` for all file operations in tests
- Tests must NEVER touch real user config directories
- Mocks: generate with `moq`, store in `mocks/` subdirectory
- Target 80%+ coverage

```go
func TestParseConfig(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    Config
        wantErr bool
    }{
        {name: "valid", input: "key=value", want: Config{Key: "value"}},
        {name: "empty", input: "", wantErr: true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseConfig(tt.input)
            if tt.wantErr {
                require.Error(t, err)
                return
            }
            require.NoError(t, err)
            assert.Equal(t, tt.want, got)
        })
    }
}
```

## Platform Support

- Use build tags for platform-specific code: `//go:build !windows`
- Separate files: `foo_unix.go` and `foo_windows.go`
- Use `filepath.Join` not `path.Join` for OS paths

## Project Layout

```
cmd/{name}/main.go      — entry points
internal/{pkg}/          — private packages
{pkg}/                   — public packages (only if intentional)
```

- Flat package structure preferred — avoid deep nesting
- One package per concern, not per type
