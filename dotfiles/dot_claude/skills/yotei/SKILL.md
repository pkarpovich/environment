---
name: yotei
description: Pavel's task tracker and backlog, yotei (MCP server `yotei`). Use when Pavel asks to add something to the backlog or park it as a task for later instead of doing it now, asks what is on his backlog, what tasks he has or what is planned, or wants a task closed, rescheduled or changed. "Backlog" means yotei, not a repo's `docs/backlog/`, unless Pavel names the repo backlog explicitly.
---

# yotei - Pavel's tasks

MCP server `yotei` (`https://yotei.pkarpovich.space/mcp`), tools `mcp__yotei__*`. A task is a note `Tasks/<title>.md` in the tuclaw vault plus metadata in yotei. The tuclaw agent and these sessions share it; Pavel reads it in the yotei app.

## Adding to the backlog

The usual case: during a session Pavel spots something and says to add it to the backlog, so he doesn't switch context. Do it right away, without asking.

One request is one task, however many problems it names: "a ticket for X and Y" is one note with both in the body. Several tasks only when Pavel asks for several.

1. `search_tasks` with a few key words first. Compare the problem each hit describes, not the file or repo it mentions: one file holds many unrelated problems. If an open task already covers it, say so; if the new finding sharpens it, edit that note (see below) instead of creating a second task.
2. A screenshot or other image Pavel sends with the request is evidence and goes into the body, not only into its description. Upload it to the bucket the `s3-images` Obsidian plugin uses, under the same `<YYYY-MM>/<sha256>.<ext>` key, and put `![](<url>)` in the body next to the text it supports:

   ```sh
   f="<image path>"; ext=png; type=image/png   # jpg -> image/jpeg
   url="https://s3-hub.pkarpovich.space/obsidian/$(date -u +%Y-%m)/$(shasum -a 256 "$f" | cut -d' ' -f1).$ext"
   key=$(security find-generic-password -s obsidian-s3-sessions | sed -n 's/.*"acct"<blob>="\(.*\)"/\1/p')
   printf 'user = "%s:%s"\n' "$key" "$(security find-generic-password -s obsidian-s3-sessions -w)" |
     command curl -fsS -K - --aws-sigv4 "aws:amz:us-east-1:s3" -X PUT -H "Content-Type: $type" --data-binary @"$f" "$url"
   ```

   Writes need a signature: the key is the Keychain item `obsidian-s3-sessions` (account = access key ID, password = secret), allowed only `PutObject` on `obsidian/`. It goes to curl through stdin, so it never shows in a command line or the output. If the item is missing or the PUT fails, create the task without the image and tell Pavel the image was not uploaded. Reads stay anonymous. The bucket is reachable only over the LAN or tailscale; a link works in Obsidian, for the tuclaw agent and in the yotei app alike. Never copy the image into the vault: Obsidian Sync drops files over its size limit, and the vault-root `Attachments/` is outside the tuclaw-vault repo the agent reads.
3. `add_tasks` with one item:
   - `title`: names the problem, not the place and not the fix - `reopen fallback ignores the last-frontmost window`, not `fix library.go`; `sidebar cannot be opened after scrolling on the phone`, not `proper mobile layout`. A feature names what Pavel wants to be able to do, not the shape of the solution. Short, in English, starts with a lowercase letter like the existing titles (product names inside keep their case). It becomes the file name, so no `/` or `:`, and it must be unique.
   - `body`: see "Writing the body".
   - `project`: always set, as `[[Name]]` - the repo or product the task is about, e.g. `[[farside]]`, `[[tuclaw]]`. It must exist in yotei: `list_projects` first, reuse the name exactly, and only for something really new `add_projects` (a `parent` makes it a sub-project). `add_tasks` rejects an unknown project.
   - Leave `status` (backlog), `scheduled`, `deadline`, `important` and `tags` unset unless Pavel gave a day, a deadline, called it important or named a tag. Never invent tags like `feature`, `bug` or `migration`.
4. Reply with the title in one line. Don't go back to the task unless asked.

## Writing the body

The body is read cold, days later, by Pavel or by an agent that has none of this session's context. Markdown, in the language of Pavel's request; only the title is English. Do not mix languages inside the body.

- Say what is wrong or missing, why it matters, and how it shows today: the concrete command, output, repo, `path:line`, PR, commit, date. The idea for the fix is one sentence, and only when Pavel gave it or the evidence points to it.
- No required sections. Two lines when two lines carry it; a page only for a problem that needs a page.
- No implementation plan: no step lists, tests, docs or file-by-file changes. Whoever takes the task decides how.
- Write about 80% of the way to ASD-STE100 (Simplified Technical English), also in Russian: short sentences, about 20 words at most; one idea per sentence; active voice; concrete words - the command, the file, the date - not general ones; one word for one thing, no synonyms for variety; no hedges or filler ("apparently", "in general", "it is worth noting").
- A mermaid diagram only when the point is a structure that text describes badly: a flow between several components, or state transitions. Keep it small, and never instead of the text. Obsidian renders it; the yotei app shows it as a code block.

Never put into a body:
- a date or author prefix (`Pavel 08.11.2026:`): yotei records `created_at`, and every task is Pavel's.
- a list of guesses (`likely suspects`, `options to check`) or a designed API (field lists, parameter names, a wait mode).
- a promise instead of content (`details later`, `Pavel will explain`). If the request lacks what a cold reader needs, ask one question before creating the task, or write down exactly what is known.

Bad:

```
title: proper mobile layout
Pavel 08.11.2026: on the phone yotei just stretches to the screen width, there is no separate mobile design. Main problem: once you start scrolling, the sidebar cannot be opened any more. Needs proper mobile navigation. Details later.
```

Good:

```
title: sidebar cannot be opened after scrolling on the phone
In yotei-app on the phone the sidebar cannot be opened once the list scrolls. There is no mobile layout: the desktop one is squeezed to the screen width.
```

## Changing a task

- Status, dates, important and tags live in yotei: change them with `update_tasks`.
- The body is just the note: edit `~/Obsidian/PK Workspace/Tuclaw/Tasks/<title>.md` directly, like any file - rewrite, fix, restructure. Leave the frontmatter (`task_id`, `number`, `project`) as it is. Obsidian git syncs the file, and yotei picks it up on its next pull.
- `append_to_task` is for a quick addition when you have no access to the file.
- Never close a task to recreate it with a cleaner text: edit the note instead.
- When a session does the work a task describes, set it to `done` in the same session, right after the work lands. A task not worth doing goes to `dropped`.

## Reading

- Reading the backlog is not permission to work on it. On "what is on my backlog", show it and stop.
- To list: `query_tasks`, one line per task - title, project, status, date if set.
- When Pavel picks a task or asks what to take, brief it before anything else, one line each: summary in your own words (not the title restated); effort - what the fix touches and whether it is mechanical or still a design decision; blast radius - what else the change can reach; materiality - who is affected today and how badly, or plainly that nothing is visible yet.
- `query_tasks` takes a Dataview-like `where`: `!closed AND scheduled <= today`, `project = "farside"`, `tags contains "x"`, `important`, `today±N` for relative days. Unset fields are `null`.
- Projects form a tree (`list_projects` shows each parent). `project = "turtle-hub"` matches only that project; `project_path contains "turtle-hub"` matches it and every project below it.
- `get_tasks` returns the note body.
- Statuses: `list_statuses` (backlog, todo, in-progress, done, dropped). A task leaves lists through a closed status; there is no delete.
- Batch several tasks into one `add_tasks` / `update_tasks` call; each call is one git commit.
