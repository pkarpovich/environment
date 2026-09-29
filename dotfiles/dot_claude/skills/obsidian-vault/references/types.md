# Type registry

Each row gives: where to write, what to name the file, which frontmatter fields to include, and known status enum values. **Frontmatter fields are listed in canonical order** — match this order when writing new files so notes stay scannable.

Status enum values are documented per type because they drive `.base` filters; using a value not in the enum will hide the note from existing views.

## Personal (root of vault)

### Journal
- **Folder**: vault root (the empty `Journal/` directory is unused).
- **Filename**: `YYYY-MM-DD - <Title>.md`. Multiple entries on the same day get `YYYY-MM-DD HHmm - <Title>.md`.
- **Frontmatter**:
  ```yaml
  categories:
    - "[[Journal]]"
  created: YYYY-MM-DD
  ```
- **Body**: free-form. Often markdown sections like `## 1. Title`, but no strict template — Pavel writes whatever the thought is.

### Meeting
- **Folder**: vault root.
- **Filename**: `YYYY-MM-DD HHmm - <Topic>.md`.
- **Frontmatter**:
  ```yaml
  categories:
    - "[[Meetings]]"
  project: "[[<Project Name>]]"  # or empty string if no project
  created: YYYY-MM-DD
  attendees:
    - "[[Pavel Karpovich|@Me]]"
    - "[[<Other Person>]]"
  ```
- **Body**: starts with `## Action items` and a checklist; rest is up to Pavel.

### Project Note
- **Folder**: vault root.
- **Filename**: `YYYY-MM-DD - <Title>.md`.
- **Frontmatter**:
  ```yaml
  categories:
    - "[[Project Notes]]"
  project: "[[<Project Name>]]"
  created: YYYY-MM-DD
  ```
- **Body**: free-form.

### Task
- **Folder**: vault root.
- **Filename**: `<Task name>.md` (just the task name, no date prefix).
- **Frontmatter**:
  ```yaml
  categories:
    - "[[Tasks]]"
  project: "[[<Project>]]"  # or empty
  status: backlog
  created: YYYY-MM-DD
  deadline:
  completed:
  ```
- **Status enum**: `backlog`, `in-progress`, `done` (infer from `.base` if more — check `Bases/Tasks.base`).

### Idea
- **Folder**: vault root.
- **Filename**: `<Title>.md` — a short noun phrase capturing the idea, in whatever language Pavel used (Russian and English both occur).
- **Frontmatter**: often missing entirely on quick captures. When fuller:
  ```yaml
  categories:
    - "[[Ideas]]"
  project: "[[<Project>]]"
  area: <free text>
  created: YYYY-MM-DD
  ```
- **Body**: 1-3 sentences usually. Treat as inbox-grade.

### Evergreen
- **Folder**: vault root.
- **Filename**: `<Title>.md` — a complete declarative sentence ideally (kepano-style: "Talent is the speed of learning" not "Talent").
- **Frontmatter**:
  ```yaml
  categories:
    - "[[Evergreen]]"
  created: YYYY-MM-DD
  ```
- **Body**: 1-3 paragraphs. Concept that should be reusable across contexts.

### Quote
- **Folder**: vault root.
- **Filename**: a short evergreen-style identifier capturing the quote's idea, in the original language. Examples in the vault: `Photography didn't kill painting.md`, `Here's to the crazy ones.md`, `Талант - это скорость обучения.md`.
- **Frontmatter**:
  ```yaml
  categories:
    - "[[Quotes]]"
  attribution: "[[<Person Name>]]"      # who said it; scalar wikilink or list if multiple
  source: "[[<Original Work or Site>]]" # the show, book, blog, podcast where it was published
  via: "[[<Where Pavel Encountered It>]]"  # optional: the secondary work that surfaced the quote
  created: YYYY-MM-DD
  topics: []                            # optional list of topic wikilinks
  ```
