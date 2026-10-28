---
name: lego-cubes-prep
description: Prepare, publish and archive an episode of Lego Cubes, the Russian-language podcast about films, games, books and dev projects. Use when an episode is mentioned by number ("prepare episode 30", "Lego Cubes 30", "the next episode"), when the episode note needs filling, a title or a cover prompt, when a recording is done ("I recorded the podcast", "put it on the NAS", "make the nfo"), or when impressions move to References. Requests come in Russian as often as English. Eight stages with a check-in after each, and a single stage can be run on its own. Other vault notes go to obsidian-vault.
---

# Lego Cubes Episode Preparation

This skill prepares a new Lego Cubes podcast episode for Pavel. It walks through 8 stages with explicit check-ins so he can review and adjust before each next step.

The detail lives in reference files. Load the one a stage names **when that stage runs**, not before - that is what keeps this body small:

| Reference | Used by |
|---|---|
| `references/writing-style.md` - how bullets are worded | Stages 2, 3 |
| `references/title-style.md` - title conventions, past titles | Stage 4 |
| `references/nano-banana-cover-prompt.md` - LEGO cover prompt spec | Stage 6 |
| `references/post-episode.md` - NAS publishing, nfo spec, archival | Stages 7, 8 |

## Vault layout

- Vault root: `/Users/pavel.karpovich/Obsidian/PK Workspace/`
- Episode notes live at vault root: `Lego Cubes NNN - <Title>.md` (NNN is 3-digit padded)
- Per-content impressions (films/shows/games/books for the upcoming episode) live in `Tuclaw/Podcast/`
- Once an episode is published those files move to `References/` - that is Stage 8
- Template: `Templates/Lego Cubes Episode.md` (Templater plugin) - creates a stub `Lego Cubes NNN -.md` with frontmatter

## Conventions

- ASCII hyphen `-` for every dash, no U+2014 or U+2013, in titles, bullets and the nfo alike.
- Content bullets format: `- <hook> - [[<wikilink with year>]]`
- Sub-items for marathons/dilogies: indent 4 spaces, same hook format
- Frontmatter `episode: 30` (integer, not padded)
- File on disk: `Lego Cubes 030 - <Title>.md` (padded to 3 digits)

## The 8 stages

Stages 1-6 are pre-recording (Obsidian note prep). Stage 7 is post-recording publishing. Stage 8 is post-publishing archival. A request can name one stage: "I recorded the episode" or "put it on the NAS" is Stage 7, "move impressions to References" is Stage 8. Run only that stage.

Run pre-recording stages in order. After each, summarize and let Pavel confirm before moving on. He may pause the skill at any stage - that is normal.

### Stage 1 - Episode setup

Goal: locate or create the episode note.

1. Determine episode number `N` from the request. If unclear, ask.
2. Compute the padded form `NNN`.
3. Look for `Lego Cubes NNN - *.md` at vault root: `ls "/Users/pavel.karpovich/Obsidian/PK Workspace/" | grep -i "Lego Cubes NNN"`.
4. If it exists, Read it and confirm which file you found.
5. If not, tell Pavel to create it via Templater (Cmd+P -> "Templater: Create new note from template" -> "Lego Cubes Episode"), wait, then re-check.
6. The template yields empty `title:`, `date:`, `cover:` and the skeleton `## Logo`, `## Links`, `## Key notes` -> `### Content`, `### Projects`.

### Stage 2 - Collect Content

Goal: fill `### Content` with one bullet per piece of content discussed this episode.

**Read `references/writing-style.md` before writing a single hook.**

1. Find this episode's impression files by their `> Mentioned in` marker:
   ```bash
   cd "/Users/pavel.karpovich/Obsidian/PK Workspace/Tuclaw/Podcast" && for f in *.md; do mention=$(grep -o "Lego Cubes [0-9]\+ -" "$f" | head -1); echo "$mention | $f"; done | sort
   ```
2. Read every matched file.
3. **Skip files without a review body** - frontmatter plus the `> Mentioned in` line and nothing else, typically `status: watching/playing/on hold`. Tell Pavel which ones you skipped and why.
4. Write one hook per remaining file, in the style from the reference.
5. Group related items under a parent bullet (sequels watched together, book plus adaptation, genre marathon), sub-items indented 4 spaces.
6. Order: movies -> shows -> games -> books. Within a medium Pavel keeps watch-date order, so a newly added film slots in by its `last:` date, not at the end.
7. Format every bullet as `- <hook> - [[<wikilink>]]`, the wikilink being the filename without `.md`.
8. Show the whole block in chat as plain text **before** writing it to the file, and ask about grouping, order and wording.
9. After confirmation, Edit the file in place of the empty `### Content` placeholder.

