---
name: github-radar
description: >-
  Cross-repo GitHub radar - a personal snapshot of the open pull requests and
  issues that involve you, run from any directory (account-wide, not tied to the
  current repo). Covers your own repos (every open PR/issue, any author) plus
  anywhere you are involved on other people's repos (authored, assigned,
  mentioned, or review-requested). Use this whenever the user wants a GitHub
  overview or status, asks what PRs or issues need their attention, what is
  waiting on them, what they have open on GitHub, what they might be forgetting,
  before standup, or when catching up after time away - including phrasings like
  "github radar", "my open PRs", "anything waiting on me on github", "what did I
  leave open", even if they don't name a specific repo. Also supports an optional
  single-repo scope - when the user names one repository ("github radar for
  turtle-hub", "what's open in pkarpovich/tuclaw", "PRs and issues in <repo>"),
  pass that repo and the report covers only it.
---

# GitHub radar

A maintenance-light overview of everything on GitHub that involves you, across
every repo at once. No state is kept - it is a fresh snapshot each run, so it is
safe to run as often as you like. The point is to surface, in one glance, the
PRs waiting on your review and the work you have open or were asked to do, while
keeping the firehose of dependency-bot PRs out of the way.

## How it works

Run the bundled script - it does all the `gh` queries, merges and de-duplicates
them, classifies automated/bot PRs, and emits one JSON object:

```bash
bash scripts/radar.sh             # account-wide (default)
bash scripts/radar.sh owner/repo  # scope to a single repo
```

When the user names a specific repo, pass it as `owner/repo` (resolve a bare
"turtle-hub" to `<login>/turtle-hub`, or use the owner they gave). The JSON gains
a top-level `scope` - `"account"` or the repo. In single-repo mode every item is
under `mine` and `elsewhere` is empty.

Requires `gh` (authenticated) and `jq`. If either is missing, or `gh` is not
logged in, the script prints `{"error": "..."}` - relay that to the user instead
of rendering an empty report.

The JSON shape:

- `login`, `generatedAt`, `counts`
- `mine`: `prs[]` + `issues[]` in the user's own repos (`<login>/*`)
- `elsewhere`: `prs[]` + `issues[]` in OTHER people's repos where the user is involved
- each PR has `automated` (bot / dependency churn), `isDraft`, `reviewRequestedFromMe`
- each item has `repo`, `number`, `title`, `url`, `author`, `labels`, `updatedAt`, `ageDays`, `stale`
- `stale == true` means nothing has touched it in `counts.stale_days` days (default 60, override with the `RADAR_STALE_DAYS` env var) - these are almost always dead threads in abandoned repos and are the main source of noise

## Output

Render a compact terminal report from the JSON. Keep it tight - this is a glance
tool, not a wall of text. Use this structure:

```
## GitHub radar - <login>  (<generatedAt, local time>)
<summary line>

### Needs your review (<n>)        # omit the whole section if n == 0
- owner/repo#<num> <title> - @<author> <flags> [<ageDays>d]

### Your repos
**owner/repo**
- PR #<num> <title> - @<author> <flags> [<ageDays>d]
- issue #<num> <title>  [<labels>]

### Elsewhere - you're involved
**owner/repo**
- PR #<num> <title> - @<author> <flags> [<ageDays>d]

_Hidden: <n> automated - <m> stale (>Nd). Ask to show._
```

Rules that make it useful:

- **Summary line** under the title, from `counts`: e.g. `0 review requests live - 4 PRs + 1 issue in your repos - 0 live elsewhere - 79 automated + 42 stale hidden`. Be honest when a bucket is zero - that itself is the signal ("nothing waiting on you").
- **Show only what is live.** Every section lists only `stale == false` items (and, for PRs, `automated == false`). Staleness is the whole point - an open thread nobody has touched in two months, or a review request from two years ago on a dead repo, is noise, not a to-do. Everything filtered out is *collapsed, never dropped*: end with one line `_Hidden: <counts.mine_prs_auto> automated - <counts.stale_hidden> stale (>{counts.stale_days}d). Ask to show._` and list them only if asked.
- **Sort by recency.** Within each section sort items freshest first (smallest `ageDays`), and order repos by their freshest item. The thing you touched yesterday should be at the top, not buried under alphabetical order.
- **Needs your review** comes first - it is the only bucket where you are blocking someone. Include `reviewRequestedFromMe == true` items from both `mine` and `elsewhere`, **subject to the same staleness filter** (a 600-day-old review request is dead). If none are live, omit the section.
- **Your repos**: live human PRs + issues, grouped by repo.
- **Elsewhere**: live PRs + issues in other people's repos - the "I opened something there / they pulled me in and I forgot" cases. If everything there is stale, say so in one line rather than an empty header.
- **Single-repo mode** (`scope != "account"`): title it `## GitHub radar - <scope>` and drop the "Your repos / Elsewhere" split - it is one repo, so just list its live PRs + issues (all under `mine`). Since the user explicitly chose this repo, do not hide stale items - show them with their `[Nd]` age; only the automated dependency PRs stay collapsed.
- **Flags** after a PR: `<review-me>`, `(draft)`. Show `[<ageDays>d]` so age is visible at a glance. Keep it all terse.
- Trim long titles (~60 chars). Make `owner/repo#num` a real link to `url` when the surface renders markdown links; plain text is fine otherwise.
- If a whole bucket is empty after filtering, say so in one short line.

## Notes

- Account-wide: the current working directory is irrelevant; never restrict to the repo you happen to be in.
- "Your repos" uses `--owner=<login>` (personal repos). PRs/issues in org repos where you participate still surface via the involvement queries under "Elsewhere".
- Bot/dependency classification is a heuristic (bot logins, `dependencies` label, `[Snyk]` / `chore(deps)` titles). If something is misclassified, it is safe - the item is only moved between "shown" and the collapsed line, never dropped.
- Staleness window defaults to 60 days; raise it with `RADAR_STALE_DAYS=120 bash scripts/radar.sh` when catching up after a long break, or lower it for a tighter "this week" view. Stale items are collapsed into the count, so widening the window resurfaces them.
