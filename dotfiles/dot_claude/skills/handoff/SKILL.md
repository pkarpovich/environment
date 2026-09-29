---
name: handoff
description: Capture the full state of the current session into a handoff document so a fresh agent can pick up cold with zero loss of context. Not a summary, not a brief; an exhaustive record of every task tackled (what we did, why we did it, how we did it), every user preference learned, every unresolved decision, and every loose end. Use when the user says "handoff", "save session", "checkpoint", "session snapshot", "next agent will continue", "wrap up the session", "hand off the context", or when wrapping up a multi-topic session and the next conversation needs the full picture. Saves to `<repo-root>/.local/handoffs/` so the doc lives with the project and survives across sessions. SKIP for short single-task sessions where the artifacts (commits, PRs, file edits) already carry the whole story - handoff only earns its keep when the session contains material that lives only in the conversation (decisions, dead ends ruled out, user corrections, preferences learned).
argument-hint: "What will the next session be used for?"
---

Write a full handoff document covering everything that happened in the current session. The goal is that a fresh agent, opened in a brand-new conversation with this file as their only input, can continue the work without needing the user to re-explain anything.

## Storage

Resolve the repo root with `git rev-parse --show-toplevel`. If there is no git repo, fall back to `cwd`.

Save to: `<repo-root>/.local/handoffs/<YYYY-MM-DD>-<HHMM>-<slug>.md`

- `<slug>` is a kebab-case summary of the next session's focus (from the user's argument). ASCII only, max ~40 chars.
- Bump `-2`, `-3`... if the filename is taken.
- Create `.local/handoffs/` if it does not exist.
- File contents = body only. No YAML frontmatter, no "handoff document" wrapper heading.

## Mindset

**Write for a fresh agent that has ZERO prior context.** They have not seen any of this conversation. Every commit hash, file path, plugin name, PR number, person's name must be accompanied by enough plain-language explanation that a stranger can decide whether it matters. If you write `PR #2`, also say what PR #2 was about. If you write `dd9faff`, also say what that commit did and why it matters now. If you write `resurrect`, also say what it is and why we care.

**Completeness wins over brevity.** This is not a 2-minute briefing. There is no upper bound on length. If you find yourself listing names without explanation, expand them. If you find yourself transcribing trivial back-and-forth, cut it - but keep every load-bearing exchange. The cost of a too-long handoff is one extra minute of reading; the cost of a too-short one is the next agent re-doing work, asking the user to repeat themselves, or charging into a dead end you already ruled out.

**Capture knowledge that lives only in the conversation.** Commits, diffs, PRs, issues already document themselves. The point of a handoff is everything that does NOT - why a particular approach was chosen over alternatives, what the user pushed back on, what they corrected, what they revealed about their preferences, what we tried and rejected, what we noticed but did not act on.

## Required sections, in this order

### 1. Context

One or two paragraphs. What is this project, who is the user, what is the multi-session arc this handoff sits inside. If the work has spanned days, say so and summarise the journey so far. Mention any conventions or constraints the next agent must respect from minute one (e.g. ASCII-only hyphens, never-commit-without-explicit-ask, Russian-language podcast, kepano vault style). This is the section the new agent reads first and the one you are most likely to under-write - err on the side of saying more here.

### 2. Tasks in this session

**This is the heart of the document.** Allocate the most space here.

For every distinct task tackled in the session, write a sub-section with three things:

- **What we did** - concrete actions, files touched, commands run, decisions made. Include enough detail that the next agent can reproduce or extend the work without guessing. Quote the user's actual ask verbatim if it was load-bearing.
- **Why we did it** - the motivation. What problem was it solving? What did the user say or notice that kicked it off? What alternative approaches did we consider and reject, and on what grounds? This is where the conversation-only knowledge goes - without it, the next agent will re-litigate decisions you already settled.
- **How we did it** - the specific approach, the order of operations, the diagnostic steps, the dead ends ruled out. If a bug was investigated, walk through: symptom -> things ruled out -> root cause -> fix. If a skill was written, walk through: goal -> draft -> user corrections -> final structure.

Cover every task, even small ones. If we touched four distinct topics in this session, the document has four sub-sections in this section. Do NOT collapse them into a single narrative - they are independent threads and may resume independently.

### 3. What's left

Concrete unfinished items from this session. Each item is a single line that names the artifact and what state it is in. Examples:

- `worktree fix-wezterm-ssh-prefix` - kept on disk, awaiting user verification of the SSH tab tint before merge or removal
- `skill-audit` commits sit in `worktree-add-skill-audit`, not cherry-picked to master yet
- Three skill descriptions still over the 1024-char limit (defuddle, lego-cubes-prep, obsidian-vault), known fix path documented above

Distinguish this from Open decisions (next section) - items here have a clear next action; items there need a real human choice first.

### 4. Open decisions

Things genuinely unresolved that the next agent must get user input on before proceeding. State the question, name the options, and (if appropriate) flag your own recommendation with the reasoning. Empty section is fine if there are no open decisions.

### 5. User preferences captured this session

Things the next agent should know about the user that emerged DURING this session. New rules, new corrections, new clarifications of existing rules. Quote the user verbatim where the wording is load-bearing. Examples:

- "Pavel uses 1-10 rating in his Obsidian vault, NOT the kepano 1-7 scale; do not invent ratings."
- "Pavel wants English-only in skill descriptions; non-English content in bodies is fine when load-bearing."
- "Mail.app rules: re-selecting the same dropdown option does not register as a change. Double-toggle (pick a different mailbox, save, pick the target) is required for the edit to push to iCloud."

Skip preferences already documented in `~/.claude/CLAUDE.md` or project CLAUDE.md - only capture deltas.

### 6. Verification steps

Concrete commands or checks the next agent should run before assuming the session state is still valid. The user's environment, git state, server state, daemons, etc. may have changed since this file was written. Examples:

- `cd ~/Projects/environment && git status` - confirm the three unpushed commits and clean tree still match what is recorded above
- `python3 ~/.claude/skills/skill-audit/scripts/audit.py ~/.claude/skills/` - confirm `3 fail / 18 warn / 2 info` baseline before judging any new violations
- `wezterm cli list --format json` - confirm an SSH tab is open before testing the prefix fix

Verification steps should be cheap and read-only.

### 7. Notes for future me

Things noticed during the session but not acted on. Potential traps, follow-ups too small to be tasks, observations that might matter later. The next agent should treat these as "be aware" rather than "do these". Examples:

- The `OOO Request to trash` rule matches body containing "OOO Request" but current emails use "OOO notification" - criterion is stale even after the destination ID fix.
- `agent-browser` brew formula pulls in node 26 as a transitive dependency despite marketing "no Node.js required for the daemon".
- `Journal/` folder in the Obsidian vault is empty - Pavel writes journal entries in the vault root, the folder could be deleted but he did not ask.

## Length

No upper limit. Stop when every load-bearing exchange is captured and the next agent can act without asking. Stop sooner only if you find yourself transcribing trivial chatter.

## After saving

Report the saved path back to the user as a single line.
