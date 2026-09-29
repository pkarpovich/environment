# Claude sessions across two Macs

One Claude conversation per agterm session, continued from the MacBook Air over
SSH, brought back home with one chord. This file is the map of that system: what
each piece does, how they hand off to each other, and the traps that shaped them.

The parts live in four directories because each one plugs into a different host
(agterm, Claude Code, fish, tmux), so start here rather than from any one of
them.

## The rule everything serves

**One live client per conversation.** Claude Code keeps its transcript on disk;
two processes resuming the same conversation fight over it and one of them dies,
taking its terminal with it. So a conversation is either running on the Mac in
its agterm session, or in a tmux window reached over SSH - never both. Every
script below exists to keep that true across restarts, reboots and trips.

Nothing here migrates a live process. agterm cannot attach to a running program,
so "moving" a conversation always means: kill the client on one side, resume the
same conversation id on the other. The transcript is the thing that travels.

## The state: cc-map

`~/.local/state/agterm/cc-map/<agterm-session-id>` - one JSON file per agterm
session, the single source of truth for "which conversation belongs where":

```json
{
  "conv": "9442c79c-…",          // Claude conversation id, what --resume takes
  "profile": "personal",          // personal | work (work => CLAUDE_CONFIG_DIR)
  "cwd": "/Users/…/Projects/env", // where to resume it
  "pid": 81084,                   // the claude process, recorded from inside it
  "ts": 1785106870,
  "tsession": "tuclaw-c697",      // set by ccm when it mirrors this session
  "twindow": "@3"                 // …and the window id it created there
}
```

Written only by the SessionStart/UserPromptSubmit/Stop hook (see below), which
runs *inside* the Claude process - that is how `pid` is trustworthy. Everything
else reads it.

## The parts

| File | Role | Runs when |
|---|---|---|
| `scripts/cc-map-hook.fish` | records conv/profile/cwd/pid, pins the session's restore command | Claude Code SessionStart, UserPromptSubmit, Stop |
| `scripts/cc-map-unmap.fish` | forgets the entry + pin when you deliberately quit Claude | Claude Code SessionEnd (only `prompt_input_exit`/`logout`/`exit`) |
| `scripts/cc-map-watch.fish` | deletes the entry when its agterm session is closed | launchd, subscribed to `agtermctl events --kind session.closed` |
| `com.pavel-karpovich.cc-map-watch.plist` | keeps that watcher alive | login, `KeepAlive` |
| `scripts/cc-park.fish` | kills the Claude client on one side (all sessions, or one) | called by ccm and reopen-cc |
| `scripts/reopen-cc.fish` | brings conversations home: park, then resume each in its agterm session | `Cmd+Shift+L`>`r`, or palette "Reopen this CC session" |
| `scripts/fork-cc.fish` | forks this session's conversation into a new session below it | `Cmd+B` |
| `scripts/go-session.fish` | jump to the Nth sidebar row | `Cmd+Shift+1..9` |
| `../fish/functions/ccm.fish` | mirrors agterm sessions into tmux windows (all, or `--one`) | by hand, ssh login menu, tmux leader |
| `../fish/functions/ccl.fish` | resume this session's recorded conversation | by hand |
| `../fish/functions/claude.fish` | tags a fresh run with an explicit session id | every `claude` invocation |
| `../claude/settings.json` | registers the four hooks above | - |
| `../tmux/tmux.conf` | leader `Ctrl+Shift+L`, `m` mirrors one more session | inside tmux |
| `~/.config/fish/local.fish` | the SSH login menu (machine-local, not in this repo) | ssh into the Mac |

## Flows

### Working on the Mac

`claude` starts, the hook records the entry and pins a restore command onto the
pane (`agtermctl session restore "… --resume <conv>"`). The pin is what makes an
agterm restart come back to the same conversation instead of replaying the
captured argv - see the traps below for why the argv cannot be trusted.

### Leaving for the MBA

SSH in; the menu in `local.fish` offers:

