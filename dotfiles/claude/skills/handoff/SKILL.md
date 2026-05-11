---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up. Saves to the current repo's .local/handoffs/ so the doc lives with the project and is not lost between sessions.
argument-hint: "What will the next session be used for?"
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work.

## Storage

Resolve the repo root with `git rev-parse --show-toplevel`. If there is no git repo, fall back to `cwd`.

Save to: `<repo-root>/.local/handoffs/<YYYY-MM-DD>-<HHMM>-<slug>.md`

- `<slug>` is a kebab-case summary of the next session's focus (from the user's argument), ASCII only, max ~40 chars
- Bump `-2`, `-3`... if the filename is taken
- Create `.local/handoffs/` if it does not exist
- File contents = body only. No YAML frontmatter, no "handoff document" wrapper heading

## Content

**Write for a fresh agent that has ZERO prior context.** They have not seen any of this conversation. Every commit hash, file path, plugin name, PR number you mention must be accompanied by enough plain-language explanation that a stranger can decide whether it matters. If you write `PR #2`, also say what PR #2 was about. If you write `dd9faff`, also say what that commit did and why it matters now. If you write `resurrect`, also say what it is and why we care.

A good handoff reads like a short briefing memo, not a reference card for yourself. Bullet points are fine, but they must carry meaning, not just labels.

Tailor the doc to the next session's focus when the user supplies one as the argument. Otherwise write a general handoff.

Required sections, in this order:

1. **Context** — One or two short paragraphs. What is this project, who is the user, what is the multi-session arc this handoff sits inside. If the work has spanned days, say so and summarize the journey. This is the section the new agent reads first and the one you are most likely to under-write — err on the side of saying more here.
2. **Goal** — One sentence on what the next session needs to accomplish, in plain language.
3. **Current state** — Branch, commits not yet pushed, uncommitted changes, anything blocked or waiting. Spell out *what each item represents*, not just its name.
4. **What we resolved** — Bugs investigated and fixed during the session, with one-paragraph each: symptom, what was ruled out, root cause, fix. This prevents the next agent from re-investigating dead ends you already eliminated.
5. **Open decisions** — Things genuinely unresolved that the next agent must decide or get user input on.
6. **Files / paths** — The load-bearing files the next agent will touch, each with a one-line note on what it does. Include line numbers only when truly load-bearing.
7. **Skills to invoke** — Name skills (e.g. `python`, `gh-grep`, `context7`) and say *why* each is relevant for the next session, not just that it exists.

Do NOT duplicate content that already lives in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL — but always with a one-line summary of what they say, so the next agent doesn't have to open them just to find out the topic.

Length target: long enough that a fresh agent can act after one read, short enough to read in 2-3 minutes. If you find yourself listing names without explanation, expand them. If you find yourself re-transcribing the conversation, cut.

## After saving

Report the saved path back to the user as a single line.
