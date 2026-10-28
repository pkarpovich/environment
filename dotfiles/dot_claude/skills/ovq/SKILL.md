---
name: ovq
description: Query the Obsidian vault by frontmatter with the ovq CLI (Dataview WHERE syntax), and list the property names and values the vault really uses. Use when asked to find or filter notes by metadata ("find notes where", "which notes have", "find meetings for project X"), and before writing or editing a note's frontmatter, to confirm the real category spelling and value set. Note creation itself is obsidian-vault.
---

# ovq

The vault is `/Users/pavel.karpovich/Obsidian/PK Workspace`. Pass it as `--vault` or set `OVQ_VAULT`. Output is one vault-relative path per line.

```bash
ovq --vault "/Users/pavel.karpovich/Obsidian/PK Workspace" 'categories contains "Meetings" AND project = "Tuclaw"'
```

## Discover before you write

A note whose frontmatter does not match the vault's spelling drops out of every `.base` view. Before adding or editing frontmatter in a category you have not touched this session:

```bash
ovq --values categories --count     # real category names with counts, e.g. [[Movies]]: 83
ovq --values status --count         # the value set a property really uses
ovq 'categories contains "Movies"' | head -3   # then read two of these for the frontmatter shape
```

Categories are stored as wikilinks (`[[Movies]]`), the query matches them with or without brackets.

## Query syntax

```bash
ovq 'status = "active"'              # =, !=, >, <, >=, <=
ovq 'created >= 2026-01-01'          # dates unquoted, YYYY-MM-DD
ovq 'done = true'
ovq 'tags contains "work"'           # array membership or substring
ovq 'due'                            # property present and truthy
ovq '!due'                           # missing or falsy
ovq 'due != null'                    # present with any value
ovq 'status = "active" AND (priority > 2 OR tags contains "urgent")'
```

Field names and string values match case-insensitively.

## Output modes

```bash
ovq --fields title,status,due 'status = "active"'   # path plus the fields as TSV, no file reads needed
ovq --json 'categories contains "Movies"'            # [{"file": ..., "frontmatter": {...}}]
ovq 'categories contains "Movies"' | ovq --stdin 'year > 2020'   # filter a piped path list
```

Use `--fields` when the answer is a table, `--json` when a script consumes it, and Read only for the body of a note.
