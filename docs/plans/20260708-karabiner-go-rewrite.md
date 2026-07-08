# Rewrite Karabiner config generator in Go (stdlib, zero deps)

## Overview

Replace the TypeScript/Node.js Karabiner config generator (`karabiner/src/**`) with a Go program that uses only the standard library. The program builds the same `dist/karabiner.json` that Karabiner-Elements reads today, driven by the same rule set, but with no Node.js, no pnpm, and no third-party dependencies that rot over time.

**Problem it solves:** the current generator depends on Node 22 + pnpm 9 + `tsx`/`typescript`/`prettier` (`karabiner/package.json`), all of which drift and require periodic maintenance. Karabiner is the *only* Node/pnpm consumer in this monorepo, so porting it to Go lets the whole toolchain shed Node.

**How it integrates:** `~/.config/karabiner` is a live symlink to `karabiner/dist/`. Karabiner reads `karabiner/dist/karabiner.json` directly. The generator only creates the `dist/` dir (if missing) and writes `dist/karabiner.json` — it must never wipe `dist/`, which also holds Karabiner's own `assets/` and `automatic_backups/`. The mise task `setup_keyboard` regenerates the file and reloads Karabiner via `launchctl kickstart`.

### Non-goals (v1 boundary — do not gold-plate)

- Do **not** port or re-enable the Hyper key, `navigationKeys`, `deletionKeys`, or the `createHyperSubLayer(s)` / `HyperLayerCondition` machinery. These are commented out in `karabiner/src/rules.ts` (disabled in commit `835f717`) and are out of scope. Port only the rules that actually run today.
- Do **not** add any CLI flags. The old `--laptop` flag is gone; language switching is autodetected by device (built-in vs external keyboard). Keep it flagless.
- Do **not** introduce a compile-time `KeyCode` enum/const set. Key codes are plain `string`.
- Do **not** add runtime or test dependencies. Standard library only (this includes tests — no `testify`).
- Do **not** manage or clean `dist/` beyond writing `karabiner.json`.

### Rejected alternatives

- **Full `KeyCode` string-constant block** (port the ~250-value union as Go consts): rejected — the active build uses ~20 key codes; ~230 unused constants is exactly the dead weight we are removing.
- **`text/template` over raw maps**: rejected — less type safety than structs and harder to read; loses the DRY `app()` / `subLayer()` helpers.
- **`testify` for assertions**: rejected — adds a module dependency, contradicting the zero-deps goal. Use stdlib `testing` + `encoding/json`.
- **Committed compiled binary (`go build`)**: rejected — user chose `go run .` (closest analog to `tsx`, nothing to commit or gitignore).

## Skills to invoke

Load each skill below with the Skill tool and follow its conventions before implementing any task in this plan.

- `go` — signature budgets, visibility discipline, methods-vs-helpers, file-split-by-concern, and structure conventions for all Go code in this rewrite.

## Context (from discovery)

- **Files/components involved:**
  - Current source (to be replaced/removed): `karabiner/src/rules.ts`, `karabiner/src/types.ts`, `karabiner/src/utils.ts`, `karabiner/src/customRules/{doubleCommandQ,languageSwitch,navigationKeys,deletionKeys}.ts`, `karabiner/package.json`, `karabiner/pnpm-lock.yaml`, `karabiner/tsconfig.json`.
  - New Go source: `karabiner/go.mod`, `karabiner/main.go`, `karabiner/types.go`, `karabiner/rules.go` (+ `_test.go` siblings, `karabiner/testdata/`).
  - Integration: `.mise.toml` (task `setup_keyboard`, `[tools]`), `karabiner/README.md`.
- **Active rules to port (order matters — matches `rules.ts`):**
  1. `doubleCommandQ` — 2 manipulators (variable-gated `q` + delayed-action reset). Uses `set_variable` `value: 0` and `value: 1`.
  2. `languageSwitch` — 4 manipulators, autodetect: built-in variant (`from.apple_vendor_top_case_key_code: keyboard_fn` → `to.key_code: vk_none`, no device condition) and external variant (`from.key_code: left_control` → `to.key_code: left_control`, condition `device_unless {is_built_in_keyboard: true}`), each × (EN→RU, RU→EN). Source IDs: `me.tonsky.keyboardlayout.universal.english-universal`, `me.tonsky.keyboardlayout.universal.russian-universal`.
  3. `F5 -> F13` — 1 manipulator (`from.key_code: f5`, `modifiers.optional: ["any"]` → `to.key_code: f13`).
  4. Escape sleep-fix — 1 manipulator (`from.key_code: escape` → `to_if_alone.key_code: escape`).
  5. `right_option` sublayer "Media Commands Sublayer + Apps" — ~15 manipulators, each `from.key_code: <letter>` + `modifiers.mandatory: ["right_option"]`; media keys via `keyCode(...)`, apps via `app(...)`. Order: `s,d,a,t,g,w,b,z,l,m,h,n,f,c,4`.
