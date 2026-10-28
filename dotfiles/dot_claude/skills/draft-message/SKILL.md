---
name: draft-message
description: Draft a Slack, email or chat message, show it in chat first, and save it to <repo-root>/.local/messages/ only after approval. Use when asked to "draft a message", "write to <person> about", "slack <person>", "send <person> a message", in any language. Earlier saved messages in that folder set the house style.
argument-hint: "<topic>"
---

# Draft Message

Help the user compose short messages and archive approved drafts to `.local/messages/`.

## Storage

Path: `<repo-root>/.local/messages/`. Flat layout. Each saved file contains the message body as plain text - no YAML frontmatter, no headings, no wrappers. Just the body that was sent.

The repo root is `git rev-parse --show-toplevel`, not cwd, so a monorepo keeps one folder. Without a git repo, cwd.

## Before drafting: learn the house style

Messages already in `.local/messages/` were written for this audience and got sent, so they beat the default style below. Before drafting:

1. List `.local/messages/`. Empty or missing: use the Style section below.
2. If files exist, read 1-3 of the most recent. Note their:
   - Greeting convention (often none in internal team channels)
   - Structure (flat prose vs. heavy markdown headings)
   - Tone (formal vs. casual, slang, emoji density)
   - Level of assumed context (do they explain terms or assume the audience knows?)
3. Match that tone and structure. A file the user names ("look at X.md, that's the style") wins over the rest.

## Flow

1. **Parse intent.** Extract topic and audience. Ask if essential facts are missing - do not fabricate numbers, names, links, or quoted claims.
2. **Load style context.** Read prior messages in `.local/messages/` per the section above.
3. **Draft in chat.** Plain markdown, nothing saved yet.
4. **Wait for review.** User approves ("ок" / "save" / "норм" / "go"), requests edits, or rejects. On edits, revise and loop to step 3.
5. **On approval, save.** Path: `<git-root>/.local/messages/<YYYY-MM-DD>-<slug>.md`. Date from the current-date reminder. Slug = kebab-case of the topic, ASCII only, max ~40 chars. Bump `-2`, `-3`... if the filename is taken. File contents = body only.
6. **Report.** One line with the saved path.

## Style

Default when no prior examples exist. House style from step 2 always wins.

### Structure - flat, not nested

A team message is flat prose with short labels before code blocks, not a doc with bold section headers. The shape:

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

No `# H1` or `## H2` headings and no bold-only "**Проблема** / **Решение**" labels unless the house style has them.

### The opening sentence

It announces the change or proposal and names why it matters, in one connected thought. The rest of the message is detail, not setup.

<example>
Good:

```
Добавил `featureFlag` в `/config/user` - по нему FE решает, показывать ли новый интерфейс.
```

Bad, two disconnected thoughts:

```
Добавил `featureFlag` в `/config/user`.

Напомню: `tier: "free"` - базовый план, `tier: "pro"` - платный, `tier: "enterprise"` - корпоративный. `featureFlag` работает только для `pro` и выше.
```
</example>

Two sentences are fine when they carry one idea.

### Audience context

Background ("раньше было X", "проблема в том что Y") goes in only when the audience lacks it. An internal channel that took part in the discussion starts from the delta.

### Labels before code blocks

Short, descriptive, parallel: the same grammatical case across sibling blocks.

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

Corrections that came up repeatedly, so they do not get written in the first place:

- **Greetings** ("Привет 👋", "Hey team") - unless the house style actually uses them. Internal team channels where everyone already talks daily rarely do.
- **"Проблема / Решение" headers** when the audience already has context. Start from the delta.
- **Invented collective agreements** - "договорились", "команда решила", "обсудили и выбрали" only when something was agreed.
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

- The draft goes to chat first and is saved only on explicit approval.
- Numbers, names, links and quoted opinions come from the user. Missing ones are asked for, not invented.
- An existing file is never overwritten, the suffix is bumped.
- Saved file = body only. No frontmatter, no heading wrappers, no "draft N" markers, no notes about how it was constructed.
