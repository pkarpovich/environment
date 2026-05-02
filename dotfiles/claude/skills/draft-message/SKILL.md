---
name: draft-message
description: >
  Draft a Slack / email / chat message, propose it in chat first, and save
  to `<repo-root>/.local/messages/` only after the user approves. Invoke
  when the user says "draft a message", "напиши сообщение",
  "write to <person> about", "slack <person>", "сообщение в слак", etc.
argument-hint: "<topic>"
metadata:
  version: "0.0.3"
---

# Draft Message

Help the user compose short messages and archive approved drafts to `.local/messages/`.

## Storage

Path: `<repo-root>/.local/messages/`. Flat layout. Each saved file contains the message body as plain text - no YAML frontmatter, no headings, no wrappers. Just the body that was sent.

**Resolving the repo root.** Use `git rev-parse --show-toplevel` - not cwd. The user can invoke Claude from a subdir of a monorepo; messages still go under the monorepo root so they accumulate in one place. If there is no git repo, fall back to cwd.

## Before drafting: learn the house style

Existing messages in `.local/messages/` are the single best style reference for this project - they were written by this user for this audience and actually got sent. Before drafting:

1. List `.local/messages/`. If empty or doesn't exist, use the "Style" section below.
2. If files exist, read 1-3 of the most recent. Note their:
   - Greeting convention (often none in internal team channels)
   - Structure (flat prose vs. heavy markdown headings)
   - Tone (formal vs. casual, slang, emoji density)
   - Level of assumed context (do they explain terms or assume the audience knows?)
3. Match that tone and structure. If the user points you at a specific file ("look at X.md, that's the style"), treat it as authoritative.

This is the most important step. Skipping it is why drafts miss on the first try and need 4 rewrites.

## Flow

1. **Parse intent.** Extract topic and audience. Ask if essential facts are missing - do not fabricate numbers, names, links, or quoted claims.
2. **Load style context.** Read prior messages in `.local/messages/` per the section above.
3. **Draft in chat.** Plain markdown. Do NOT save yet.
4. **Wait for review.** User approves ("ок" / "save" / "норм" / "go"), requests edits, or rejects. On edits, revise and loop to step 3.
5. **On approval, save.** Path: `<git-root>/.local/messages/<YYYY-MM-DD>-<slug>.md`. Date from the current-date reminder. Slug = kebab-case of the topic, ASCII only, max ~40 chars. Bump `-2`, `-3`... if the filename is taken. File contents = body only.
6. **Report.** One line with the saved path.

## Style

Default when no prior examples exist. House style from step 2 always wins.

### Structure - flat, not nested

Real team messages are flat prose with short labels before code blocks - not docs with bold section headers. A typical shape looks like this:

```
[Opening sentence - what you did or propose AND why, in one breath.]

[Optional second sentence for scope / caveat.]

[Short label]:
```code```

[Short label]:
```code```

[Rules / format - one short paragraph.]

[Semantic list when there are 2-5 distinct cases:]
- case A → what happens
- case B → what happens

[One-line back-compat note if relevant.]

[Follow-up / next step if relevant. One paragraph.]
```

Avoid `# H1`/`## H2` headings and bold-only "**Проблема** / **Решение**" section labels unless house style uses them. They make a chat message feel like API docs.

### The opening sentence

Hardest part. It has to do two jobs at once: announce the change/proposal AND name why it matters. The rest of the message is then context and detail, not setup.

**Good** (one connected thought):
> Добавил `featureFlag` в `/config/user` - по нему FE решает, показывать ли новый интерфейс.

**Bad** (two disconnected thoughts, reads like two emails glued together):
> Добавил `featureFlag` в `/config/user`.
>
> Напомню: `tier: "free"` - базовый план, `tier: "pro"` - платный, `tier: "enterprise"` - корпоративный. `featureFlag` работает только для `pro` и выше.

If the "what" and "why" genuinely need two sentences, fine - but they must be one connected idea, not "announcement" + "unrelated lecture".

### Audience context

Before including background ("раньше было X", "проблема в том что Y"), ask: does the audience already have this context? For internal team channels where everyone participated in prior discussion, usually yes - cut the setup and start from the delta. A common user correction is "они и так знают что это будет" - anticipate it.

### Labels before code blocks

Short, descriptive, **parallel**. Match grammatical case across sibling blocks.

- Good: `В payload запроса:` / `В ответе /api/products:`
- Worse (instructional how-to tone): `Как сформировать payload запроса:` / `Что приходит в ответе /api/products:`
- Worse (overly formal): `**Формат запроса**` / `**Формат ответа**`

### Rule lists

For sets of 2-5 cases mapping input to behavior, use a dash list with `→`:

```
Что с ним делает FE:

- `view: "compact"` → компактный список
- `view: "grid"` → плиточная сетка
- `view` не задан → дефолтное представление списка
```

Order: lead with the common/known cases, then edge cases and fallbacks.

### Anti-patterns (cut on sight)

These are the corrections that came up repeatedly in past iterations. Don't write them to begin with:

- **Greetings** ("Привет 👋", "Hey team") - unless the house style actually uses them. Internal team channels where everyone already talks daily rarely do.
- **"Проблема / Решение" headers** when the audience already has context. Start from the delta.
- **Invented collective agreements** - "договорились", "команда решила", "обсудили и выбрали" - only if something was actually agreed. Writing them otherwise is fabrication.
- **Slang fillers** - "типа", "штука", "в общем", "собственно", "короче". They signal laziness, not casualness.
- **Academic openers** - "Конвенция - X", "Семантика:", "Имплементация:". Rewrite: "Формат id - X", "Что делает FE:", "Как устроено:".
- **Code-in-prose equations** - `Отсутствие X = Y`. Rewrite as a sentence or move to the dash list.
- **AI-speak** - "важно отметить", "plays a crucial role", "leverage", "comprehensive", "robust", "seamless", "streamline".
- **Closing pleasantries** - "Hope this helps", "Let me know", "Вопросы - сюда", "Feedback welcome". In a team chat they add noise.
- **Meta-commentary about the message itself** - "Вот что предлагаю" at the very top is fine (sets the frame); "Надеюсь было полезно" at the bottom is not.

### Formatting

- Preserve the user's language. Russian → Russian, English → English. Don't mix unless house style mixes.
- ASCII hyphens only. No em / en dashes.
- Inline code in backticks for identifiers, paths, field names, values.
- Code blocks with triple backticks + language tag.
- `→` inside dash lists for "case → result" mappings.
- Bold sparingly, only for true emphasis (rarely needed).

## Rules

- Always draft in chat first. Never save silently. Never save without explicit user approval.
- Do not fabricate facts (numbers, names, links, quoted opinions). Ask instead.
- Do not overwrite an existing file. Bump the suffix.
- Saved file = body only. No frontmatter, no heading wrappers, no "draft N" markers, no notes about how it was constructed.

## Invocation triggers

Russian or English, any shape:
- "draft a message about Y" / "напиши сообщение про Y"
- "slack X" / "сообщение в слак"
- "write to X about Y" / "напиши X про Y"
- Explicit `/draft-message`.

The audience mentioned in the request is used only as content inside the draft body (greeting, tone) - the skill doesn't filter or track by audience.