- **`app(name)` output shape:** a single `to` entry with
  `shell_command: open -a "<name>" && sleep 0.1 && osascript -e 'tell application "System Events" to set frontmost of process "<name>" to true'`.
- **Output envelope:** `{ "global": { "show_in_menu_bar": false }, "profiles": [ { "name": "Default", "selected": true, "complex_modifications": { "rules": [ ... ] } } ] }`, indented 2 spaces (matches `JSON.stringify(..., null, 2)`).
- **Patterns/conventions:** first Go project in this monorepo — no existing `go.mod` or `.golangci.yml`. It sets the convention. Target the latest Go, `1.26` (mise resolves to `1.26.4` as of writing); the machine currently has `1.23.12` installed, so `mise install` provisions `1.26` before building.

## Development Approach

- **Testing approach:** Regular (code first, then tests) — this is a mechanical port with a known-good reference output, so the golden file is the anchor.
- **Testing framework:** stdlib `testing` + `encoding/json` only. **No `testify`** — the `go` skill recommends testify, but this plan overrides that to honor the zero-dependency goal. Compare via `reflect.DeepEqual` on parsed `map[string]any` or on structs.
- Complete each task fully before moving to the next; small, focused changes.
- **CRITICAL: every task with code changes MUST include new/updated tests** (success + error/edge cases) as separate checklist items.
- **CRITICAL: all tests must pass (`go test ./... -race`) before starting the next task.**
- **CRITICAL: update this plan file if scope changes during implementation.**
- Run `gofmt -s` / `goimports` after each change; keep `go vet ./...` clean.

## Code-Quality Rules (verify before marking each task complete)

Materialized from the `go` skill's `## Hard rules`. Supplements the repo's global CLAUDE.md.

**Signatures:**
- No function or method has 4+ parameters; `ctx context.Context` does not count. Past the budget, use an options struct (`type fooOpts struct { ... }`).
- No function or method has 4+ return values; split into single-purpose functions or return a struct.
- Adjacent same-type parameters (`oldLine, newLine int`) are a swap hazard — put them on a struct.

**Methods vs standalone helpers:**
- If a function is called only from methods of a single struct, it MUST be a method on that struct. Calling pattern decides, not field access.
- Standalone helpers are only for: constructors/entry points (`New...`, `Parse...`, `Decorate...`), utilities shared by multiple unrelated types, and tiny cross-cutting helpers.
- Before adding a standalone helper, walk its callers; if every caller is a method of one type, make it a method.

**Visibility (private by default):**
- Lowercase identifiers by default; export only when an out-of-package caller exists.
- Exception (per CLAUDE.md): a method called by other structs in the same package may be exported for inter-component API clarity — methods only, not types, functions, constants, or variables.
- Before exporting a new identifier, grep for cross-package callers; if none, lowercase it.

**Comments (default: none):**
- Default to no comments; add one only when the WHY is non-obvious (a hidden invariant, a workaround, surprising behavior).
- Exported items get godoc comments starting with the name; unexported get a lowercase comment or none.
- Never describe WHAT self-evident code does; no multi-paragraph comments on routine helpers.

**Per-task gate (before marking a checkbox `[x]`):**
1. `gofmt -s`/`goimports` clean, `go vet ./...` clean, `go test ./... -race` passes.
2. Grep new code for the rules above: `grep -nE '^func.*\(.*,.*,.*,.*\)'` for 4+ params (excluding `ctx`); for each new standalone helper confirm a non-method caller; for each new exported identifier confirm a cross-package caller.
3. Only after 1-2 pass: mark complete.

## Testing Strategy

- **unit tests:** required per task — struct marshaling shape, the two Go-specific gotchas (below), rule-builder output, ordering.
- **golden test:** `karabiner/testdata/karabiner.golden.json` is committed; a test marshals the full config and asserts it equals the golden file byte-for-byte. The golden is produced by the Go generator itself once, then reviewed against the TS output in the acceptance task.
- **semantic acceptance:** parse the Go output and the current TS `pnpm build` output each into `map[string]any` and assert `reflect.DeepEqual` (key ordering differs between TS insertion order and Go struct order, so compare parsed, not raw bytes).
- **no e2e:** project has none.

