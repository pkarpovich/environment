# After the recording - publishing and archival

Loaded by Stage 7 (publish to NAS) and Stage 8 (archive impressions). Nothing here is needed while preparing an episode.

## Naming on the NAS

Differs from the vault: the NAS **does not zero-pad**. `LEGO Cubes E29.mp4`, not `E029`. The vault pads (`Lego Cubes 029 - <Title>.md`) for sortability; the NAS does not.

Four files per episode, all required: `LEGO Cubes E<N>.mp4`, `LEGO Cubes E<N>.jpg`, `LEGO Cubes E<N>-thumb.jpg`, `LEGO Cubes E<N>.nfo`.

## Stage 7 - publish

### 1. Find the source recording

OBS writes `/Users/pavel.karpovich/Movies/YYYY-MM-DD_HH-MM-SS.mp4`. Take the largest file from the recording day - files under ~100 MB are throwaway tests.

```bash
ls -lt /Users/pavel.karpovich/Movies/$(date +%Y-%m-%d)*.mp4
```

If two plausible candidates exist, ask which one is the real recording.

### 2. Remux with +faststart

Moves the moov atom to the front so streaming and seeking work without downloading the whole file. No re-encode, so it runs at ~250-300x (a 3-hour 4K file takes under a minute).

```bash
ffmpeg -hide_banner -i "<source>.mp4" -c copy -movflags +faststart "/Users/pavel.karpovich/Movies/LEGO Cubes E<N>.mp4"
```

Capture from the ffmpeg output, for the nfo:

- final `time=HH:MM:SS.SS` -> total seconds for `<durationinseconds>`, rounded minutes for `<runtime>`
- resolution (`3840x2160` -> width/height, `<resolution>4K</resolution>`)
- video codec (`h264`), audio codec (`aac`), channel count (stereo -> 2)

### 3. Copy to the NAS

The cover image is usually already embedded in the vault by now: `Attachments/LEGO Cubes E0NN.jpg` (zero-padded there, unlike the NAS names). Obsidian sometimes leaves **two** files, `LEGO Cubes E0NN.jpg` and `LEGO Cubes E0NN 1.jpg`, with frontmatter `cover:` pointing at one and the `## Logo` embed at the other - `md5` them, and when they match (they always have) use either. Otherwise the source is `~/Downloads/Generated Image *.jpg` from Nano Banana Pro; if Pavel attached the image in chat, ask for the local path.

```bash
cp "<image-source>" "/System/Volumes/Data/mnt/nas/media/me/LEGO Cubes/LEGO Cubes E<N>.jpg"
cp "<image-source>" "/System/Volumes/Data/mnt/nas/media/me/LEGO Cubes/LEGO Cubes E<N>-thumb.jpg"
```

Both .jpg names hold identical bytes; Plex and Kodi look for either, and every episode from E24 on has both.

The .mp4 is 15-25 GB and takes 40-75 minutes over the mount (~5 MB/s observed). **Ask Pavel to run that copy from his own shell** (`! cp ...`) - it is then immune to agent session teardown:

```bash
cp "/Users/pavel.karpovich/Movies/LEGO Cubes E<N>.mp4" "/System/Volumes/Data/mnt/nas/media/me/LEGO Cubes/LEGO Cubes E<N>.mp4"
```

**If a copy dies mid-flight**, do not restart from zero - an interrupted `cp` leaves a correct prefix, so splice the rest on:

```bash
L="/Users/pavel.karpovich/Movies/LEGO Cubes E<N>.mp4"
NAS="/System/Volumes/Data/mnt/nas/media/me/LEGO Cubes/LEGO Cubes E<N>.mp4"
nn=$(stat -f %z "$NAS"); echo "aligned: $((nn % 1048576))  blocks: $((nn / 1048576))"
dd if="$L" of="$NAS" bs=1m skip=<blocks> seek=<blocks> conv=notrunc
```

The partial size has been an exact multiple of 1 MiB every time, so `bs=1m` with equal `skip`/`seek` splices cleanly; `conv=notrunc` keeps it an append instead of a rewrite. macOS ships openrsync, which has no `--append-verify`, so `dd` is the tool. Repeat as needed - each round keeps the progress.

### 4. Build the nfo

**Read the previous episode's nfo** (`LEGO Cubes E<N-1>.nfo`) first - it is the canonical layout to mirror exactly. Title and plot come from the vault note.

Plot field formatting (this is what makes the stage more than a copy-paste):

- Sections labeled and separated by a blank line, in the order they appear in the vault note (`General:`, `Projects:`, `Content:` in 033; `General:`, `Content:`, `Projects:` in 028). Every bullet line gets a 2-space indent. Do not drop `General` when the note has one - Pavel flags this.
- **Strip all `[[...]]` syntax.** `- <hook> - [[Title (Year)]]` becomes `- <hook> - Title (Year)`; `[[Tuclaw]]` becomes `Tuclaw`.
- Sub-bullets keep their 4-space indentation under the parent, and the parent gets a trailing `:` for readability (`- Дилогия Devil Wears Prada перед выходом второго:`).
- **Escape `&` as `&amp;`** - `The Ballad of Songbirds &amp; Snakes (2023)`. XML requires it.
- Nothing else from the note: no `## Links`, no frontmatter.