### Stage 3 - Month digest (General + Projects)

Goal: fill `### General` and `### Projects`. Pavel no longer writes these from memory - you dig the period out of the vault, present a weighted digest, he picks, you write.

**Read `references/writing-style.md`** - General and Projects bullets follow the same style as Content.

1. The period runs from the previous episode's `date:` to today. Read every weekly note covering it (`Periodic/Weekly/2026-WNN.md`) in one parallel Read. The week containing the previous episode's date is already covered by that episode - cross-check its General/Projects and drop what is there. The current week's Highlights are usually still empty on prep day, so ask Pavel what happened this week and fold his answer in.
2. Read the previous episode's `### General` / `### Projects` for running project names and wikilink spellings (`[[Tuclaw]]`, `[[Ralphex Farm]]`, `[[Glitch]]`, `[[Nikki]]`). Most project wikilinks resolve to nothing - normal in this vault, use them anyway.
3. Present the digest in chat as three tiers - **Крупное / Среднее / Мелочь** - one line per item, each carrying the detail that shows its scale (numbers, durations, "got up at 4am for two weeks", "nothing had ever been backed up before"). Rank by what Pavel was excited about or struggled with in the Highlights, not by engineering size. Personal items (esports, football, hardware dying, purchases, work events) go to General. Things he built go to Projects.
4. Pavel replies take/skip per item and adds what the weeklies missed. His verdicts are final. Things he defers to the next episode stay out.
5. Draft both sections in chat, then Edit after confirmation.
6. Keep the tier ranking in mind - Stage 4 anchors the title on the top of it.

### Stage 4 - Suggest title

Goal: 4-5 candidates in the established style, iterating until Pavel picks one.

**Read `references/title-style.md` before brainstorming**, and read the five most recent episode filenames for live calibration.

1. Inputs: the `### General` and `### Projects` digest first (they drive the central image), Content second.
2. Present 4-5 candidates with a one-line rationale each, grouped by angle so the spread is visible.
3. If Pavel likes one half of a title, keep it and rework only the other half.
4. After he picks, he renames the note in Obsidian himself - Obsidian rewrites the wikilinks in every impression card, which a filesystem `mv` would not. Offer `mv` only when nothing links to the episode yet. Set `title:` in frontmatter (title alone, no episode prefix).

### Stage 5 - Find links

Goal: fill `## Links` with one link per bullet, in note order across all three sections.

1. Walk the bullets in the order they appear in the note.
2. Pick the platform per item:
   - **Movies, TV shows** -> IMDB, `https://www.imdb.com/title/ttXXXXXXX/`
   - **Games** (including DLC) -> Steam, `https://store.steampowered.com/app/XXXXXXX/<Slug>/`. rawg.io only if a game is not on Steam
   - **Books** -> Goodreads, `https://www.goodreads.com/book/show/XXXXXXX-<slug>`
   - **Esports** -> Liquipedia, e.g. `https://liquipedia.net/dota2/The_International/2026`. A bullet naming two tournaments gets two links.
   - **Football** -> FotMob team page
   - **Hardware bought** -> the vendor product page
   - **Projects** -> GitHub repo. `gh repo list --limit 200 --json name,url,isPrivate` for his own. Repos he collaborates on live in other orgs, found with `gh api "user/repos?affiliation=collaborator,organization_member&per_page=100" --paginate`. Private repos are fine. Work projects get no link.
   - **Bullets that already wikilink a vault note** get no entry - that wikilink is enough. Bullets with nothing to link (a dead SD card) are skipped, or point at the repo holding the relevant code.
3. WebSearch each with `allowed_domains` set to the target site, and pick canonical title pages (not mediaviewer/cast subpages).
4. Show the list in chat first, flagging assumptions (which hardware model, which of several same-named repos), then Edit `## Links`. Bare URLs as bullets, no descriptions.
5. **Links are positional** - nothing labels which URL belongs to which bullet, so they drift silently whenever a section is reordered, and Pavel does reorder. Before Stage 7, re-read the note and realign. Verify by counting: links must equal the number of link-bearing bullets, and the section boundaries must line up.