### Go-specific gotchas the tests must lock

1. **`omitempty` zero-value trap:** `doubleCommandQ`'s delayed action resets `command-q` to `value: 0`. With `int` + `omitempty`, Go drops `"value":0` and produces invalid JSON. `SetVariable.Value` must be a plain `int` (no `omitempty`, always emitted). `Condition.Value` must be `*int` (present for `variable_if`, absent for `input_source_if`/`device_unless`). A test must assert `"value": 0` survives in the `set_variable` output.
2. **Map-ordering trap:** the `right_option` sublayer entries must serialize in the fixed order `s,d,a,t,g,w,b,z,l,m,h,n,f,c,4`. Go map iteration is randomized, so the sublayer builder takes an **ordered slice of key→command pairs**, not a `map`. A test must assert the emitted `from.key_code` order.

## Progress Tracking

- mark completed items `[x]` immediately when done
- add newly discovered tasks with ➕ prefix
- document blockers with ⚠️ prefix
- keep this plan in sync with actual work

## Solution Overview

Flat `package main` Go module rooted at `karabiner/`, split by concern per the `go` skill:

- `types.go` — the struct subset the active rules need, with `json` tags and `omitempty` (except where the gotchas above forbid it). Key codes / modifiers are `string`.
- `rules.go` — rule builders (`doubleCommandQ`, `languageSwitch`, `f5ToF13`, `escapeSleepFix`, the `right_option` sublayer) and helpers `app(name)`, `keyCode(code)`, `subLayer(...)`.
- `main.go` — composition root: assemble the `config` value, `json.MarshalIndent` with 2-space indent, `os.MkdirAll("dist")`, write `dist/karabiner.json`, print a confirmation. No flags.

Run via `go run .` from `karabiner/` (wired into the `setup_keyboard` mise task).

## Technical Details

### Struct subset (signatures only — bodies born during execution)

Only the fields the active rules use. Illustrative field list (final tags decided in code):

```go
type config struct {
    Global   global    `json:"global"`
    Profiles []profile `json:"profiles"`
}
type manipulator struct {
    Type            string          `json:"type"`
    Description     string          `json:"description,omitempty"`
    From            from            `json:"from"`
    To              []to            `json:"to,omitempty"`
    ToIfAlone       []to            `json:"to_if_alone,omitempty"`
    ToDelayedAction *delayedAction  `json:"to_delayed_action,omitempty"`
    Conditions      []condition     `json:"conditions,omitempty"`
}
type from struct {
    KeyCode                 string     `json:"key_code,omitempty"`
    AppleVendorTopCaseKeyCode string   `json:"apple_vendor_top_case_key_code,omitempty"`
    Modifiers               *modifiers `json:"modifiers,omitempty"`
}
type to struct {
    KeyCode           string       `json:"key_code,omitempty"`
    Modifiers         []string     `json:"modifiers,omitempty"`
    ShellCommand      string       `json:"shell_command,omitempty"`
    SetVariable       *setVariable `json:"set_variable,omitempty"`
    SelectInputSource *inputSource `json:"select_input_source,omitempty"`
}
type setVariable struct { Name string `json:"name"`; Value int `json:"value"` } // no omitempty on Value
type condition struct {
    Type         string        `json:"type"`
    Name         string        `json:"name,omitempty"`
    Value        *int          `json:"value,omitempty"` // pointer: emit 0 for variable_if, omit otherwise
    InputSources []inputSource `json:"input_sources,omitempty"`
    Identifiers  *identifiers  `json:"identifiers,omitempty"`
}
```

(`global`, `profile`, `complexModifications`, `modifiers` {mandatory/optional `[]string`}, `delayedAction` {toIfInvoked/toIfCanceled `[]to`}, `inputSource` {inputSourceID}, `identifiers` {isBuiltInKeyboard} follow the same pattern.)

### Helper contracts

- `keyCode(code string) layerCmd` — returns a command whose `to` is a single `{key_code: code}`.
- `app(name string) layerCmd` — returns a command whose `to` is a single `shell_command` (the `open -a … && sleep … && osascript …` string) plus a `description`.
- `subLayer(modifier, description string, entries []layerEntry) rule` — wraps each `layerEntry{key, cmd}` into a manipulator with `from.key_code=key` + `modifiers.mandatory=[modifier]`, preserving `entries` order.

