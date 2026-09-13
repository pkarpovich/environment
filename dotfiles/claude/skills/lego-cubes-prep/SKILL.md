---
name: lego-cubes-prep
description: End-to-end preparation of a new Lego Cubes podcast episode (Pavel's Russian-language podcast about content + dev projects). Walks through 8 stages with check-ins — collect Content bullets from Tuclaw/Podcast files, digest the period's weekly notes into General/Projects, fill the episode note, suggest an episode title in the established poetic style, find IMDB/Steam/Goodreads links, produce a LEGO-style cover image prompt for Nano Banana Pro, after the recording publish the .mp4 + .jpg + .nfo bundle to the NAS for Plex/Kodi, and finally archive the per-content impression files into References/. Trigger on any mention of preparing, assembling, filling, publishing, or archiving a Lego Cubes episode — including phrases like "prepare episode 30", "Lego Cubes 30", "the next episode", "fill out the episode note", "I recorded the podcast", "put it on the NAS", "make the nfo", "faststart the recording", "move impressions to References", "archive the episode", or a bare episode number with podcast context. Pavel typically writes these requests in Russian — same triggers apply regardless of language. Always use this skill when Pavel mentions a Lego Cubes episode by number or asks to prepare/finalize/publish/archive one — do not handle these requests ad-hoc, the skill encodes critical conventions (ASCII hyphens, sequel grouping, title style, single-room cover composition, NAS naming, nfo plot format, References archival rules) that are easy to miss without it.
---

# Lego Cubes Episode Preparation

This skill prepares a new Lego Cubes podcast episode for Pavel. It walks through 5 stages with explicit check-ins so Pavel can review and adjust at each step before moving on.

## Vault layout (always assume this structure)

- Vault root: `/Users/pavel.karpovich/Obsidian/PK Workspace/`
- Episode notes live at vault root: `Lego Cubes NNN - <Title>.md` (NNN is 3-digit padded)
- Per-content impressions (films/shows/games/books for the upcoming episode) live in: `Tuclaw/Podcast/`
- After an episode is published, those files get moved to `References/` - that migration is NOT part of this skill, it happens later. We work only with what is currently in `Tuclaw/Podcast/`.
- Template: `Templates/Lego Cubes Episode.md` (Templater plugin) - creates a stub file `Lego Cubes NNN -.md` with frontmatter

## Critical conventions (do not violate)

- **ASCII hyphen `-` only**, never `—` (em dash) or `–` (en dash). This is enforced project-wide. The user has rejected em dashes explicitly.
- Content bullets format: `- <hook> - [[<wikilink with year>]]`
- Sub-items for marathons/dilogies: indent 4 spaces, same hook format
- Frontmatter `episode: 30` (integer, not padded)
- File on disk: `Lego Cubes 030 - <Title>.md` (padded to 3 digits)

## The 8 stages

Stages 1-6 are pre-recording (Obsidian note prep). Stage 7 is post-recording publishing (.mp4 to NAS with sidecars). Stage 8 is post-publishing archival (move impression files to References/). Pavel often invokes only one stage at a time - phrases like "I recorded the episode, prepare the file" or "put it on the NAS" jump to Stage 7; "move impressions to References" jumps to Stage 8. Don't run earlier stages in those cases; just go to the requested one.

Run pre-recording stages in order. After each stage, summarize what was done and ask Pavel to confirm before moving on. Pavel may pause the skill at any stage - that is normal.

### Stage 1 - Episode setup

Goal: locate or create the episode note.

1. Determine episode number `N` from Pavel's request. If unclear, ask.
2. Compute padded form: `NNN = String(N).padStart(3, "0")`.
3. Check if a file matching `Lego Cubes NNN - *.md` exists at vault root. Use `ls "/Users/pavel.karpovich/Obsidian/PK Workspace/" | grep -i "Lego Cubes NNN"`.
4. If file exists, Read it - confirm to Pavel which file you found and proceed.
5. If no file exists, tell Pavel to create one via Obsidian Templater (Cmd+P -> "Templater: Create new note from template" -> "Lego Cubes Episode") and give the episode number when prompted. Wait for him to do this and confirm. Re-check.
6. The template produces a stub with empty `title:`, `date:`, `cover:` and skeleton sections (`## Logo`, `## Links`, `## Key notes` -> `### Content`, `### Projects`).

### Stage 2 - Collect Content

Goal: fill the `### Content` section with one-line hooks for each piece of content discussed in this episode.

1. List files in `Tuclaw/Podcast/`: `ls "/Users/pavel.karpovich/Obsidian/PK Workspace/Tuclaw/Podcast"`.
2. Filter to files belonging to THIS episode by their `> Mentioned in [[Lego Cubes NNN -]]` marker at the bottom. Use:
   ```bash
   cd "/Users/pavel.karpovich/Obsidian/PK Workspace/Tuclaw/Podcast" && for f in *.md; do mention=$(grep -o "Lego Cubes [0-9]\+ -" "$f" | head -1); echo "$mention | $f"; done | sort
   ```
   Pick rows matching the target episode number.
3. Read each matched file in parallel (single tool message with multiple Read calls - Pavel cares about latency).
4. For each file, extract a one-line hook:
   - **Skip files without a review body** - if the file has only frontmatter and the `> Mentioned in` line (no impression text), drop it. Files with `status: watching/playing/on hold` and empty body are typical skips. Tell Pavel which ones you skipped and why.
   - These hooks become the published **show notes**. The target style is the topic lists of Radio-T (radio-t.com) and UWP (podcast.umputun.com), which Pavel explicitly asked to copy in episode 033: **each hook is one complete statement with a subject and a predicate** - a mini-story, a verdict with a twist, or an ironic observation. Model lines: "Как одно хобби сломало другое", "Поход к дилеру Indian оказался провальным", "Добрые дела не проходят безнаказанно", "Автор zig совсем сорвался с цепи". Useful moves: "Как X сделал Y", "X оказался Y", "X не дал / заставил / привёл", an idiom that fits the subject ("Звёздный городок долго запрягает, но быстро едет").
   - **Never write two comma-spliced fragments** ("Сильнее второго, у Рейниры едет крыша", "Аня Тейлор-Джой хороша, эпизоды неровные"). That is a list of verdicts, not a phrase. Pick one angle and phrase it as a sentence.
   - Prefer the angle with a story or a joke over the plain rating. When Pavel had both to choose from, he took "Игра года задним числом ушла к Кодзиме" over "DLC сделали, чтобы продать бандл" and "Гай Ричи не дал вовремя лечь спать" over "Кандидат на сериал года за четыре ночи".
   - Still a teaser, not the review: 4-9 words, no reasoning, no full plot. Do not oversell - understate.
   - Keep hooks in Russian, in Pavel's voice (he writes informally). No trailing period.
5. Group related items under a parent bullet:
   - Sequels watched together (e.g., "Дилогия X перед выходом второго")
   - Book + film adaptations of same source
   - Genre marathons (e.g., "Резидент-марафон после RE9")
   Use 4-space indent for sub-items.
6. Order: movies -> shows -> games -> books (matches the established style in episodes 024-028). Sub-grouped items keep their parent in this order based on dominant medium.
7. Format every bullet as `- <hook> - [[<wikilink>]]`. The wikilink is the file name without `.md` (e.g., `[[Project Hail Mary (2026)]]`).
8. Show the proposed Content block to Pavel **as plain text in chat first**, before writing to the file. Ask if grouping/order/wording is OK.
9. After confirmation, Edit the file to replace the empty `### Content\n\n- ` placeholder (followed by `### Projects` or end of file).
10. **Pavel's edits to a hook are final.** If he rewrites or shortens one, take his version verbatim - do not reintroduce a detail he cut when you touch that line again. He notices ("я же специально это убрал").

Reference - example Content block in the current style (from episode 033):
```markdown
- Netflix не любит тратиться на инопланетян - [[War Machine (2026)]]
- Как целая улица уехала к динозаврам - [[The End of Oak Street (2026)]]
- Кино заставило дать книге второй шанс - [[The Dog Stars (2026)]]
- Терминатор как джарвис, которому не объяснили задачу - [[Terminator 2 - Judgment Day (1991)]]
- У Рейниры едет крыша, и это лучшее в сезоне - [[House of the Dragon S03 (2026)]]
- Одна погоня уровня GTA на семь серий - [[Lucky S01 (2026)]]
- Гай Ричи не дал вовремя лечь спать - [[The Gentlemen S02 (2026)]]
- Игра года задним числом ушла к Кодзиме - [[Mafia - The Old Country - Man of Honor (2026)]]
```

Grouping reference (from episode 029 - the hook wording there is the old style, look only at the structure):
```markdown
- Дилогия Devil Wears Prada перед выходом второго
    - Пересмотрел оригинал, добрые эмоции и отличная актёрская игра - [[The Devil Wears Prada (2006)]]
    - Идеальное продолжение про трансформацию медиа под новые реалии - [[The Devil Wears Prada 2 (2026)]]
```

Episodes 030-032 used the older "short phrase / two fragments" style ("Крепкое становление, злодей слабоват", "DLC с новым копьём") - do not mimic their wording, only their brevity. Episode 033 is the calibration for wording.

### Stage 3 - Month digest (General + Projects)

Goal: fill `### General` and `### Projects`. Pavel no longer writes these from memory - you dig the period out of the vault, present a weighted digest, he picks, you write.

1. The period runs from the previous episode's `date:` to today. Read every weekly note covering it - `Periodic/Weekly/2026-WNN.md` - in one parallel Read. The week that contains the previous episode's date is already covered by that episode (cross-check against its General/Projects and drop what is there). The current week's "Highlights of the week" is usually still empty on prep day - ask Pavel what happened this week and fold his answer in.
2. Read the previous episode's `### General` / `### Projects` for the running project names and wikilink spellings (`[[Tuclaw]]`, `[[Ralphex Farm]]`, `[[Glitch]]`, `[[Nikki]]` ...). Most project wikilinks do not resolve to a note - that is normal in this vault, use them anyway; only a few (`Content Oracle`, `Agent SDK Runtime`, `Home Backups`) exist as notes.
3. Present the digest in chat as three tiers - **Крупное / Среднее / Мелочь** - one line per item, with the detail that shows the scale (numbers, durations, "got up at 4am for two weeks", "nothing had ever been backed up before"). Rank by what Pavel was excited about or struggled with in the Highlights, not by engineering size. Include personal items (esports, football, hardware dying, purchases, work events) - those go to General; things he built go to Projects.
4. Pavel replies with take/skip per item and adds what the weeklies missed. His verdicts are final. Items he defers to the next episode (an exam he has not taken yet, a deploy blocked on hardware) stay out or go in as "in progress" only if he says so.
5. Draft both sections in chat. **Same hook style as Content** - one statement per line with a twist, in the Radio-T / UWP manner; the first 033 draft slipped back into flat reporting ("Nikki - замена Toggl Track, уже собирает данные") and got sent back. Wikilinks on projects/entities inside the sentence. Reference lines from 033:
   - `[[Team Spirit]] взяли [[The International 2026]] и [[EWC 2026]], а я перешёл на шанхайское время`
   - `[[pi-alpha]] погиб смертью храбрых и доказал, зачем были бэкапы`
   - `[[Chelsea FC]] при Хаби решил не защищаться - 17:9 за три матча`
   - `[[Mimi]] помнит митинги лучше меня`
   - `Ответил на все вопросы [[CCAF]], осталось ответить на экзамене`
   - `Сервис для [[Oura Ring]] готов, а деплоить некуда`
   Keep `### General` flat - Pavel removed every sub-bullet there in 033. In `### Projects` a tab-indented group is fine when several items share one joke (the "apps started naming themselves in Japanese" parent over Nikki and Mimi). Do not invent a struggle for humour where there was none: "занял четыре недели вместо одной" got corrected to "много работы, и вся по плану". After confirmation, Edit the file, replacing the empty `- ` placeholders under `### General` and `### Projects`.
6. Keep the tier ranking in mind - Stage 4 anchors the title on the top of it.

### Stage 4 - Suggest title

Goal: propose 4-5 episode title candidates in the style of recent episodes. Pavel iterates with you until he picks one.

1. Read 5 most recent episodes to absorb the style. Use Glob to find them, then read 023-028 (or whatever's recent). The current style (022 onward) is **poetic, metaphorical, 4-7 words, blending the central project of the period with a content theme**. Examples:
   - 022 "Когда агент зовет в континуум" (Continuum project + agents)
   - 026 "Снежная кузница параллельных сеансов" (winter break + Continuum parallel execution)
   - 027 "Оруженосец из черепашьей гавани" (Tuclaw assistant + Turtle Ecosystem)
   - 029 "Дьявол носит артефакт повелителя теней" (Devil Wears Prada + Maul Shadow Lord + Glitch project as "артефакт" double meaning)

2. Inputs to the title:
   - The `### Content` you filled in Stage 2 (look for dominant content themes)
   - The `### General` and `### Projects` you filled in Stage 3 - they drive the title's central image more than content does

3. **Anchor on the top tier of the Stage 3 digest - do not title from the bullet text alone.** The bullets are one-line shorthand and give no sense of scale: "Реализовали с 0 процесс бекапов" was the month's biggest engineering effort (nothing had ever been backed up; a full 3-2-1 system with an offsite copy of the entire podcast archive), while "У Ralphex Farm теперь есть свои раннеры" was a minor increment. The weekly Highlights you already read tell them apart. If a wikilinked project has its own note at the vault root (`Home Backups.md`, `nhop proxy router.md`), open it for the imagery; a missing note is itself a signal the item is small. Pavel pushes back hard when the title is built on a minor item ("ты выбираешь мелочь") or on something he already called small.

4. Brainstorm angles:
   - One central project name or metaphor as the anchor
   - One content reference as the secondary layer - and prefer the **newest / headline** release over an older entry in the same marathon (with a Spider-Man marathon, the anchor is `Brand New Day`, not `Homecoming`)
   - Look for double-meaning words: "артефакт" (tech bug + magic relic), "фантом" (Star Wars + glitched data), "сбой" (malfunction + disruption), "трещина" (crack in mask + crack in code)
   - Avoid in-your-face references - Pavel prefers subtle and metaphorical over literal
   - **Do not reuse a motif from the last 2-3 episodes.** Check the recent titles you just read and retire those words: after 030 "Автономная ферма выходит на форсаж" and 031 "Сны молодого агента", the words "агент", "ферма", "сны" are burned.
   - The title must read as **one coherent phrase**. A liked opening plus a bolted-on technical tail ("Совершенно новый день на новой раскладке") reads as two halves glued together - keep rewriting until the whole line means one thing.

5. Present 4-5 candidates **with one-line reasoning each** explaining what's woven in. Group them by angle (project-anchored vs content-anchored vs hybrid) so Pavel can quickly see the spread.

6. If Pavel likes the start but not the end (or vice versa), keep the part he likes and brainstorm only the variable half. Push toward double meanings and cinematic phrasing - Pavel responded well to those in past sessions.

7. After Pavel picks, instruct him to:
   - Rename the file: change `Lego Cubes NNN -.md` to `Lego Cubes NNN - <Chosen Title>.md` (in Obsidian, just rename the note - Obsidian will update wikilinks automatically)
   - Set `title: <Chosen Title>` in frontmatter (just the title, no episode prefix)

   You can offer to do this via Bash `mv` + Edit, but warn that doing it from the file system bypasses Obsidian's wikilink updater - safer to let Pavel rename in Obsidian. If no other notes link to this episode yet (likely the case for a freshly-created episode), `mv` is fine.

### Stage 5 - Find links

Goal: fill the `## Links` section with one link per bullet across all three sections, in note order: **General -> Content -> Projects** (since 033; before that only Content had links).

1. Walk through the bullets in the same order they appear in the note.
2. Pick the platform per item type:
   - **Movies, TV shows** -> IMDB. URL format: `https://www.imdb.com/title/ttXXXXXXX/`
   - **Games** (including DLC) -> Steam. URL format: `https://store.steampowered.com/app/XXXXXXX/<Slug>/`. If a game is not on Steam (rare), use rawg.io as fallback.
   - **Books** -> Goodreads. URL format: `https://www.goodreads.com/book/show/XXXXXXX-<slug>`
   - **Esports** (TI, EWC) -> Liquipedia, e.g. `https://liquipedia.net/dota2/The_International/2026`. A bullet naming two tournaments gets two links.
   - **Football** -> FotMob team page: `https://www.fotmob.com/teams/8455/overview/chelsea`
   - **Hardware bought** -> the vendor product page (`https://www.raspberrypi.com/products/raspberry-pi-5/`)
   - **Projects** -> GitHub repo. `gh repo list --limit 200 --json name,url,isPrivate` for Pavel's own (`pkarpovich/...`); Stephen's projects (Feud, Jeoparty) live under `BitAdventure/` and `Runaway-Games/` - find them with `gh api "user/repos?affiliation=collaborator,organization_member&per_page=100" --paginate`. Private repos are fine, Pavel keeps them. Work items (Project Sahara / DealCloud) get no link.
   - **Bullets that already wikilink a vault note** get no entry in Links - that wikilink is enough on its own. Bullets with nothing to link (a dead SD card) are simply skipped - or link the repo that holds the relevant code (`home-environment` for the backups that saved pi-alpha).
3. Run WebSearch in parallel for all external items - one search per item with the title and year, e.g. `"Dream Scenario" 2023 IMDB`, with `allowed_domains` set to the target site. Spawn all WebSearches in a single tool message to keep latency low.
4. From the results, pick the canonical title page URL (not mediaviewer/cast/reviews subpages).
5. Show the proposed list in chat first, flagging assumptions (which Pi model, which of several Feud repos), then Edit the `## Links` section. No descriptions on the links - just bare URLs (or wikilinks) as bullets.
6. Links are positional - nothing labels which URL belongs to which item, so the lists drift silently if a section is reordered afterwards. Pavel does reorder. Before Stage 7, re-read the note and realign Links to the current bullet order.

Reference - example Links block:
```markdown
## Links

- https://www.imdb.com/title/tt0458352/
- https://www.imdb.com/title/tt33612209/
- https://www.goodreads.com/book/show/51901147-the-ballad-of-songbirds-and-snakes
- https://store.steampowered.com/app/2109300/Resident_Evil_4__Separate_Ways/
```

### Stage 6 - Cover prompt for Nano Banana Pro

Goal: produce a LEGO-style image prompt for Pavel to feed into Nano Banana Pro (Gemini 3 Pro Image). All Lego Cubes covers follow a fixed LEGO brick diorama aesthetic - the variables are camera, subject, palette, and Easter eggs.

**Read `references/nano-banana-cover-prompt.md` before writing the prompt.** That file has the full Nano Banana Pro prompting principles, the Lego Cubes house style spec (style anchor, color palette by LEGO brick names, minifigure rules, past episode style calibration), the composition decision tree (single-scene vs multi-zone), the prompt assembly template, and iteration guidance. Loading it lazily keeps this skill body lean.

Workflow:

1. Extract the **central image** from the chosen title - the cover should literalize the title's main figure or concept.
2. Decide composition (single coherent scene vs multi-zone diorama) using the decision tree in the reference file. Default single-scene unless Pavel says otherwise.
   - **Give the scene a real place and a sense of scale.** A bare interior rendered on empty background reads as a room floating in a void - Pavel's first note on such a draft was "нет масштаба и деталей, комната не понятно где". Anchor it: put the room somewhere specific, open a wall or a window onto a wider view (a skyline, a horizon, terrain below), and add scale cues in that view - distant buildings, a helicopter, an antenna mast, rooftop details.
   - Where the content allows, borrow the location from the dominant Content item: for a Spider-Man month the room became the top floor of a New York skyscraper, styled as the "guy in the chair" control room that guides Peter through the earpiece.
   - Push density explicitly. Sparse renders come back when the prompt lists too few objects - name the equipment, the cabling, the desk clutter, and raise the piece count in the style anchor (5000+ rather than 3000) for interiors that should feel packed.
3. Build the prompt by filling the assembly template in the reference file. Include all required ingredients (subject, composition, action, location, style + lighting + text + aspect ratio).
4. Apply Nano Banana Pro best practices: prose over tag soup, explicit text rendering instructions, named LEGO brick colors, full sentences.
5. Weave in 2-3 subtle Easter eggs referencing other Content items - small props with named labels, posters, silhouettes. Not dominating the scene.
6. Output the prompt as a single fenced code block in chat (one-click copy), followed by a 3-5 bullet `## Что в нём заложено` summary so Pavel can decide whether to tweak.
7. If Pavel asks to change direction, update only the affected block of the prompt - keep the style anchor and lighting boilerplate stable.

The cover image filename, once Pavel generates it, follows the pattern `LEGO Cubes E029.jpg` (or `.jpeg`/`.png`) inside the vault. Frontmatter `cover:` and `## Logo` embed both reference this. Stage 6 stops at the prompt - generation and embedding are out of scope. Stage 7 picks the image back up to publish it on the NAS.

### Stage 7 - Publish to NAS (post-recording)

Goal: process the raw OBS recording into a streaming-ready file with metadata sidecars (image + nfo) so Plex/Kodi index the episode. Run this after the recording session is done.

Naming convention on NAS (differs from the vault):
- **Single-digit episode**: `LEGO Cubes E29.mp4`, NOT zero-padded `E029`. Vault uses padded `Lego Cubes 029 - <Title>.md` for sortability, NAS does not.
- Per-episode files: `LEGO Cubes E<N>.mp4`, `LEGO Cubes E<N>.jpg`, `LEGO Cubes E<N>-thumb.jpg`, `LEGO Cubes E<N>.nfo` (all four required).

Steps:

1. Find the source recording. OBS writes to `/Users/pavel.karpovich/Movies/YYYY-MM-DD_HH-MM-SS.mp4`. Pick the largest file from today (small <100MB files are throwaway tests):
   ```bash
   ls -lt /Users/pavel.karpovich/Movies/$(date +%Y-%m-%d)*.mp4
   ```
   If multiple plausible candidates, ask Pavel which one is the real recording.

2. Remux with `+faststart`. This rewrites the file with the moov atom at the front so streaming/seek works without downloading the whole file. No re-encode (`-c copy`), so it runs at ~250-300x speed:
   ```bash
   ffmpeg -i "<source>.mp4" -c copy -movflags +faststart "/Users/pavel.karpovich/Movies/LEGO Cubes E<N>.mp4"
   ```
   Watch the ffmpeg output - capture these for the nfo:
   - `Duration: HH:MM:SS.SS` -> total seconds for `<durationinseconds>`, rounded minutes for `<runtime>`
   - Resolution (`3840x2160` -> `<width>3840</width><height>2160</height><resolution>4K</resolution>`)
   - Codec (`h264`), audio codec (`aac`), audio channel count (stereo -> 2)

3. Copy files to NAS. The .mp4 is 15-25 GB, so run that one in the background while you do the rest:
   ```bash
   cp "<image-source>" "/System/Volumes/Data/mnt/nas/media/me/LEGO Cubes/LEGO Cubes E<N>.jpg"
   cp "<image-source>" "/System/Volumes/Data/mnt/nas/media/me/LEGO Cubes/LEGO Cubes E<N>-thumb.jpg"
   # mp4 in background - expect 40-75 minutes over the network mount (~5 MB/s observed):
   cp "/Users/pavel.karpovich/Movies/LEGO Cubes E<N>.mp4" "/System/Volumes/Data/mnt/nas/media/me/LEGO Cubes/LEGO Cubes E<N>.mp4"
   ```
   The two .jpg copies are byte-identical content; both names exist because Plex/Kodi look for either, mirroring the pattern of past episodes (E24+ have both `E<N>.jpg` and `E<N>-thumb.jpg`).

   The cover image source: by the time Stage 7 runs Pavel has usually already embedded it, so it lives in the vault at `Attachments/LEGO Cubes E0NN.jpg` (zero-padded there, unlike the NAS names). Obsidian often leaves **two** files, `LEGO Cubes E0NN.jpg` and `LEGO Cubes E0NN 1.jpg`, with frontmatter `cover:` pointing at one and the `## Logo` embed at the other - `md5` them, and when they match (they have every time) just use either. Otherwise the source is `~/Downloads/Generated Image *.jpg` from Nano Banana Pro; if Pavel attached an image in chat, ask for the local path.

   **Long background copies get killed here.** Multi-GB `cp` runs have been stopped mid-flight repeatedly (session teardown leaves no completion record), leaving a truncated file on the NAS. Do not restart from zero - an interrupted `cp` writes a correct prefix, so resume:
   ```bash
   L="/Users/pavel.karpovich/Movies/LEGO Cubes E<N>.mp4"
   NAS="/System/Volumes/Data/mnt/nas/media/me/LEGO Cubes/LEGO Cubes E<N>.mp4"
   nn=$(stat -f %z "$NAS"); echo "aligned: $((nn % 1048576))  blocks: $((nn / 1048576))"
   dd if="$L" of="$NAS" bs=1m skip=<blocks> seek=<blocks> conv=notrunc
   ```
   The partial size has been an exact multiple of 1 MiB every time, so `bs=1m` with equal `skip`/`seek` splices cleanly; `conv=notrunc` is what keeps it an append instead of a rewrite. macOS ships openrsync, which has no `--append-verify`, so `dd` is the tool. Repeat as needed - each round keeps the progress. If Pavel is around, suggest he run the copy himself from his own shell (`! cp ...`), which is not subject to agent teardown.

4. Build the nfo. **Read the previous episode's nfo** (`LEGO Cubes E<N-1>.nfo`) before writing - it is the canonical layout to mirror exactly. Source the title and plot from the vault note (`Lego Cubes NNN - <Title>.md`).

   Plot field formatting (this is what makes Stage 7 different from a simple copy-paste):
   - Sections, each labeled and separated by a blank line, in this order: `General:` (only if the vault note has a non-empty `### General`), then `Content:`, then `Projects:`. Every bullet line gets a 2-space indent (matches E28's nfo style - E28 included all three sections; E29 had no General so its nfo had only Content + Projects). Do not drop `General` when the note has it - Pavel flags this.
   - **Strip all `[[...]]` wikilink syntax**. For Content bullets `- <hook> - [[Title (Year)]]`, the link target becomes plain text: `Title (Year)`. For Projects bullets that mention `[[Tuclaw]]`, `[[Glitch]]`, etc., drop just the brackets: `Tuclaw`, `Glitch`.
   - Sub-bullets (dilogies, marathons) keep their 4-space indentation under the parent. Add a trailing `:` on the parent line for readability (e.g., `- Дилогия Devil Wears Prada перед выходом второго:`).
   - **Escape `&` as `&amp;`** in titles like `The Hunger Games - The Ballad of Songbirds &amp; Snakes (2023)` (XML requires it).
   - Do NOT include the `## Links` section, frontmatter, or anything else from the vault note. Just General (if present) + Content + Projects.

   Other nfo fields:
   - `<title>` and `<originaltitle>`: same value, the chosen episode title (no `Lego Cubes` prefix, no episode number).
   - `<showtitle>LEGO Cubes</showtitle>`, `<season>1</season>`, `<episode>N</episode>`, and `<group episode="N" id="AIRED" name="" season="1"/>` (note: `<episode>` integer, not padded).
   - `<premiered>` and `<aired>`: recording date as `YYYY-MM-DD`.
   - `<dateadded>`: same date with time `YYYY-MM-DD HH:MM:SS`.
   - Stream details: codec/aspect/width/height/resolution/durationinseconds from Step 2's ffmpeg output. Aspect for 3840x2160 is `1.78`.
   - `<original_filename>LEGO Cubes E<N>.mp4</original_filename>`.

5. Verify all 4 files landed correctly:
   ```bash
   ls -la "/System/Volumes/Data/mnt/nas/media/me/LEGO Cubes/LEGO Cubes E<N>"*
   ```
   The .mp4 size on NAS must match the local source byte-for-byte (network copies can stall).

   **If the copy was ever interrupted and resumed, size alone is not proof.** Note the trap: `+faststart` puts the moov atom at the front, so a truncated file still reports the full duration under `ffprobe` - that check cannot detect a missing tail. Spot-check the actual bytes instead, reading only ~150 MB back over the mount:
   ```bash
   chk() { dd if="$1" bs=1m skip=$2 count=$3 2>/dev/null | md5 -q; }
   # head (moov), a window around each splice offset, and the tail
   for r in "0 8" "<splice_blocks-25> 50" "<last_blocks-40> 41"; do
     set -- $r; [ "$(chk "$L" $1 $2)" = "$(chk "$NAS" $1 $2)" ] && echo "OK $1" || echo "FAIL $1"
   done
   ```
   Compare a window centred on every offset where a copy was resumed, plus the head and the tail. Matching size + matching splice windows + matching tail is enough; a full 22 GB `md5` over the mount would take as long as the copy itself.

Stop after this stage. The local Movies copy stays as a backup; don't delete it. The original raw `YYYY-MM-DD_HH-MM-SS.mp4` from OBS also stays - Pavel cleans those up himself later.

### Stage 8 - Archive impressions to References

Goal: move the per-content impression files for this episode from `Tuclaw/Podcast/` to `References/`. This happens AFTER publishing (Stage 7), when the impressions are no longer "upcoming material" but historical record.

What gets moved: **only files with a written review body**. Skip stubs (frontmatter only with `status: watching/playing/on hold` and no impression text under the `> Mentioned in` line). Those are works-in-progress that may roll over into a future episode - they stay in `Tuclaw/Podcast/`.

Steps:

1. List all files in `Tuclaw/Podcast/` marked for this episode:
   ```bash
   cd "/Users/pavel.karpovich/Obsidian/PK Workspace/Tuclaw/Podcast" && for f in *.md; do
     grep -l "Lego Cubes NNN" "$f" 2>/dev/null
   done
   ```
   (Substitute the 3-digit padded episode number.)

2. Filter to filled-in files. A reliable heuristic: file size. Stubs are <500 bytes (~20 lines of just frontmatter + the mention line); filled impressions are 1500+ bytes. Verify with:
   ```bash
   for f in <matching files>; do echo "$(wc -l < "$f") lines | $(stat -f %z "$f") bytes | $f"; done | sort -n
   ```
   Anything under ~25 lines or 500 bytes is almost certainly a stub - Read it to confirm before deciding. Tell Pavel which ones you're skipping and why.

3. Cross-check against the published episode's `### Content` section. Every Content bullet's wikilinked file should be in the move list; if a file is in Content but not in your move list, that is a bug - stop and investigate.

4. Move the filled files in one batch:
   ```bash
   cd "/Users/pavel.karpovich/Obsidian/PK Workspace" && for f in "<title 1>.md" "<title 2>.md" ...; do
     mv "Tuclaw/Podcast/$f" "References/$f" && echo "moved: $f"
   done
   ```
   `References/` is flat (no subfolders). Filesystem `mv` is safe here because the basename is unchanged - Obsidian's `[[Title (Year)]]` wikilinks resolve by shortest unique name and survive the move without rewriting.

5. Verify - the moved titles should no longer appear in `Tuclaw/Podcast/`:
   ```bash
   ls "/Users/pavel.karpovich/Obsidian/PK Workspace/Tuclaw/Podcast/"
   ```
   Only stubs (and impressions for the NEXT episode) should remain. List the remaining stubs so Pavel can see what is queued for the next round.

6. **Roll the stubs forward.** Stubs marked for THIS episode obviously won't make it - they have no review body and the episode is already published. Update their `> Mentioned in [[Lego Cubes NNN - <Title>]]` line to point to the next episode in bare form: `> Mentioned in [[Lego Cubes <NNN+1> -]]` (trailing dash, no title - the next episode file doesn't exist yet, but the wikilink will resolve once Pavel creates it via Templater).

   Find stubs to roll: any remaining file in `Tuclaw/Podcast/` whose `Mentioned in` line still names the just-published episode. Older episodes' stubs may also still be here (rolled forward repeatedly across episodes - that's fine, just bump them all to the next episode).

   ```bash
   cd "/Users/pavel.karpovich/Obsidian/PK Workspace/Tuclaw/Podcast" && for f in *.md; do
     grep "Mentioned in" "$f"; echo " | $f"
   done
   ```
   Then Edit each file's Mentioned line. Confirm afterward that every remaining stub points to the next episode.

End of skill. The episode is fully prepped, published, and archived; rolled-over stubs are queued for the next round.

## Workflow philosophy

- **Pace it like a checklist with check-ins, not a one-shot dump.** Pavel always reviews the Content block before it lands in the file, always wants 3-5 title options to compare, and often iterates twice on the cover prompt. Bake those pause points in.

- **Read multiple files in parallel.** Stages 2, 3 and 5 all have list operations - issue all the Read or WebSearch calls in a single tool message. Pavel notices latency.

- **When in doubt about stylistic conventions, look at episodes 024-028.** Those are the canonical recent style. The earlier episodes (001-021) used different conventions and should not be mimicked for current work.

- **Pavel writes in Russian, prefers informal voice.** Don't formalize his hooks. Keep grammar but allow casual phrasing ("зашло", "крепкая восьмёрка", "не докрутили", "слили концовку"). Mirror his vocabulary from the source impressions.

- **The skill stops after the cover prompt.** Image generation, file uploads, publishing - all out of scope. Just hand off the prompt and confirm the episode note is fully populated.

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
