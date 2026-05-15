---
name: skill-audit
description: Audit one or more Claude Code skills against best practices and report violations. A Python script runs mechanical checks (1024-char description limit, name format and dir match, frontmatter required fields, body 500-line target, ASCII hyphens, bilingual trigger padding, reference-file ToC, allowed-tools syntax). The model adds semantic checks on top (what + when, negative cases, concrete triggers, progressive disclosure, sibling-skill coordination). Use when the user asks to audit, check, review or validate a skill, before adding a new skill to the dotfiles, or before committing changes to an existing skill. Also activate when asked HOW to write a good skill, what fields to use, when to split into references/, or about the 1024-char description limit, the bilingual-padding pitfall, or the progressive-disclosure pattern.
allowed-tools: Read, Bash(python3:*), Bash(ls:*), Bash(find:*), Glob, Grep
---

# skill-audit

Audit Claude Code skills against the conventions captured in `references/rules.md`. Combines a deterministic script for mechanical checks with model-side semantic review.

## Usage

The script runs without loading its source into context. Always invoke via Bash, do not Read the script body:

```bash
python3 ~/.claude/skills/skill-audit/scripts/audit.py <path>
```

`<path>` can be:
- a single skill directory (the one containing `SKILL.md`)
- a parent directory containing many skills (audits all of them)
- omitted -> uses the current directory

Add `--json` for machine-readable output if you need to post-process.

## Workflow

1. Run the script on the target path. Capture stdout.
2. Pass the script report through to the user, grouped as written. Do not paraphrase rule names or counts.
3. Add a "Semantic review" section with the checks the script cannot make (see below). Only include this section for the skill(s) the user is actively working on, not the full inventory, otherwise the report bloats.
4. For each FAIL or WARN, propose a concrete fix in one short bullet. Do not edit files automatically. If the user wants the fix applied, do it as a separate step.

## Semantic checks the script cannot make

Read each subject SKILL.md after the script runs and check:

- **Right place at all?** Is this content actually skill-shaped, or does it belong in a different Claude Code primitive? Always-on rules belong in CLAUDE.md. Event-driven side effects belong in hooks. Isolated multi-step work belongs in a subagent. Repeated external-tool calls belong in MCP. A skill that reads as "Claude should always do X" is in the wrong place. See `references/rules.md` "Is this even a skill" for the full split.
- **What + when**: does the `description:` answer both *what the skill does* and *when Claude should invoke it*? Either alone is not enough.
- **Negative cases**: does the description spell out when the skill should NOT trigger? This is the highest-leverage way to keep skills from over-firing.
- **Concrete triggers**: are the example phrases real things a user would actually type ("create a release", "I bought sneakers") rather than abstract concepts ("automation", "media management")?
- **Progressive disclosure**: if the body is more than ~300 lines, is detail split into `references/` files referenced from SKILL.md, so the model only loads what is needed for the current invocation?
- **Scripts loaded, not read**: if the skill ships scripts in `scripts/`, does SKILL.md instruct the model to RUN them rather than READ them? Loading the script body defeats the "execute, only output consumes tokens" benefit.
- **Composability with sibling skills**: does this skill overlap with another (e.g. `obsidian-vault` vs `lego-cubes-prep`)? If yes, does the description name the sibling and tell Claude when to defer?

## Default audit target

When the user says "audit our skills" without naming a path, assume the dotfiles tree:

```
~/.claude/skills/         # symlinked from dotfiles/claude/skills/
```

Use the dotfiles path directly when editing fixes, because `~/.claude/skills/` is read-only via symlink.

## When NOT to invoke this skill

- Editing or improving an existing skill's behaviour (use direct file edits).
- Creating a brand-new skill from scratch (use `skill-creator`, then run this skill on the result before committing).
- Generic markdown linting unrelated to Claude skills.
