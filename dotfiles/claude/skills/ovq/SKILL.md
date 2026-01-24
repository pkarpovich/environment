---
name: ovq
description: Query Obsidian vault files by frontmatter properties using Dataview-style syntax. Use when user asks to find notes in their Obsidian vault, search for files with specific properties, or filter notes by metadata (tags, status, dates, categories, projects, etc.). Triggers on phrases like "find notes where", "search vault for", "which notes have", "find meetings", "find projects with status".
---

# ovq - Obsidian Vault Query

Query markdown files by YAML frontmatter properties using Dataview-style syntax.

## Quick Start

```bash
ovq --vault "/path/to/vault" 'status = "active"'
```

Set `OVQ_VAULT` environment variable to skip `--vault` flag.

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

1. Use ovq to find matching files
2. Read relevant files to get content
3. Process or summarize as needed

## Matching Behavior

- Field names: case-insensitive (`Status` matches `status`)
- String values: case-insensitive
- Obsidian links: `[[Link]]` normalized to `Link` for comparison
