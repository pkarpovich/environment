---
name: ferry
description: "Read and edit notes in the Obsidian vault on the Mac from this WSL box, and reach yotei, through ferry, the call bus over the ssh link the Mac keeps open. Use when a task needs a vault note (a yotei task body in Tuclaw/Tasks, any note Pavel names by path), when yotei tools fail to connect, when `ferry call` or `ferry ls` comes up, or when something has to run on the Mac. Not for notes that live in this box's own repos, and not on the Mac itself, where the vault is a local folder."
---

# ferry

The vault lives on the Mac, and this box has no copy of it. ferry is the way in: the Mac dials this box over ssh and keeps one stream open, and either side calls named handlers on the other. A call behaves like `ssh host command`: argv, stdin, stdout, an exit code. `ferry ls` shows whether the link is up and which handlers each side offers.

## Reading a note

```sh
f=$(mktemp --suffix=.md)
ferry call note-read "Tuclaw/Tasks/<title>.md" > "$f"
```

The path is one of: relative to the vault root (`Tuclaw/Tasks/x.md`), the form Pavel copies from the Mac (`~/Obsidian/PK Workspace/...`), or absolute (`/Users/...`). Only a regular file inside the vault is served, symlinks and anything outside exit 2.

## Editing a note

Read first, record the sha256 of the text as read, edit the local copy, write it back with that sha. The handler compares it with the file on the Mac and refuses when the note changed in between, the same rule as Edit in Claude Code.

One Bash call to read, which prints the temp file and its sha:

```sh
f=$(mktemp --suffix=.md) && ferry call note-read "Tuclaw/Tasks/<title>.md" > "$f" && echo "$f" && sha256sum "$f"
```

Then Edit on the printed file, then a separate Bash call to write, with the printed sha and path typed in literally:

```sh
ferry call note-write "Tuclaw/Tasks/<title>.md" <sha> < <file>
```

Shell variables do not survive a Bash call, so the path and the sha come from the read's output, never from `$f` or `$sha` in a later call. The sha is of the text as read, before any edit. A read that exits non-zero leaves an empty file: do not edit or write after it. One temp file per note, from `mktemp`, since two sessions on this box can edit at the same time. `note-write` replaces the whole file and never creates one: a new note is made on the Mac side or, for a task, by `add_tasks` in yotei.

## yotei on this box

The `yotei` MCP server works as on the Mac: the Mac's handler forwards each request with its own token, so nothing here needs credentials. Status, dates, project and tags change through `update_tasks`. The body of a task is the note `Tuclaw/Tasks/<title>.md`, read and edited as above, frontmatter left alone. `append_to_task` is the fallback when a full read and write is not worth it. Claude connects MCP servers once, at session start: when the link was down at that moment, `yotei` stays failed for the whole session even after the link is back. Nothing here fixes that, Pavel reconnects it with `/mcp`.

## Exit codes

| Code | Meaning | What to do |
|---|---|---|
| 0 | done | |
| 1 | the note changed on the Mac after it was read | read it again, redo the edit |
| 2 | path outside the vault, no such file, or wrong usage | fix the call |
| 126 | the handler exists but did not start | report it |
| 127 | no handler with that name on the other side | check `ferry ls` |
| 255 | link down, dropped mid-call, or over a limit | report it |

On 255, when `ferry ls` says `link: down`, or when either command prints `ferry: no daemon on this host` (this box restarted and the Mac has not connected yet), the Mac is asleep or its tunnel is down. Nothing on this box can bring it back: tell Pavel and stop.

## Not this skill

- Files in this box's repos: edit them directly.
- Starting daemons or touching `~/.config/ferry`: the daemon here starts itself when the Mac connects.
- A `ferry call` that cannot open `~/.local/state/ferry/ferry.sock` from a sandboxed command is a sandbox limit, not a link problem: ask Pavel to run that one call outside the sandbox.