- **Body**: just the quote, typically as a blockquote (`> ...`). Source URL or extra context belongs in the `source` / `via` properties, not the body.
- **Property names matter**: it is `attribution`, not `author`, even though the `Bases/Quotes.base` view config used to alias it. Always match the real frontmatter so existing notes and views keep working.

### Job Interview
- **Folder**: vault root.
- **Filename**: `YYYY-MM-DD - <Candidate or Topic>.md`.
- **Frontmatter**:
  ```yaml
  categories:
    - "[[Meetings]]"
  type: "[[Job Interviews]]"
  project: "[[<Project>]]"
  people:
    - "[[<Candidate>]]"
  created: YYYY-MM-DD
  role: <free text>
  rating:  # 1-10, empty if unknown
  ```
- **Body**: `## Brief Notes`, `## Summary`.

### Rent Payment
- **Folder**: vault root.
- **Filename**: `<Property Name> Rent <Month> <Year>.md` (e.g. `Drewnowska 51 Rent January 2026.md`).
- **Frontmatter**:
  ```yaml
  categories:
    - "[[Rent Payments]]"
  property: "[[<Property>]]"
  date: YYYY-MM-DD
  rent: <number>
  admin_fee: <number>
  electricity: <number>
  total_pln: <rent + admin_fee + electricity>
  total_usd: <total_pln / usd_rate, 2 decimals>
  ```
- **Special**: Pavel needs the USD/PLN rate for `total_usd`. If he hasn't given it, ask.

## Periodic

### Weekly
- **Folder**: `Periodic/Weekly/`.
- **Filename**: `YYYY-WNN.md` (ISO week, e.g. `2026-W20.md`).
- **Frontmatter**:
  ```yaml
  created: YYYY-MM-DD HH:mm
  tags: [weekly]
  week: YYYY-WNN
  ```
- **Body**:
  ```markdown
  # YYYY-WNN
  > [[<prev week>]] ⟷ [[<next week>]]

  ## This Week
  - [ ]
  - [ ]
  - [ ]

  ---

  ## Highlights of the week

  -
  -
  -

  ![[Tasks.base#Weekly]]
  ![[Tasks.base#Completed]]
  ```

## References (outside the user's world)

All in `References/`. Filename is the title; year goes in parentheses for media.

### Movie
- **Filename**: `<Title> (YYYY).md`.
- **Frontmatter**:
  ```yaml
  categories:
    - "[[Movies]]"
  director: "[[<Name>]]"
  cast:
    - "[[<Actor>]]"
  genre:
    - <Genre 1>
    - <Genre 2>
  status: <enum>
  rating:  # 1-10
  year: YYYY
  cover: <URL or [[attachment.png]]>
  last: YYYY-MM-DD  # last watched
  ```
- **Status enum**: `watched`, `backlog`, `wishlist`.

### TV Show (season)
- **Filename**: `<Title> S0N (YYYY).md` (one file per season, not per show).
- **Frontmatter**:
  ```yaml
  categories:
    - "[[TV Shows]]"
  show: "[[<Show Name>]]"
  series: "[[<Franchise>]]"  # optional, e.g. "[[League of Legends]]"
  cast:
    - "[[<Actor>]]"
  genre:
    - <Genre>
  season: <integer>
  status: <enum>
  rating:  # 1-10
  year: YYYY
  cover: <URL or [[attachment.png]]>
  last: YYYY-MM-DD
  ```
- **Status enum**: `watched`, `backlog`, `wishlist`, `watching`.

### Game
- **Filename**: `<Title> (YYYY).md`.
- **Frontmatter**:
  ```yaml
  categories:
    - "[[Games]]"
  platform: <PS5 | PC | Switch | ...>
  developer: <Studio>
  publisher: <Publisher>
  genre:
    - <Genre>
  status: <enum>
  rating:  # 1-10
  year: YYYY
  cover: <URL or [[attachment.png]]>
  last: YYYY-MM-DD  # last played
  ```
- **Status enum**: `completed`, `playing`, `backlog`, `wishlist`, `dropped`.

