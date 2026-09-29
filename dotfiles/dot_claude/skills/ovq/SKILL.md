---
name: ovq
description: Query Obsidian vault files by frontmatter properties using Dataview-style syntax, AND discover what property names and values actually exist in the vault. Use when the user asks to find notes, search the vault, or filter notes by metadata (tags, status, dates, categories, projects). ALSO use proactively before writing or editing a vault note when the canonical schema is not 100% certain: run `ovq --values <field> --count` to discover real category and property values, and run a `categories contains` query plus read 1-2 sample files to confirm property names before assuming them. Triggers include "find notes where", "search vault for", "which notes have", "find meetings", "find projects with status", and any agent task that touches Obsidian frontmatter on a vault you do not own.
---

# ovq - Obsidian Vault Query

Query markdown files by YAML frontmatter properties using Dataview-style syntax.

## Quick Start

```bash
ovq --vault "/path/to/vault" 'status = "active"'
```

Set `OVQ_VAULT` environment variable to skip `--vault` flag.

## Discovery: what actually exists in the vault

Before writing queries (or new notes) on an unfamiliar vault, use the value-listing modes to learn the canonical property names and value enums. This is the single most useful agent move when you are about to touch frontmatter you did not write yourself.

```bash
ovq --values categories --count       # all categories with file counts
ovq --values status --count           # all status values that actually appear
ovq --values tags --count             # tag inventory
ovq --values genre --count            # genre vocabulary used in media notes
```

Use this to:

- Find the **real spelling** of a category (`Project Notes` vs `Projects`, `TV Shows` vs `Shows`).
- Discover the **value enum** for a property (what actually fills `status`? `watched`, `backlog`, `wishlist`, ...).
- Spot **drift and typos** (one note with `status: watche` next to 50 notes with `watched`).
- Decide whether a property is **load-bearing** at all (zero non-empty values = nobody uses it).

After you know the universe, write the query.

## Query Syntax

### Comparison Operators

```bash
ovq 'status = "active"'          # String equality
ovq 'priority > 2'               # Numeric comparison
ovq 'created >= 2024-01-01'      # Date comparison
ovq 'done = true'                # Boolean
```

Operators: `=`, `!=`, `>`, `<`, `>=`, `<=`

### Contains (Arrays and Substrings)

```bash
ovq 'tags contains "project"'        # Array membership
ovq 'categories contains "Meetings"' # Check category
ovq 'title contains "sync"'          # Substring match
```

### Existence Checks

```bash
ovq 'due'                # Property exists and is truthy
ovq '!due'               # Property missing or falsy
ovq 'due != null'        # Property exists (any value)
ovq 'due = null'         # Property is missing
```

### Boolean Logic

```bash
ovq 'status = "active" AND priority > 2'
ovq 'status = "done" OR status = "archived"'
ovq '(type = "note" OR type = "doc") AND published = true'
```

### Value Types

- Strings: `"quoted"`
- Numbers: `42`, `3.14`
- Booleans: `true`, `false`
- Dates: `2024-01-15`
- Null: `null`

## Common Patterns

### Find by Category

```bash
ovq 'categories contains "Meetings"'
ovq 'categories contains "Projects"'
ovq 'categories contains "Project Notes"'
```

### Find by Tag

```bash
ovq 'tags contains "work"'
ovq 'tags contains "urgent" AND status != "done"'
```

### Find by Project

```bash
ovq 'project = "ProjectName"'
ovq 'project contains "Graph"'
```

### Combined Queries

```bash
# Meetings for a specific project
ovq 'categories contains "Meetings" AND project = "ProjectName"'

# Active tasks with due dates
ovq 'status = "active" AND due'

# Recent notes
ovq 'created >= 2024-01-01'

# Notes missing a property
ovq 'categories contains "Meetings" AND !date'
```

## Workflow

When the property names and value enums are already known:

1. Use ovq to find matching files
2. Read relevant files to get content
3. Process or summarize as needed

When you do not know the schema yet (new vault, new property, drafting a note in a category you have not touched before):

0. **Discover first.** `ovq --values <field> --count` to see what values exist. For a category-keyed property, also run `ovq 'categories contains "<Category>"'` and read 1-2 of the returned files to see the real frontmatter shape.
1. Then proceed with steps 1-3 above.

Skipping step 0 leads to inventing property names that no `.base` view actually filters on, which silently drops the note from the user's existing dashboards.

## Matching Behavior

- Field names: case-insensitive (`Status` matches `status`)
- String values: case-insensitive
- Obsidian links: `[[Link]]` normalized to `Link` for comparison
