# Skill-audit rules

The reasoning behind each check `audit.py` runs, and the matching semantic checks the model layers on top. Load this file only when the user asks WHY a rule exists, or when authoring a brand-new skill from scratch and wants the full picture.

## Is this even a skill?

Before checking any specific field, decide whether the content should be a skill at all. Claude Code has five customisation primitives and they cover non-overlapping shapes of work:

- **CLAUDE.md** loads into every conversation. Use for **always-on** standards: project-wide style, never-do constraints, framework preferences, environment facts that hold no matter the task.
- **Skill** loads on demand when the model matches the description. Use for **task-specific expertise** that would clutter the context window if always present: a PR review checklist, a release workflow, a vault grammar.
- **Hook** fires on harness events (file save, pre-tool-call, etc.). Use for **event-driven side effects**: run a linter, validate an input, ping a notifier. Hooks are not knowledge, they are reactions.
- **Subagent** runs in an isolated context, returns a result. Use for **work that must not pollute the main conversation**: deep multi-step research, parallel branches of investigation.
- **MCP server** exposes external tools to the model. Use when you need to **call an outside service**: a database, a SaaS API, a private knowledge base.

Smells that suggest the content is in the wrong primitive:

| Symptom in a skill | Probably belongs in |
|---|---|
| Description reads "Claude should always X" / "in every project X" | CLAUDE.md |
| Description reads "on every save", "after each commit", "before any tool call" | a hook |
| Body says "work in isolation", "do not touch main context", "spawn a separate agent" | a subagent |
| Body is mostly "call this API repeatedly with these parameters" | an MCP server |
| Body lists style or naming conventions that apply to ALL of a language | CLAUDE.md (project) or a skill that triggers on file type |

The audit's mechanical hint for this is the `description-no-trigger` warning: if the description has no `when`/`trigger`/`use this when` language, the content is either a badly-described skill or an always-on rule masquerading as one. The model should decide which.

## Frontmatter

### `name` (required)

- Lowercase letters, digits, hyphens only. Max 64 characters.
- Must match the directory name. Mismatched names silently fail to load on some Claude Code versions.

### `description` (required, max 1024 chars)

The single most important field. The model uses it to decide whether to consult the skill at all. Two non-negotiable jobs:

1. State what the skill does in one tight sentence.
2. State when the skill should be invoked, with concrete trigger phrases the user is likely to actually type.

A third highly useful job: state when the skill should NOT be invoked. This is the most reliable way to keep skills from over-firing on adjacent topics.

The 1024-char limit is enforced by the standard. Over-the-limit descriptions risk truncation. Tight descriptions are also easier for the model to weigh against sibling skills.

**Anti-pattern: bilingual trigger padding.** Listing the same trigger phrase in English and Russian (or any two languages) does not improve recall; the model matches intent across languages already. The duplication just spends the 1024-char budget. Keep examples in one language, ideally English. Load-bearing non-English content in the body (style examples, real titles, vocabulary the skill is supposed to produce) is fine and should stay.

### `allowed-tools` (optional)

Restricts which tools Claude can use while the skill is active. Use for read-only or scope-limited skills:

```yaml
allowed-tools: Read, Grep, Glob, Bash(curl:*)
```

When set, the listed tools run without permission prompts. Omitting the field keeps the normal permission model. Specifying tool patterns (e.g. `Bash(curl:*)`) further restricts which subcommands are allowed.

### `model` (optional)

Pins a specific Claude model when the skill is active. Rarely needed; useful when:

- A skill performs cheap formatting and can run on `haiku` to save cost.
- A skill performs deep multi-step review and benefits from `opus`.

Most skills should leave this unset and inherit the session model.

## Body shape

### Length

Aim for a SKILL.md body under 500 lines. The body is loaded whenever the skill activates, so long bodies waste tokens on every invocation.

Move detail into `references/<topic>.md` and link from the body with a short pointer like `see references/api_reference.md`. The model loads reference files only when the active task needs them.

### Progressive disclosure

Three standard subdirectories:

- `scripts/` for executable code. The body should instruct the model to RUN scripts, not READ them. Scripts execute without their source consuming context; only the script's stdout/stderr does.
- `references/` for additional documentation loaded on demand.
- `assets/` for templates, images, or fonts used in output.

### ToC for large reference files

Once a single reference file passes ~300 lines, the model has trouble finding the relevant section without a table of contents at the top. Add either a literal `## Table of contents` block or enough `## section` headers near the top that the model can navigate by scanning the first 20 lines.

## Project conventions

These are layered on top of the Anthropic standard for Pavel's dotfiles.

### ASCII hyphens

Project convention is plain ASCII `-` everywhere, including in SKILL.md content. No em-dash (`—`, U+2014), no en-dash (`–`, U+2013). The audit flags these as warnings rather than failures because they do not break the skill, only the project style guide.

### English text in description and triggers, non-English content in body when load-bearing

Description and "Invocation triggers" sections are model-facing routing metadata; keep them in English. Examples, real titles, voice references, anything the skill is supposed to REPRODUCE in non-English output: keep in the source language. Mixing the two purposes inflates the description and drains the 1024-char budget.

### Sibling-skill overlap

When two skills could plausibly handle the same request, the more-specific skill should name the more-general one and tell Claude when to defer. Example: `lego-cubes-prep` is more specific than `obsidian-vault`. Both deal with Obsidian notes, so `obsidian-vault` explicitly says "defer Lego Cubes episodes to `lego-cubes-prep`".

## Semantic checks (model-side, not in the script)

After the script reports, also verify:

1. **What + when**: the description states both what the skill does and when to invoke it. Either alone is insufficient.
2. **Negative cases**: the description spells out when the skill should NOT trigger.
3. **Concrete triggers**: trigger phrases are real things a user would type, not abstract concepts.
4. **Progressive disclosure depth**: if the body is over ~300 lines, detail should be in `references/`, not inline.
5. **Scripts run, not read**: SKILL.md instructs the model to invoke scripts via Bash, not Read their source.
6. **Sibling-skill coordination**: skills that overlap with other skills name them explicitly and define which wins.
