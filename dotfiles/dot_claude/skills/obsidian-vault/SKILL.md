---
name: obsidian-vault
description: Create or extend notes in Pavel's Obsidian vault, PK Workspace, in its own grammar: plural wikilinked categories, YYYY-MM-DD dates, eager wikilinks, root for personal notes and References for the outside world, a 1-10 rating. Use whenever something should land in the vault, said or not: "save a note", "log this", "I watched", "I read", "I finished", "I bought", "I met", "new idea", "meeting note", "weekly note", or a bare movie, book, game, person or product to catalogue. The 19 note types and their frontmatter are in references/types.md. Lego Cubes episodes go to lego-cubes-prep. Notes with an existing structure are edited directly.
---

# obsidian-vault

Pavel's personal vault, started from kepano's template and grown into its own rules. The rules below win over assumptions.

## Vault location

```
/Users/pavel.karpovich/Obsidian/PK Workspace/
```

Sub-vault `Tuclaw/` has its own `.git` and its own conventions. Only `lego-cubes-prep` writes there.

## House rules

1. **Categories are plural and wikilinked.** `categories: [[Movies]]`, not `Movie`. The `.base` views filter on this exact spelling.
2. **Dates are `YYYY-MM-DD` everywhere.** Created, last, deadline, acquired - same shape. Time when present is `YYYY-MM-DD HH:mm`.
3. **Rating is an integer 1-10**, not kepano's 1-7. An unknown rating stays empty.
4. **Wikilink eagerly.** The first mention of a named entity in the body (person, brand, place, project, movie) becomes `[[Name]]`, target file or not. Authors, directors, casts, brands, companies and projects in the frontmatter are wikilinks too.
5. **Properties are short and reused.** The names already in the vault (`year`, `last`, `genre`, `cast`), not `release_year` or `watched_on`. A property that can hold several values (genres, attendees, cast) is a list even with one item.
6. **Personal vs Reference dichotomy.**
   - **Root of the vault** - anything Pavel writes about his own world: journal entries, ideas, meetings, project notes, tasks, evergreen thoughts, job interviews.
   - **`References/`** - things that exist outside his world: books, movies, shows, games, people, products (clothing), companies, places, recipes, podcasts. Filename is the title.
   - **`Periodic/Weekly/`** - only weekly notes.

## Workflow

Before writing a file, settle three things, from the message when it is obvious, otherwise by asking:

1. **Type** - one of the 19 in `references/types.md`. "Bought new sneakers" is a Product, "tried a new cafe" a Place, "interesting thing X said" is a Quote or an Evergreen, ask which. A Person note is a minimal scaffold, and whether someone gets one is a question for Pavel.
2. **Title** - exactly as it will appear in the filename. Movies, shows, games, books include the year in parentheses: `<Title> (YYYY).md`. Seasons add `S0N`: `<Title> S02 (YYYY).md`. Products use `<Brand> <Model> <Size>` shape.
3. **Frontmatter** - only the fields whose values are known, the rest stay empty. For media, year, director, cast and cover URL come from WebFetch or defuddle when the title is well known. Ratings, statuses and opinions come from Pavel only.

The vault is the source of truth and `references/types.md` its summary. Before writing a note of a type not touched this session, check the vault through the `ovq` skill:

```bash
ovq --values categories --count                    # confirms the real category name and how many notes use it
ovq 'categories contains "<Category>"' | head -3   # pick 2-3 sample files, read them, copy the actual frontmatter shape
```

When the sampled files and `types.md` disagree on a property name, a value set or scalar versus list, the files win, and `types.md` gets patched afterwards.

After writing, report the saved path on one line.

"Write the review" or "summarize the meeting" is a request for the content, write it. Scaffolding alone is for an unclear ask.

## Type registry

`references/types.md` holds the per-type table (folder, filename, frontmatter, examples). Read it when:
- Creating any note other than a quick idea capture in the root.
- The type's schema is not already in context.
- Adding fields to an existing note in `References/` - match the schema strictly.

## Out of scope

- Reorganizing folders. The root is flat on purpose.
- Moving existing files.
- Layout cleanup, the empty `Journal/` folder included, unless asked.
- Templater `<%* ... %>` syntax. The file is written in its final form.
- New `.base` files or changes to `.obsidian/types.json`. A new category (a "Clothing" next to "Products") is a vault design decision, raise it instead of creating it.
- Lego Cubes episode notes, `lego-cubes-prep` owns them.

## When the title is non-trivial

For media references the year and metadata are pulled in:

- defuddle or WebFetch on IMDB, Goodreads, RAWG or Letterboxd for movies, shows, games and books. A URL in the request goes through the `defuddle` skill first.
- The year in the filename for media, the `.base` views group on it.
- `cover:` holds an image URL as a quoted string, the source's own image or the S3 URL of a pasted one. Images and PDFs do not live in the vault: the `s3-images` plugin uploads pasted files to `https://s3-hub.pkarpovich.space/obsidian/` and links them, there is no `Attachments/` folder.