## What Goes Where

- **Implementation Steps** (`[ ]`): Go source, tests, `.mise.toml`, `README.md`, removal of TS artifacts.
- **Post-Completion** (no checkboxes): live keyboard behavior check on both a built-in and an external keyboard; verifying Karabiner actually reloaded.

## Implementation Steps

### Task 1: Scaffold Go module and type subset

**Files:**
- Create: `karabiner/go.mod`
- Create: `karabiner/types.go`
- Create: `karabiner/types_test.go`

- [x] `go mod init karabiner` in `karabiner/` and set the `go 1.26` directive (latest); confirm no dependencies are added
- [x] add the struct subset in `types.go` per Technical Details (`config`, `profile`, `global`, `complexModifications`, `rule`, `manipulator`, `from`, `to`, `modifiers`, `delayedAction`, `setVariable`, `condition`, `inputSource`, `identifiers`); all types lowercase (single-package program)
- [x] apply the gotcha rules: `setVariable.Value` is `int` with no `omitempty`; `condition.Value` is `*int` with `omitempty`
- [x] write `types_test.go`: marshal a `setVariable{Value:0}` and assert output contains `"value": 0` (gotcha #1); marshal a `condition` of type `input_source_if` and assert no `"value"` key appears
- [x] run `go test ./... -race` — must pass before next task

### Task 2: Sublayer + command helpers

**Files:**
- Modify: `karabiner/rules.go` (create)
- Modify: `karabiner/rules_test.go` (create)

- [x] define `layerCmd` and `layerEntry` (key + cmd) types in `rules.go`
- [x] implement `keyCode(code string) layerCmd` and `app(name string) layerCmd` per the helper contracts (exact `app` shell string from Context)
- [x] implement `subLayer(modifier, description string, entries []layerEntry) rule` preserving entry order and applying `modifiers.mandatory=[modifier]` to each `from`
- [x] write tests: `app("Finder")` produces the exact expected `shell_command` string; `subLayer` preserves a given entry order in the emitted `from.key_code` sequence (gotcha #2); `keyCode` emits a bare `key_code` with no modifiers
- [x] run `go test ./... -race` — must pass before next task

### Task 3: The four rule builders

**Files:**
- Modify: `karabiner/rules.go`
- Modify: `karabiner/rules_test.go`

- [x] implement `doubleCommandQ()` — 2 manipulators (variable-gated `q`, and the `set_variable` + `to_delayed_action` reset to `value:0`)
- [x] implement `languageSwitch()` — 4 manipulators, built-in variant (fn→vk_none, no device condition) and external variant (left_control→left_control, `device_unless {is_built_in_keyboard:true}`), each × (EN→RU, RU→EN), using the two source-id constants
- [x] implement `f5ToF13()` and `escapeSleepFix()` (1 manipulator each) and the `right_option` `mediaAppsSubLayer()` using `subLayer` with the fixed entry order from Context
- [x] write tests: `languageSwitch()` returns exactly 4 manipulators; the external ones carry a `device_unless` condition and the built-in ones do not; `doubleCommandQ`'s delayed reset emits `"value": 0`; the media/apps sublayer emits the `from.key_code` order `s,d,a,t,g,w,b,z,l,m,h,n,f,c,4`
- [x] run `go test ./... -race` — must pass before next task

### Task 4: Composition root, output writer, and golden test

**Files:**
- Create: `karabiner/main.go`
- Create: `karabiner/main_test.go`
- Create: `karabiner/testdata/karabiner.golden.json`

- [ ] `main.go`: assemble the `config` (rules in order: doubleCommandQ, languageSwitch, f5ToF13, escapeSleepFix, mediaAppsSubLayer), `json.MarshalIndent(cfg, "", "  ")`, `os.MkdirAll("dist", 0o755)`, write `dist/karabiner.json`, print confirmation; return/handle errors with `fmt.Errorf("...: %w", err)`
- [ ] factor the config assembly into a testable function (e.g. `buildConfig() config`) so tests do not perform disk I/O
- [ ] generate `testdata/karabiner.golden.json` from `buildConfig()` output once and commit it
- [ ] write `main_test.go`: marshal `buildConfig()` and assert it equals the committed golden file (byte-for-byte)
- [ ] run `go test ./... -race` — must pass before next task

### Task 5: Semantic acceptance against the current TS output

**Files:**
- Modify: `karabiner/main_test.go`
- (reads, does not commit) current TS output

- [ ] with the TS generator still present, run `pnpm install && pnpm build` in `karabiner/` to produce the reference `dist/karabiner.json`; copy it aside as the reference (repo-relative temp, e.g. `karabiner/testdata/ts-reference.json`, do not commit)
- [ ] add a test (build-tagged or skipped when the reference file is absent) that parses both the Go output and the reference into `map[string]any` and asserts `reflect.DeepEqual`
- [ ] resolve any semantic diffs by fixing the Go builders (not by editing the golden); re-run until deep-equal
- [ ] once parity is confirmed, delete `karabiner/testdata/ts-reference.json` (keep only the committed golden)
- [ ] run `go test ./... -race` — must pass before next task

### Task 6: Wire mise task and update README

**Files:**
- Modify: `.mise.toml`
- Modify: `karabiner/README.md`

- [ ] `.mise.toml` `[tasks.setup_keyboard]`: replace `pnpm build` with `go run .` (keep `dir = "karabiner"` and the `launchctl kickstart` line)
- [ ] `.mise.toml` `[tools]`: remove `node = "22"` and `pnpm = "9"`; add `go = "1.26"`
- [ ] `karabiner/README.md`: replace the `pnpm build` build step with `go run .`; drop Node/pnpm install references
- [ ] (no unit tests — config/docs only) verify `mise run setup_keyboard` regenerates `dist/karabiner.json` and reloads Karabiner without error
- [ ] confirm `go run .` from `karabiner/` writes `dist/karabiner.json` identical to the golden

### Task 7: Remove TypeScript artifacts

**Files:**
- Delete: `karabiner/src/` (all `.ts`), `karabiner/package.json`, `karabiner/pnpm-lock.yaml`, `karabiner/tsconfig.json`
- Remove (untracked): `karabiner/node_modules/`

- [ ] delete `karabiner/src/**`, `karabiner/package.json`, `karabiner/pnpm-lock.yaml`, `karabiner/tsconfig.json`
- [ ] `rm -rf karabiner/node_modules` (untracked)
- [ ] grep the repo for lingering references to the removed TS files / `pnpm`/`tsx` in karabiner context; fix any stragglers
- [ ] (no unit tests — deletion only) run `go run .` once more to confirm the generator is self-contained after removal
- [ ] run `go test ./... -race` — must pass before next task

### Task 8: Verify acceptance criteria

- [ ] verify all Overview requirements: zero non-stdlib deps (`go.mod` has no `require` block), all five rules present and in order, autodetect languageSwitch (4 manipulators), F5→F13, no `--laptop` flag
- [ ] verify the two gotchas hold in the real output: `dist/karabiner.json` contains `"value": 0` in the command-q reset, and the sublayer key order is `s,d,a,t,g,w,b,z,l,m,h,n,f,c,4`
- [ ] run full test suite: `go test ./... -race` (from `karabiner/`)
- [ ] run `go vet ./...` and `gofmt -s -l .` (no output) and the Code-Quality grep checks
- [ ] run `mise run setup_keyboard` and confirm Karabiner reloads with no errors in its log

### Task 9: Update documentation and finalize

- [ ] update `karabiner/README.md` final wording if anything changed during implementation
- [ ] update root docs/CLAUDE.md if this establishes the monorepo's first Go conventions worth recording
- [ ] move this plan to `docs/plans/completed/`

## Post-Completion

*Items requiring manual intervention or external systems — no checkboxes, informational only.*

**Manual verification:**
- On a machine with the **built-in** keyboard: press `fn` alone and confirm it toggles EN⇄RU (and `fn` still works as a modifier otherwise).
- On a machine with an **external** keyboard: press `left_control` alone and confirm it toggles EN⇄RU while `left_control` still acts as control when chorded; confirm the built-in `fn` variant does not interfere (device condition).
- Confirm `right_option` + each letter still launches/focuses the right app, and media keys (`s/d/a`) work.
- Confirm double-`⌘Q` still required to quit; single `⌘Q` does nothing.
- Confirm `F5 → F13` and the escape sleep-fix behave as before.

**Environment note:**
- After `[tools]` loses `node`/`pnpm`, run `mise install` (or `mise run install_tools`) on each machine so the pinned Go toolchain is present and Node is no longer provisioned for this repo.
