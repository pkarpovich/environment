# Claude sessions in agterm

One Claude conversation per agterm session. This file is the map of the scripts that keep track of which conversation lives where: what each piece does, how they hand off to each other, and the traps that shaped them.

The parts live in three directories because each one plugs into a different host (agterm, Claude Code, fish), so start here rather than from any one of them.

## The state: cc-map

`~/.local/state/agterm/cc-map/<agterm-session-id>` - one JSON file per agterm
session, the single source of truth for "which conversation belongs where":

```json
{
  "conv": "9442c79c-…",          // Claude conversation id, what --resume takes
  "cwd": "/Users/…/Projects/env", // where to resume it
  "pid": 81084,                   // the claude process, recorded from inside it
  "ts": 1785106870
}
```

Written only by the SessionStart/UserPromptSubmit/Stop hook (see below), which
runs *inside* the Claude process - that is how `pid` is trustworthy. Everything
else reads it.

## The parts

| File | Role | Runs when |
|---|---|---|
| `scripts/cc-map-hook.fish` | records conv/cwd/pid, pins the session's restore command | Claude Code SessionStart, UserPromptSubmit, Stop |
| `scripts/cc-map-unmap.fish` | forgets the entry + pin when you deliberately quit Claude | Claude Code SessionEnd (only `prompt_input_exit`/`logout`/`exit`) |
| `scripts/cc-map-watch.fish` | deletes the entry when its agterm session is closed | launchd, subscribed to `agtermctl events --kind session.closed` |
| `com.pavel-karpovich.cc-map-watch.plist` | keeps that watcher alive | login, `KeepAlive` |
| `scripts/fork-cc.fish` | forks this session's conversation into a new session below it | palette "Fork Claude session" |
| `scripts/update-cc.fish` | restarts Claude on its own conversation after an update | script palette |
| `scripts/ws-shelve.fish`, `ws-unshelve.fish` | put a workspace away and bring it back | script palette |
| `../fish/functions/ccl.fish` | resume this session's recorded conversation | by hand |
| `../fish/functions/claude.fish` | tags a fresh run with an explicit session id | every `claude` invocation |
| `../claude/settings.json` | registers the four hooks above | - |

## Flows

### Working on the Mac

`claude` starts, the hook records the entry and pins a restore command onto the
pane (`agtermctl session restore "… --resume <conv>"`). The pin is what makes an
agterm restart come back to the same conversation instead of replaying the
captured argv - see the traps below for why the argv cannot be trusted.

### Quitting for real

Exiting Claude at the prompt (Ctrl+C/Ctrl+D/`exit`, `/logout`) fires the unmap
hook: the map entry and the restore pin disappear, so nothing resurrects it.
`/clear` and app teardown deliberately do **not** - that is the state a restart
must restore.

## Invariants

- The map is the truth; restore pins are derived from it and may be rebuilt at
  any time.
- Session names are never pinned (`session rename`), otherwise Claude's live
  title stops updating in the sidebar.

## Traps we already paid for

These are empirical, each cost a debugging session:

- **A resumed Claude drops the conversation id from its argv** (Node rewrites the
  process title), so neither `ps` nor `tree --json` can be used to tell which
  conversation a process serves. Hence `pid` in the map.
- **Sessions created with `--no-select` are lazy**: no pty, no process, until
  they are selected. `session type` into one fails with "session not realized".
- **fish splits command substitution on newlines** - a multi-line value passed as
  one argument (`--arg mapped (…)`) silently becomes many arguments.
- **fish `set -l x` makes `set -q x` true** even with no value; use an explicit
  sentinel.

## Debugging

```sh
ls ~/.local/state/agterm/cc-map/                    # who is mapped
jq . ~/.local/state/agterm/cc-map/<session-id>      # one entry
agtermctl tree --json | jq '[.result.tree.workspaces[].sessions[]]'   # foreground, restoreCommand, status
tail -f /tmp/cc-map-watch.log                       # the events watcher
```

A conversation that lost its map entry is not lost: `ccr` opens Claude's own
resume picker, and running it once re-creates the entry through the hook.
