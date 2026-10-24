---
name: yotei
description: Pavel's task tracker and backlog, yotei (MCP server `yotei`). Use when Pavel asks to add something to the backlog or park it as a task for later instead of doing it now, asks what is on his backlog, what tasks he has or what is planned, or wants a task closed, rescheduled or changed. "Backlog" means yotei, not a repo's `docs/backlog/`, unless Pavel names the repo backlog explicitly.
---

# yotei - Pavel's tasks

MCP server `yotei` (`https://yotei.pkarpovich.space/mcp`), tools `mcp__yotei__*`. A task is a note `Tasks/<title>.md` in the tuclaw vault plus metadata in yotei. The tuclaw agent and these sessions share it; Pavel reads it in the yotei app.

## Adding to the backlog

The usual case: during a session Pavel spots something and says to add it to the backlog, so he doesn't switch context. Do it right away, without asking.

1. `search_tasks` with a few key words first. Compare the problem each hit describes, not the file or repo it mentions: one file holds many unrelated problems. If an open task already covers it, say so; if the new finding sharpens it, edit that note (see below) instead of creating a second task.
2. `add_tasks` with one item:
   - `title`: names the problem, not the place - `reopen fallback ignores the last-frontmost window`, not `fix library.go`. Short, in English. It becomes the file name, so no `/` or `:`, and it must be unique.
   - `body`: see "Writing the body".
   - `project`: always set, as `[[Name]]` - the repo or product the task is about, e.g. `[[farside]]`, `[[turtle-hub]]`. Check `task_values` with `field: "project"` and reuse an existing name exactly when it is the same thing; otherwise a new name is fine. The link does not need an existing note.
   - Leave `status` (backlog), `scheduled`, `deadline` and `important` unset unless Pavel gave a day, a deadline or called it important.
3. Reply with the title in one line. Don't go back to the task unless asked.

## Writing the body

The body is read cold, days later, by Pavel or by an agent that has none of this session's context. Markdown, in the language Pavel used.

- Say what is wrong or missing, why it matters, and how it shows today: the concrete command, output, repo, `path:line`, PR or commit. Add the idea for the fix if there is one.
- No required sections. Two lines when two lines carry it; a page only for a problem that needs a page.
- No implementation plan: no step lists, tests, docs or file-by-file changes. Whoever takes the task decides how.
- Write about 80% of the way to ASD-STE100 (Simplified Technical English), also in Russian: short sentences, about 20 words at most; one idea per sentence; active voice; concrete words - the command, the file, the date - not general ones; one word for one thing, no synonyms for variety; no hedges or filler ("apparently", "in general", "it is worth noting").
- A mermaid diagram only when the point is a structure that text describes badly: a flow between several components, or state transitions. Keep it small, and never instead of the text. Obsidian renders it; the yotei app shows it as a code block.

## Changing a task

- Status, dates, important and tags live in yotei: change them with `update_tasks`.
- The body is just the note: edit `~/Obsidian/PK Workspace/Tuclaw/Tasks/<title>.md` directly, like any file - rewrite, fix, restructure. Leave the frontmatter (`task_id`, `project`) as it is. Obsidian git syncs the file, and yotei picks it up on its next pull.
- `append_to_task` is for a quick addition when you have no access to the file.
- Never close a task to recreate it with a cleaner text: edit the note instead.
- When a session does the work a task describes, set it to `done` in the same session, right after the work lands. A task not worth doing goes to `dropped`.

## Reading

- Reading the backlog is not permission to work on it. On "what is on my backlog", show it and stop.
- To list: `query_tasks`, one line per task - title, project, status, date if set.
- When Pavel picks a task or asks what to take, brief it before anything else, one line each: summary in your own words (not the title restated); effort - what the fix touches and whether it is mechanical or still a design decision; blast radius - what else the change can reach; materiality - who is affected today and how badly, or plainly that nothing is visible yet.
- `query_tasks` takes a Dataview-like `where`: `!closed AND scheduled <= today`, `project = "farside"`, `tags contains "x"`, `important`, `today±N` for relative days. Unset fields are `null`.
- `get_tasks` returns the note body.
- Statuses: `list_statuses` (backlog, todo, in-progress, done, dropped). A task leaves lists through a closed status; there is no delete.
- Batch several tasks into one `add_tasks` / `update_tasks` call; each call is one git commit.
