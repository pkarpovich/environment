---
name: obsidian-vault
description: Create or extend notes in Pavel's personal Obsidian vault at `/Users/pavel.karpovich/Obsidian/PK Workspace/`, following his adapted kepano-style vault grammar (plural categories, YYYY-MM-DD dates, heavy internal wikilinking, root-first organization, 1-10 rating). Use this skill WHENEVER Pavel wants to capture something into his vault - even when he does not say "Obsidian" or "vault" explicitly. Trigger phrases include "save a note about <X>", "log this", "add to vault", "I watched <movie>", "I read <book>", "I finished <game>", "I bought <jacket/jeans/sneakers>", "I met <person>", "new idea", "evergreen about", "meeting note for", "project note on", "weekly note", "add <X> to references", and any bare mention of a movie/book/game/show/person/place/product that implies cataloguing. Knows the 19 active note types - Journal, Meeting, Project Note, Task, Idea, Evergreen, Quote, Job Interview, Rent Payment, Weekly, Movie, TV Show, Game, Book, Person, Product, Company, Place, Recipe, Podcast - and where each one lives (root vs `References/` vs `Periodic/Weekly/`). SKIP this skill for Lego Cubes podcast episode preparation (use `lego-cubes-prep` instead - it owns `Tuclaw/Podcast/`), for editing existing notes that already have an established structure (just edit them directly), or for any general note-taking that is not destined for this specific Obsidian vault.
---

# obsidian-vault

This is Pavel's personal vault. It started from kepano's vault template and has accumulated 1390+ notes (~258 References) under his own house rules. Use the rules below, not your assumptions, when creating files here.

## Vault location

```
/Users/pavel.karpovich/Obsidian/PK Workspace/
```

Sub-vault `Tuclaw/` has its own `.git` and its own conventions - only the `lego-cubes-prep` skill should write there. Stay out unless that skill explicitly delegated.

## House rules (do not violate)

1. **Categories are plural and wikilinked.** `categories: [[Movies]]` - never `Movie`. The whole vault's view system is built on this exact spelling matching `.base` filters.
2. **Dates are `YYYY-MM-DD` everywhere.** Created, last, deadline, acquired - same shape. Time when present is `YYYY-MM-DD HH:mm`.
3. **Rating is integer 1-10.** Pavel does not use the kepano 1-7 scale. If unsure of a rating, leave the field empty rather than guessing.
4. **Wikilink eagerly.** First mention of any named entity in the body (a person, brand, place, project, movie) becomes `[[Name]]`, even if the target file does not exist yet - unresolved links are intentional breadcrumbs. Authors, directors, casts, brands, companies, projects in the frontmatter are wikilinks too.
5. **Properties are short and composable.** Use the property names already used elsewhere (`year`, `last`, `genre`, `cast`) - do not invent `release_year` or `watched_on`. If a property might ever hold more than one value (genres, attendees, cast), use list shape even when seeding with one item.
6. **Personal vs Reference dichotomy.**
   - **Root of the vault** - anything Pavel writes about his own world: journal entries, ideas, meetings, project notes, tasks, evergreen thoughts, job interviews. The whole point of root-first is that he doesn't have to think about where to put things. Use it.
   - **`References/`** - things that exist outside his world: books, movies, shows, games, people, products (clothing), companies, places, recipes, podcasts. Filename is the title.
   - **`Periodic/Weekly/`** - only weekly notes.

## Workflow

Before writing a file, confirm three things with Pavel (or infer if obvious from his message):

1. **Type** - which of the 19 types from `references/types.md` is this? Ambiguous cases: "bought new sneakers" → Product; "tried a new cafe" → Place; "interesting thing X said" → could be Quote or Evergreen, ask. Person notes are minimal scaffolds - when in doubt about whether someone deserves their own file, ask before creating.
2. **Title** - exactly as it will appear in the filename. Movies, shows, games, books include the year in parentheses: `<Title> (YYYY).md`. Seasons add `S0N`: `<Title> S02 (YYYY).md`. Products use `<Brand> <Model> <Size>` shape.
3. **Frontmatter** - fill only fields whose values you actually know. Empty fields stay empty rather than being guessed. For media, look up year / director / cast / cover URL via WebFetch or defuddle if Pavel did not provide them and the title is well-known - but never invent ratings, statuses, or personal-opinion fields.

**Verify the schema against the vault before assuming it.** `references/types.md` is a best-effort summary, not the source of truth - Pavel's vault is. Before writing a note of a type you have not touched recently, run two checks via the `ovq` skill:

```bash
ovq --values categories --count                    # confirms the real category name and how many notes use it
ovq 'categories contains "<Category>"' | head -3   # pick 2-3 sample files, read them, copy the actual frontmatter shape
```

Property names, value enums, and the choice between scalar vs list shape are all things that have drifted from `types.md` before (the Quote schema landed with `author:` in the docs while every real note used `attribution:`). If the sampled files disagree with `types.md`, trust the files and patch `types.md` afterwards.

After writing, report the saved path on a single line so Pavel can open it in Obsidian.

If Pavel asks for **content** (e.g. "write the review", "summarize the meeting we had"), help write it - he is OK with delegating content. Default to scaffolding only when intent is unclear.

## Type registry

Full per-type table (folder, filename, frontmatter shape, examples) lives in `references/types.md`. Load that file when:
- Creating any note other than a quick idea capture in the root.
- Pavel mentions a type whose schema you don't remember exactly.
- Adding fields to an existing note in `References/` - match the schema strictly.

## Things this skill does NOT do

- Reorganize folders. Pavel's root is intentionally messy.
- Move existing files. Templater stamped them where they live; leave them.
- Delete the empty `Journal/` folder or any other layout cleanup unless explicitly asked.
- Write Templater `<%* ... %>` syntax - that is for the Obsidian app, not for us. We generate the final file content directly.
- Create new `.base` files or modify the `.obsidian/types.json` schema map. Adding a brand-new category (e.g. a "Clothing" category separate from existing "Products") is a vault-design decision - surface it to Pavel rather than executing silently.
- Generate Lego Cubes episode notes - `lego-cubes-prep` owns that workflow end-to-end.

## When the title is non-trivial

For media references Pavel often wants the year and metadata pulled in:

- **Use defuddle/WebFetch on IMDB, Goodreads, RAWG, Letterboxd** for movies/shows/games/books. The `defuddle` skill is the right first move when he gives a URL.
- **Year is mandatory** in the filename for media - without it the `.base` views group wrong.
- **Cover URL**: paste the source URL into `cover:` for media - it can be a `https://...` image or an `[[Attachment.png]]` wikilink to an already-stored image, both are seen in existing notes.
