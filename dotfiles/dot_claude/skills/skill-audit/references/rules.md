# Skill-audit rules

Why each check exists. Sources: the Claude Code skills reference (code.claude.com/docs/en/skills), the Agent Skills best practices (platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) and the Claude 5 prompting pages (Opus 5.5, Fable 5.1, general best practices). Checked against the docs on 2026-10-27.

## Is this a skill at all

Claude Code has five primitives and they do not overlap:

- CLAUDE.md loads into every conversation. Always-on rules: style, never-do constraints, environment facts.
- Skill loads when the model matches the description, or when the user types `/name`. Task-specific expertise that would clutter every session.
- Hook fires on harness events. Side effects: run a linter, ping a notifier. Not knowledge.
- Subagent runs in isolated context and returns a result. Work that must not pollute the main conversation.
- MCP server exposes an outside service as tools.

| Symptom in a skill | Belongs in |
|---|---|
| "Claude should always X", "in every project X" | CLAUDE.md |
| "on every save", "after each commit", "before any tool call" | a hook |
| "work in isolation", "spawn a separate agent" | a subagent, or `context: fork` |
| "call this API with these parameters" | an MCP server |
| conventions for a whole language | a skill with `paths`, or project CLAUDE.md |

The script's `description-no-trigger` warning is the mechanical hint: a description with no "when" is either badly described or an always-on rule.

## Frontmatter

All fields are optional. A field name Claude Code does not recognize is ignored silently, so a typo (`allowed_tools`, `when-to-use`) costs the field. The script flags unknown names.

| Field | What it does |
|---|---|
| `name` | Command name in the `/` menu. Defaults to the directory name. Lowercase, digits, hyphens, max 64. |
| `description` | What the skill does and when to use it. Key use case first. |
| `when_to_use` | Extra trigger context, appended to the description in the listing. |
| `argument-hint` | Autocomplete hint such as `[issue-number]`. |
| `arguments` | Named positional arguments for `$name` substitution. |
| `disable-model-invocation` | `true`: only `/name` runs it. For deploy, release, destructive workflows. |
| `user-invocable` | `false`: hidden from the `/` menu, only Claude loads it. For background knowledge. |
| `allowed-tools` | Tools that need no permission prompt during the invoking turn. |
| `disallowed-tools` | Tools removed while the skill is active, such as `AskUserQuestion` in a loop. |
| `model`, `effort` | Override for the rest of the turn. |
| `context: fork`, `agent`, `background` | Run the skill in a subagent. |
| `hooks` | Hooks registered when the skill is invoked. |
| `paths` | Globs. The skill loads automatically only for matching files. |
| `license`, `compatibility`, `metadata` | Agent Skills spec fields, Claude Code stores them and does nothing. |

Outside Claude Code (claude.ai upload, Skills API, Zed through the same `~/.agents` store) only `name`, `description`, `license`, `compatibility`, `metadata` and `allowed-tools` are valid, and any other field is a hard error on upload. A skill that must travel stays within those six.

### Description

The one field the model reads for every skill on every turn. Two jobs, in this order: what the skill does, then when to invoke it with phrases a user would type. A third job that pays most: when not to invoke it, naming the sibling that takes those cases.

Caps: Claude Code truncates `description` plus `when_to_use` at 1,536 characters in the listing, so put the key use case first. The Agent Skills spec caps `description` at 1,024, and a skill that is uploaded anywhere else must fit that. The script fails over 1,536 and warns over 1,024.

Do not pad with the same trigger in two languages. The model matches intent across languages. Non-English text that the skill must reproduce (titles, voice, vocabulary) belongs in the body.

Do not list file extensions as triggers for a language skill. Set `paths` and the skill loads when such a file is in play.

### Name

Lowercase, digits, hyphens. Gerund or noun phrase that says what the skill does (`processing-pdfs`, `skill-audit`), never `helper`, `utils`, `tools`. Match the directory name: the directory name also invokes the skill, and a mismatch gives two commands for one skill.

## Body

### It stays in context

An invoked skill enters the conversation as one message and stays there across every later turn. Claude Code does not re-read the file. Two consequences:

- Write standing instructions, not one-time steps. "Keep commit messages under 72 columns" holds for the session. "First, read the config" runs once and then sits there.
- Every line is a recurring token cost. State what to do, not why. Assume Claude already knows the language, the tool and the common patterns, and keep only what it does not have: this project's conventions, this tool's quirks, the decision rules.

Under 500 lines. Detail goes to `references/<topic>.md`, linked directly from SKILL.md, one level deep: a reference that points to another reference gets read with `head -100` and the tail is lost. A reference over 300 lines gets a table of contents at the top.

After compaction Claude Code re-attaches the first 5,000 tokens of each invoked skill, within a shared 25,000-token budget. Put the rules that must survive a long session near the top.

### Claude 5 wording

The Claude 5 models follow instructions more literally and more eagerly than Claude 4 did, and the prompting guidance moved with them:

- No emphatic language. "Use this when" does what "CRITICAL: you MUST use this when" did on older models, and the emphatic form now overtriggers. Same for ALL CAPS, "ALWAYS", "NEVER" as emphasis, and exclamation marks. The script counts them.
- No anti-laziness nudges. "Be thorough", "make sure to check everything", "use tools aggressively" were written for models that under-acted. Claude 5 over-acts on them.
- No anti-formatting rules for chat. Fable 5.1 already uses little bold and few lists. Say when formatting is wanted instead.
- Examples in `<example>` tags, three to five, close to the real use and different from each other, so the model separates them from instructions.
- One default with an escape hatch, not a list of options. "Use pdfplumber. For scanned PDFs use pdf2image with pytesseract."
- No dates or version cut-offs in instructions. A "current method" section and an "old patterns" section.
- One term for one thing throughout.
- Scope stated explicitly. If the skill wants more than the minimum (say, a dashboard with many interactions), it says so. If it wants less, it says what to leave out.

### Scripts

A `scripts/` file is run through Bash, never read. The body says how to call it and what the output means. The script handles its own errors and prints a usable message, it does not leave the model to guess. Paths with forward slashes.

## Project conventions

Layered on top of Anthropic's guidance for these dotfiles.

- ASCII `-` for every dash. The script warns on U+2014 and U+2013.
- Description and triggers in English. Body text in the language it must produce.
- No semicolons in prose.
- Sibling overlap is stated in the more specific skill: `lego-cubes-prep` defers nothing, `obsidian-vault` says "Lego Cubes episodes go to lego-cubes-prep".
- A skill holds the rule and an example, never Pavel's quotes.

## Measuring

Seeing a skill trigger says Claude found it, not that it helped. `/skill-doctor` shows each skill's context cost and how often it fired. For output quality, run the same prompts in fresh sessions with the skill on and off (set it to `"off"` in `skillOverrides`), and compare.