### Book
- **Filename**: `<Title> (YYYY).md`.
- **Frontmatter**:
  ```yaml
  categories:
    - "[[Books]]"
  author: "[[<Name>]]"
  series: "[[<Series>]]"  # optional
  genre:
    - <Genre>
  status: <enum>
  rating:  # 1-10
  year: YYYY
  cover: <URL>
  last: YYYY-MM-DD  # last read
  ```
- **Status enum**: `read`, `reading`, `backlog`, `wishlist`, `dropped`.

### Person
- **Filename**: `<First Last>.md` (preferred order in Pavel's vault is `<First> <Last>`, including for Russian names transliterated to Latin).
- **Frontmatter** (intentionally minimal):
  ```yaml
  categories:
    - "[[People]]"
  ```
- **Body**: free-form. Sometimes empty (just the wikilink target). Sometimes a one-liner with role, employer, GitHub, etc.
- **Composable**: if the person is also an author/director/etc., add the relevant role-specific properties to the same file — do not create separate files.

### Product (clothing, footwear, accessories)
- **Filename**: `<Brand> <Model name> <Size>.md` — e.g. `Cropp Bomber Jacket XXL.md`, `Levis 501 Original W40 L33.md`, `Lacoste Court Lt 125.md` (footwear uses Euro size).
- **Frontmatter**:
  ```yaml
  categories:
    - "[[Products]]"
  brand: "[[<Brand>]]"
  type: <jacket | jeans | sneakers | shirt | ...>
  model: <model name>
  size: <size>
  price:
  acquired: YYYY-MM-DD
  status: <enum>
  rating:  # 1-10
  ```
- **Status enum**: `owned`, `wishlist`, `returned`, `sold`.
- **Body**: typically `## Specs`, `## Notes`, `## Links` (URL to the shop page).

### Company
- **Filename**: `<Company Name>.md`.
- **Frontmatter**:
  ```yaml
  categories:
    - "[[Companies]]"
  country: <Country>
  type: <industry/type>
  founded: YYYY
  ```

### Place
- **Filename**: `<Place Name>.md` (restaurant, cafe, city, neighborhood, venue).
- **Frontmatter**:
  ```yaml
  categories:
    - "[[Places]]"
  city: <City>
  country: <Country>
  ```

### Recipe
- **Filename**: `<Recipe Name>.md`.
- **Frontmatter**:
  ```yaml
  categories:
    - "[[Recipes]]"
  created: YYYY-MM-DD
  ```

### Podcast (the show itself, not an episode)
- **Filename**: `<Show Name>.md`.
- **Frontmatter** (varies by view — `Bases/Podcasts.base` defines three views with slightly different field sets):
  ```yaml
  categories:
    - "[[Podcasts]]"
  show: "[[<Show Name>]]"
  guest: "[[<Person>]]"  # if a guest-focused note
  channel: <YouTube/Spotify/etc>
  host: "[[<Host>]]"
  date: YYYY-MM-DD
  ```
- **For Lego Cubes episodes specifically — STOP and defer to `lego-cubes-prep`.**

## Edge cases and ambiguous types

- **"I bought socks with Home Alone print"** — Product. Size if known, brand if known, leave blanks for unknown fields.
- **"new idea for the plugin"** — Idea (root, minimal frontmatter, often body-only).
- **"thoughts on X after watching Y's stream"** — Journal if it's a stream-of-consciousness reflection; Evergreen if it's a single crystallized concept.
- **"tried a new cafe today"** — Place (References) + optionally a Journal entry in root that wikilinks to it.
- **"watched <Movie>, liked it"** — Movie reference in References/; ask whether to also create a Journal mention.
- **A person who is both a director and an actor** — single file, properties cumulative (composability is the rule).
- **An item that doesn't fit any existing type** (furniture, electronics, software subscription, etc.) — surface to Pavel before inventing a new category. Adding a category means new `.base` view, `.obsidian/types.json` entry, and a Categories landing page — explicit vault-design decision, not a silent skill action.