- `[Enter]` - mirror **everything** into tmux session `main` (`ccm main`)
- `[o]` - pick **one** session; it gets its own tmux session named
  `<project>-<id prefix>` (`ccm --one`), stable across trips, with the status
  line off (Moshi draws its own row on the phone)
- `[p]` / `[s]` - a plain tmux session / a bare shell

Either way `ccm` parks the Mac-side Claude first (`cc-park.fish agterm …`), clears
its restore pin (so a reboot cannot resurrect it behind your back), marks the
sidebar row with a purple diamond, and only then opens the window that resumes
the conversation. Inside tmux, `Ctrl+Shift+L` `m` adds one more session as
another window the same way.

### Coming home

`Cmd+Shift+L` `r` ("Reopen CC sessions") parks the tmux side, parks any stale
Mac-side clients, resumes every mapped conversation in its own agterm session and
clears the diamonds. The palette entry "Reopen this CC session" does the same for
the focused session only, parking just that conversation's tmux window.

### Quitting for real

Exiting Claude at the prompt (Ctrl+C/Ctrl+D/`exit`, `/logout`) fires the unmap
hook: the map entry and the restore pin disappear, so nothing resurrects it.
`/clear` and app teardown deliberately do **not** - that is the state a restart
must restore.

## Invariants

- The map is the truth; pins and tmux windows are derived from it and may be
  rebuilt at any time.
- A pin exists only while the conversation is meant to live on the Mac. Parking
  clears it; the hook re-adds it on the next start.
- `ccm` never opens a window it could not park first - it aborts instead, because
  a second client is worse than no mirror.
- Session names are never pinned (`session rename`), otherwise Claude's live
  title stops updating in the sidebar.

## Traps we already paid for

These are empirical, each cost a debugging session:

- **A resumed Claude drops the conversation id from its argv** (Node rewrites the
  process title), so neither `ps` nor `tree --json` nor tmux's
  `#{pane_start_command}` can be used to tell which conversation a process serves.
  Hence `pid` in the map and `twindow` for windows.
- **`pgrep` hides its own ancestors** on macOS unless `-a` is passed - a park run
  from inside a Claude session would silently skip that very Claude.
- **Mirrored windows are addressed by tmux window id** (`@3`), never by name:
  ids are unique server-wide, never reused, and work on a detached session. Names
  repeat (a fork and its parent share the Claude title) - that is what killed the
  wrong tab back when this ran on zellij.
- **Sessions created with `--no-select` are lazy**: no pty, no process, until
  they are selected. `session type` into one fails with "session not realized".
- **tmux owns the terminal title**, so a Claude running inside a tmux window
  cannot show its live title in the agterm sidebar. `ccm` therefore stamps the
  window name once, at mirror time (`allow-rename` stays off).
- **fish splits command substitution on newlines** - a multi-line value passed as
  one argument (`--arg mapped (…)`) silently becomes many arguments.
- **fish `set -l x` makes `set -q x` true** even with no value; use an explicit
  sentinel.
- **tmux matches the character the layout produces**, so every letter binding
  carries a Cyrillic twin - the same tax zellij charged (upstream #1355).
- **Ctrl+Shift+<letter> needs `extended-keys on`**: the legacy encoding drops
  Shift on control keys, so without it the whole wezterm mirror collapses onto
  plain Ctrl+<letter>.

## Debugging

```sh
ls ~/.local/state/agterm/cc-map/                    # who is mapped
jq . ~/.local/state/agterm/cc-map/<session-id>      # one entry
agtermctl tree --json | jq '[.result.tree.workspaces[].sessions[]]'   # foreground, restoreCommand, status
CC_PARK_DRYRUN=1 cc-park.fish agterm <session-id>     # what a park would kill
tmux list-sessions                                  # the other side
tmux list-panes -s -t <session> -F '#{window_id}|#{pane_start_command}'  # what is mirrored
tail -f /tmp/cc-map-watch.log                       # the events watcher
```

A conversation that lost its map entry is not lost: `ccr` opens Claude's own
resume picker, and running it once re-creates the entry through the hook.