Other fields:

- `<title>` and `<originaltitle>`: the episode title alone - no `Lego Cubes` prefix, no number.
- `<showtitle>LEGO Cubes</showtitle>`, `<season>1</season>`, `<episode>N</episode>`, `<group episode="N" id="AIRED" name="" season="1"/>` - integer, not padded.
- `<premiered>` and `<aired>`: recording date `YYYY-MM-DD`. `<dateadded>`: same date plus `00:00:00`.
- Stream details from step 2. Aspect for 3840x2160 is `1.78`.
- `<original_filename>LEGO Cubes E<N>.mp4</original_filename>`.

Validate before moving on: `xmllint --noout "<nfo>"`.

### 5. Verify

```bash
ls -la "/System/Volumes/Data/mnt/nas/media/me/LEGO Cubes/LEGO Cubes E<N>"*
```

The .mp4 size on the NAS must match the local source byte for byte.

**Size alone is not proof if the copy was ever interrupted and resumed.** The trap: `+faststart` puts the moov atom at the front, so a truncated file still reports full duration under `ffprobe` - that check cannot see a missing tail. Spot-check the bytes instead, reading back only ~50-150 MB:

```bash
chk() { dd if="$1" bs=1m skip=$2 count=$3 2>/dev/null | md5 -q; }
blocks=$(( $(stat -f %z "$NAS") / 1048576 ))
[ "$(chk "$L" 0 8)" = "$(chk "$NAS" 0 8)" ] && echo "HEAD OK" || echo "HEAD FAIL"
[ "$(chk "$L" $((blocks-40)) 41)" = "$(chk "$NAS" $((blocks-40)) 41)" ] && echo "TAIL OK" || echo "TAIL FAIL"
```

Compare a window centred on every offset where a copy was resumed, plus head and tail. Matching size + matching splice windows + matching tail is enough; a full 25 GB `md5` over the mount would take as long as the copy itself.

Leave both local files in place - the remuxed copy is the backup, and Pavel clears the raw OBS file himself later.

## Stage 8 - archive impressions

Moves this episode's impression files from `Tuclaw/Podcast/` to `References/`, after publishing, when they stop being upcoming material and become record.

**Only files with a written review body move.** Stubs - frontmatter plus the `> Mentioned in` line, usually `status: watching/playing/on hold` - stay put; they are works in progress that roll into a future episode.

1. List the candidates with sizes. Stubs run under ~500 bytes (~20 lines); real impressions are 1500+ bytes. Read anything borderline before deciding, and tell Pavel what is being skipped and why:

```bash
cd "/Users/pavel.karpovich/Obsidian/PK Workspace/Tuclaw/Podcast" && for f in *.md; do
  m=$(grep -o "Lego Cubes [0-9]\+" "$f" | head -1); printf "%s | %5s b | %s\n" "${m:-NO MENTION}" "$(stat -f %z "$f")" "$f"
done | sort -t'|' -k2 -n
```

2. Cross-check against the published `### Content`: every wikilinked file there must be in the move list. A Content entry missing from the list is a bug - stop and investigate. The counts matching (15 bullets, 15 files in 033) is the signal to proceed.

3. Move them, guarding against silent overwrites - `References/` is flat, and a same-named file there would be clobbered:

```bash
cd "/Users/pavel.karpovich/Obsidian/PK Workspace" && for f in "<title 1>.md" "<title 2>.md"; do
  if [ -e "References/$f" ]; then echo "COLLISION, skipped: $f"; else mv "Tuclaw/Podcast/$f" "References/$f"; fi
done
```

Filesystem `mv` is safe for the links: the basename does not change, and Obsidian resolves `[[Title (Year)]]` by shortest unique name.

4. **Roll the stubs forward.** Whatever stayed behind will not make this episode, so point it at the next one: `> Mentioned in [[Lego Cubes <NNN+1> -]]` - bare, trailing dash, no title, since that note does not exist yet. The wikilink resolves once Pavel creates it via Templater. Read the actual lines first rather than assuming their form - after an episode is renamed, Obsidian rewrites the link inside every card that referenced it, so stubs usually carry the full title:

```bash
cd "/Users/pavel.karpovich/Obsidian/PK Workspace/Tuclaw/Podcast" && for f in *.md; do
  printf "%-45s %s\n" "$f" "$(grep -o '> Mentioned in .*' "$f")"
done
```

Older stubs rolled forward across several episodes may also be sitting there - bump them all. A card that arrived from another machine after the rename can still carry the stale `[[Lego Cubes NNN - ]]` stub form; fix it to the full title before moving the file.

5. Verify: only stubs (and material for the next episode) remain in `Tuclaw/Podcast/`, each pointing at the next episode, and every moved title is present in `References/`.
