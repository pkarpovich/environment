# Go 1.27: what changed and what to look for

Read this when a service moves to Go 1.27 or when writing new code on it. Every snippet below was compiled and run on go1.27.0.

## Language

### Generic methods

A method can declare its own type parameters, even when the receiver type is not generic. Before 1.27 a generic helper that logically belonged to a struct had to be a standalone function.

```go
type Mapper struct{ prefix string }

func (m Mapper) Map[T, R any](in []T, f func(T) R) []R {
	out := make([]R, 0, len(in))
	for _, v := range in {
		out = append(out, f(v))
	}
	return out
}
```

What to look for:
- Standalone `func name[T any](...)` helpers whose only callers are methods of one struct. Per the hard rule "called only from methods of one struct -> must be a method", these can now become methods. Before 1.27, generics were the one legitimate exception to that rule.
- Leave generic helpers alone when they have non-method callers. `inputSchema[T]` in telegram-user-mcp is one example: it is called from the plain `Register*` functions.

### Promoted fields of embedded structs in composite literals

A literal can set the fields of an embedded struct directly. The two-step init (build the outer value, then assign the embedded value) is gone.

```go
type Head struct{ Ears int }
type Dog struct {
	Head
	Name string
}

d := Dog{Name: "rex", Ears: 2}
```

What to look for: `x := Outer{...}; x.Inner = Inner{...}` and `Outer{Inner: Inner{...}, ...}` where the flat form reads better.

## Standard library

### `httptest.NewTestServer` + `testing/synctest`

`httptest.NewTestServer(t, handler)` serves over an in-memory network, and it works inside a `synctest.Test` bubble. The old `httptest.NewServer` kept a keep-alive socket goroutine alive, so time inside the bubble never advanced and the test hung. The docs now say most tests should use `NewTestServer`.

- Call `server.Client()` before reading `server.URL`: the URL is set by the first `Client`/`Start` call. For in-memory servers it is `http://example.com`.
- The server is closed through `t.Cleanup`, so no manual `Close` is needed.

```go
func TestClient_TimeoutIsUnavailable(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		server := httptest.NewTestServer(t, http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
			<-r.Context().Done()
		}))
		httpClient := server.Client()
		httpClient.Timeout = 10 * time.Second
		client := New(Config{BaseURL: server.URL, HTTPClient: httpClient})

		_, err := client.Get(t.Context())
		require.ErrorIs(t, err, ErrUnavailable)
	})
}
```

The 10s timeout above elapses instantly and deterministically in the bubble.

What to look for:
- Timeout, expiry, retry and backoff tests that use a short real timeout (`50 * time.Millisecond`) plus a `release` channel to unblock the handler. Move them into `synctest.Test` with `NewTestServer` and the real production timeout.
- Token-expiry and cool-off tests that mock the clock only because the HTTP server blocked the bubble.
- Do not convert tests that need a real listener, such as `run()` binding `:port` or `require.Eventually` polling a real socket.

### `uuid` in the standard library

The import path is plain `import "uuid"`, not `crypto/uuid`. It provides `New`, `NewV4`, `NewV7`, `Parse`, `MustParse`, `Nil`, `Max`, and `UUID.Compare`/`String`/`MarshalText`/`UnmarshalText`. Random components come from a CSPRNG.

What to look for: a direct `github.com/google/uuid` (or gofrs) dependency in `go.mod`. Switch it to the stdlib and drop the dependency. An `// indirect` entry pulled in by other modules is not yours to remove.

### `encoding/json` runs on v2

`encoding/json` (v1 API) is now a wrapper over `encoding/json/v2`. The API is unchanged, so no code change is needed. Still, run the full test suite after the bump, and check exact-bytes JSON assertions in particular.

### `strings.CutLast`

`before, after, found := strings.CutLast(s, sep)` splits around the last occurrence of `sep`. It replaces `i := strings.LastIndex(s, sep); s[:i], s[i+len(sep):]`.

### Also new, rarely relevant to our services

- `crypto/mldsa`: ML-DSA post-quantum signatures, next to `crypto/mlkem`.
- `simd`: vector arithmetic.

## Carried from 1.26 and still commonly missed

golangci-lint `modernize` flags these:
- `errors.AsType[*url.Error](err)` returns `(v, ok)` and replaces `var e *url.Error; errors.As(err, &e)`.
- `new(expr)` allocates and initialises in one step: `it.Season = new(md.ParentIndex)`.

## Bump checklist

1. Pin the version in `.mise.toml` (`go = "1.27.x"`), set `go 1.27` in `go.mod`, and set `GO_VERSION=1.27` in the Dockerfile.
2. Run `go fix ./...`. The modernizers rewrite the mechanical cases.
3. Run `golangci-lint run ./...` and fix the `modernize` findings by hand.
4. Grep for the "What to look for" patterns above. Pay particular attention to time-based HTTP tests (move them to synctest) and to direct `google/uuid` usage.
5. Run `go test ./... -race`.
