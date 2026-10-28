---
name: skill-audit
description: Audit a Claude Code skill against the current skill docs and the Claude 5 prompting guidance, then report what to fix. A script checks the mechanics (frontmatter fields, description and listing caps, body length, ASCII hyphens, emphatic wording, reference files), the model reviews the substance (what and when, negative cases, progressive disclosure, overlap with sibling skills, whether it should be a skill at all). Use when asked to audit, check, review or validate a skill, before adding a skill to the dotfiles, and when asked how to write a skill or which frontmatter fields exist. Not for writing a skill from scratch (skill-creator) or for general markdown linting.
allowed-tools: Read, Bash(python3:*), Bash(ls:*), Bash(find:*), Glob, Grep
---

# skill-audit

Rules and their reasons are in `references/rules.md`. Read it when a finding needs explaining or when the question is how to write a skill.

## Usage

Run the script, do not read its source:

```bash
python3 ~/.claude/skills/skill-audit/scripts/audit.py <path>
```

`<path>` is one skill directory, a directory of skills, or omitted for the current directory. `--json` gives machine-readable output. The dotfiles tree is `~/Projects/environment/dotfiles/dot_claude/skills/`, edit there, `~/.claude/skills/` is symlinks.

## Workflow

1. Run the script and pass its report through unchanged.
2. Read the subject SKILL.md and add a "Semantic review" section with the checks below. Do this only for the skills under discussion, not a whole inventory.
3. For each finding, one bullet with the concrete fix. Edit only when asked.
4. For usage data, `/skill-doctor` in an interactive session shows each skill's context cost and invocation count.

## Semantic review

- **Right primitive.** Always-on rules belong in CLAUDE.md, reactions to events in hooks, isolated work in a subagent, external calls in MCP. A skill that reads "always do X" is in the wrong place.
- **What and when.** The description says what the skill does and when to use it, in that order, key use case first. The listing cuts `description` plus `when_to_use` at 1,536 characters.
- **Negative cases.** The description says when not to use the skill, naming the sibling that takes those cases.
- **Concrete triggers.** Phrases a user types ("cut a release", "I bought sneakers"), not topics ("automation").
- **File-scoped skills use `paths`.** A skill that applies to a file type (a language style guide) sets `paths` instead of listing file extensions as triggers.
- **Manual workflows opt out of auto-invocation.** A deploy or release flow sets `disable-model-invocation: true`. Background knowledge sets `user-invocable: false`.
- **Standing instructions.** Once invoked, the body stays in context for the rest of the session. Every line is a recurring cost. State what to do, not why, and drop what Claude already knows.
- **No emphatic wording.** "Use when" instead of "CRITICAL: you MUST". Claude 4.5 and later overtrigger on emphasis.
- **One default.** One recommended tool or approach with an escape hatch, not a menu.
- **Progressive disclosure.** Detail lives in `references/`, linked one level deep from SKILL.md, under 500 lines in the body. Scripts are run, never read.
- **No dates.** No "before X use the old API". A current method and an old-patterns section instead.
- **Consistent terms.** One word for one thing throughout.
- **Sibling overlap.** When two skills could take the same request, the more specific one names the general one and says who defers.