### Stage 6 - Cover prompt for Nano Banana Pro

Goal: a LEGO-diorama image prompt for Pavel to feed into Nano Banana Pro (Gemini 3 Pro Image). The aesthetic is fixed. Camera, subject, palette and Easter eggs are the variables.

**Read `references/nano-banana-cover-prompt.md` before writing the prompt** - it holds the prompting principles, the house style spec, the composition decision tree, the assembly template and iteration guidance.

1. Take the **central image from the chosen title** - the cover literalizes the title's main figure.
2. Default to a single coherent scene. **Give it a real place and a sense of scale**: a bare interior on an empty background reads as a room floating in a void. Open a wall or window onto a wider view and put scale cues in it. Where content allows, borrow the location from the dominant Content item.
3. Push density explicitly - name the equipment, cabling and desk clutter, and raise the piece count in the style anchor (5000+ rather than 3000) for interiors that should feel packed.
4. Weave in 2-3 subtle Easter eggs referencing other Content items - small labelled props, posters, silhouettes, never dominating.
5. Output the prompt as one fenced code block, followed by a 3-5 bullet `## Что в нём заложено` summary.
6. On a change request, rewrite only the affected block - the style anchor and lighting boilerplate stay stable.

Pavel pastes the generated image under `## Logo`. The `s3-images` Obsidian plugin uploads it to the S3 bucket and leaves `![](https://s3-hub.pkarpovich.space/obsidian/<YYYY-MM>/<sha256>.jpg)` there, so no file lands in the vault. Frontmatter `cover:` holds the same URL as a quoted string. Generation and pasting are Pavel's. Stage 7 downloads the image from that URL for the NAS.

### Stage 7 - Publish to NAS (post-recording)

Goal: turn the raw OBS recording into a streaming-ready file with sidecars so Plex/Kodi index the episode.

**Read `references/post-episode.md` before touching anything** - it has the naming rules, the exact ffmpeg and `dd` recipes, the full nfo field spec and the verification method.

1. Find today's recording in `~/Movies` (the largest file, sub-100 MB ones are tests).
2. Remux with `-c copy -movflags +faststart`, capturing duration, resolution and codecs for the nfo.
3. Copy both .jpg sidecars, hand the 15-25 GB .mp4 copy to Pavel to run in his own shell.
4. Build the nfo by mirroring the previous episode's file, with the plot assembled from the note's sections.
5. Verify all four files, size plus byte spot-checks if any copy was resumed.

### Stage 8 - Archive impressions to References

Goal: move this episode's impression files from `Tuclaw/Podcast/` to `References/`, and roll the leftovers to the next episode.

**Read `references/post-episode.md`** - the archival half covers the stub/review split, the collision-guarded move and the rollover.

1. Split reviews from stubs by size, confirming anything borderline by reading it.
2. Cross-check the move list against `### Content` - counts must match.
3. Move the reviews, guarding against same-named files in `References/`.
4. Repoint every remaining stub at `[[Lego Cubes <NNN+1> -]]`.
5. Verify both directories.

## Pace and voice

- Check in after every stage. The Content block is reviewed in chat before it lands, titles come as 4-5 options, the cover prompt usually takes two rounds.
- Requests and impressions are in informal Russian. Mirror the vocabulary of the source impressions, do not formalize it.
- The latest episode is the calibration for bullet wording and title style. Read it before Stage 2 and Stage 4.

## Quick reference - file paths

| What | Path |
|------|------|
| Vault root | `/Users/pavel.karpovich/Obsidian/PK Workspace/` |
| Episode notes | `/Users/pavel.karpovich/Obsidian/PK Workspace/Lego Cubes NNN - <Title>.md` |
| Content impressions (current episode) | `/Users/pavel.karpovich/Obsidian/PK Workspace/Tuclaw/Podcast/*.md` |
| Template | `/Users/pavel.karpovich/Obsidian/PK Workspace/Templates/Lego Cubes Episode.md` |
| Past References (post-publish) | `/Users/pavel.karpovich/Obsidian/PK Workspace/References/` |
| Raw OBS recordings | `/Users/pavel.karpovich/Movies/YYYY-MM-DD_HH-MM-SS.mp4` |
| Local remuxed output | `/Users/pavel.karpovich/Movies/LEGO Cubes E<N>.mp4` |
| NAS published episodes | `/System/Volumes/Data/mnt/nas/media/me/LEGO Cubes/` |
