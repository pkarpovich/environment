---
name: ralphex-farm
description: >
  Work with ralphex-farm: an autonomous executor that polls Linear, picks up
  Todo issues whose description carries a `<!-- ralphex-farm -->` YAML block,
  runs ralphex against the named plan inside Docker, and opens a PR. Invoke
  whenever the user wants to: create a Linear ticket for a plan ("создай
  тикет в ферме", "create ralphex farm task", "add task for plan", "запусти
  план через ферму"), add a new repository to the farm ("добавь репо в
  ферму", "add repo to ralphex farm", "register repo in farm"), debug why a
  ticket was not picked up, or generally answer questions about how the farm
  works. Also trigger on any mention of the `<!-- ralphex-farm -->` metadata
  block, repos.yaml in the farm context, or `/var/ralphex/...` host paths.
metadata:
  version: "0.0.1"
---

# ralphex-farm

Operator skill for the ralphex-farm runner (https://github.com/pkarpovich/ralphex-farm).

## What the farm does (one paragraph)

Polls one Linear team every N minutes (default 5m). For each issue in `Todo`
whose description contains a valid `<!-- ralphex-farm -->` metadata block, it
runs ralphex inside a Docker container against the named plan in the named
repo, then pushes a feature branch, opens a GitHub PR, comments the PR URL
back on the Linear issue, and moves the issue to `In Review`. On any failure
the issue moves to `Error` with a comment.

The farm is stateless — Linear is the source of truth. Repo clones live at
`<repos-root>/<name>` on the host (the operator picks the root, conventionally
`/var/ralphex/repos`).

## The metadata block

This is the single most important piece. The farm does a strict regex match.
Get this wrong and the issue is silently skipped.

```
<!-- ralphex-farm
repo: <linear_slug>
plan: <repo-relative-path-to-plan-md>
-->
```

Rules:
- `<!--` and `-->` markers each on their own line.
- `repo` matches a `linear_slug` (or repo key) in the operator's `repos.yaml`.
- `plan` is repo-relative and the file MUST exist on the repo's default branch
  (the farm does `git fetch && reset --hard origin/<default>` before checking).
- The first matching block wins; the rest of the description is free-form.

## Workflow A: Create a Linear ticket for a plan

Use this when the user has a plan committed somewhere and wants the farm to
execute it.

### Pre-flight — verify the plan is on the default branch

This is the #1 reason tickets do not get picked up. Even if the user has
pushed the plan to a feature branch, the farm runs `git reset --hard
origin/<default>` first, so anything outside the default branch is invisible.

Check before creating the ticket:

```bash
gh api "repos/<owner>/<repo>/contents/<plan-path>?ref=<default-branch>" --jq .path
```

If 404, stop and tell the user. Offer the cheapest fix:

- Single-commit feature branch with just the plan → cherry-pick or merge to
  default. Plans are documents; merging them alone is not risky.
- Plan mixed with implementation commits → open a small PR with only the plan
  file, merge it, then create the ticket.

Also check the user has not pre-created the implementation branch. The farm's
ralphex container will create its own branch (typically derived from the plan
filename) and push it. A pre-existing branch with the same name causes a push
conflict at the end. Ask the user to delete it.

### Find the Linear team

The farm runs against ONE team (set by `LINEAR_TEAM_ID` in the operator's
`.env`). The skill does not store this — discover at runtime:

```
mcp__claude_ai_Linear__list_teams
```

If the operator has only one team that fits the farm naming convention (often
contains "ralphex" or "farm"), use it. Otherwise, present the list and ask the
user to pick. Cache the choice for the rest of the session.

### Create the issue

Use `mcp__claude_ai_Linear__save_issue` (Linear MCP must be authenticated;
if not, tell the user to run `/mcp` and pick the Linear connector). Fields:

- `team`: the team ID from above.
- `title`: short, action-oriented. Use the plan commit message subject if
  available, not the filename.
- `state`: `Todo`. Anything else and the poller skips it.
- `description`: metadata block FIRST (so the poller's regex catches it
  cleanly), then a human summary, then a link to the plan on the default
  branch.

Description template:

```markdown
<!-- ralphex-farm
repo: <linear_slug>
plan: <repo-relative-plan-path>
-->

<one-paragraph summary of what the plan does — pull from the commit
message that introduced the plan, or ask the user>

Plan: [<relative-path>](<https-url-to-plan-on-default-branch>)
```

Pass the description as raw markdown — do NOT escape newlines. The Linear
MCP server requires literal newlines.

### After creation

Report the issue identifier (e.g. `XYZ-3`) and URL. Mention the poll cadence
("up to 5 min by default") and that the user can restart the farm container
to force an immediate poll: `docker compose restart farm` on the host running
the farm.

## Workflow B: Add a new repository to the farm

Use this when `repo:` in a metadata block names a slug that is not yet in
`repos.yaml`. All steps run on the host running the farm (typically a small
home server / RPi reachable over SSH).

### 1. Clone the repo

Conventional layout (operator may differ — confirm with the user if unsure):

```fish
sudo mkdir -p /var/ralphex/repos
cd /var/ralphex/repos
sudo git clone <clone-url> <name>
sudo chown -R <app-uid>:<app-uid> <name>
```

`<app-uid>` must match the uid that owns the OTHER repos in this directory.
The farm auto-detects this uid from the directory owner and passes it into
the ralphex container as `APP_UID` so files written back to `/workspace` end
up owned by the same host user. Mixed ownership across repos breaks the
shared `RALPHEX_CONFIG_DIR` write-back. If unsure, run `stat -c '%u' *` in
the repos root and use the same uid (commonly `1000`).

For private repos use SSH (`git@github.com:...`) — the farm container mounts
`~/.ssh` from the host.

### 2. Add to `repos.yaml`

Edit the file referenced by `REPOS_CONFIG_PATH` in the farm's `.env`
(conventionally `/opt/ralphex-farm/repos.yaml` on the host, mounted into the
farm container at `/etc/farm/repos.yaml`).

```yaml
<key>:
  clone_url: <https-or-git@-url>
  local_path: /var/ralphex/repos/<name>   # absolute, must match step 1
  default_branch: <main|master|...>       # gh repo view --json defaultBranchRef
  # linear_slug: <slug>                   # defaults to <key>; only set if you
                                          # want a different value in the
                                          # ticket's metadata block
  # image: <registry>/ralphex-mise:latest # only to override RALPHEX_IMAGE
```

Validation rules the farm enforces (taken from
`pkg/config/config.go::LoadRepos`):
- `clone_url`, `local_path`, `default_branch` are required.
- `local_path` must be absolute.
- `linear_slug` (defaults to key) must be unique across the file.

### 3. Apply

```fish
cd /opt/ralphex-farm   # or wherever docker-compose.yml lives
docker compose restart farm
docker compose logs --tail=50 farm
```

The farm validates `repos.yaml` at startup; if the file is malformed it
refuses to start (clear error in logs). On success the log shows the loaded
repo count.

Health check: `curl http://localhost:7077/health` (port from `FARM_HEALTH_PORT`).

## Critical gotchas (read before doing anything)

These come from real failures. None of them surface as obvious errors — the
farm just silently skips or fails opaquely.

1. **Plan not on default branch.** Farm resets to `origin/<default>` before
   looking. Plan on a feature branch = `plan file not found`.
2. **Pre-created implementation branch.** Ralphex creates and pushes its own
   branch from the plan filename. A pre-existing remote branch with the same
   name = push conflict at the end of an otherwise successful run.
3. **Wrong Linear team.** The farm polls ONE team. Tickets in any other team
   are invisible. Always confirm `team` matches the operator's
   `LINEAR_TEAM_ID`.
4. **Wrong state.** Only `Todo` is picked up. Backlog / In Progress / etc.
   are skipped. Re-opening a closed ticket: move it back to `Todo` explicitly.
5. **Metadata block formatting.** `<!--` and `-->` MUST be on their own
   lines. Inline / single-line variants are not parsed.
6. **`linear_slug` mismatch.** The `repo:` value in the metadata block must
   match `linear_slug` (or the map key when slug is omitted) in `repos.yaml`.
   Easy typo — copy-paste both sides.
7. **`local_path` ownership.** All repos in the farm must be owned by the
   same uid. If a new repo is `chown root` and others are `chown 1000`, the
   farm writes config in the wrong place and writes back files no one can
   read.

## Discovering farm config (when hands-on)

If you have SSH access to the host and need to debug:

| What | Where |
|---|---|
| `.env` | `/opt/ralphex-farm/.env` (conventional) |
| `repos.yaml` (host) | path from `REPOS_CONFIG_PATH` in `.env` |
| `repos.yaml` (in container) | `/etc/farm/repos.yaml` (read-only mount) |
| Repo clones | `/var/ralphex/repos/<name>` (conventional) |
| Shared ralphex config | `RALPHEX_CONFIG_DIR` from `.env`, default `/var/ralphex/config` |
| Codex auth | `CODEX_CONFIG_DIR` from `.env`, default `/var/ralphex/codex` |
| Mise toolchain cache | `MISE_DATA_DIR` from `.env`, default `/var/ralphex/mise` |
| Health endpoint | `http://<host>:${FARM_HEALTH_PORT:-7077}/health` |
| Logs | `docker compose logs farm` from compose dir |

The `.env` file is the source of truth for everything tunable. When in doubt,
read it before guessing defaults.

## Anti-patterns (don't do)

- **Don't hardcode a Linear team ID** in the ticket-creation tool call.
  Always discover via `list_teams` first — the operator's setup is private.
- **Don't fabricate the human summary** in the description. If the plan
  commit message is short or unclear, ask the user instead of inventing.
- **Don't write the metadata block as a multiline string with escaped `\n`.**
  Linear's MCP wants literal newlines (server-side enforced).
- **Don't restart the farm without first confirming `repos.yaml` parses.**
  A typo will keep the container down. Test with `yq` or
  `python -c 'import yaml; yaml.safe_load(open("repos.yaml"))'` first.
- **Don't tell the user "it should pick up in 5 minutes"** without checking
  the actual `POLL_INTERVAL` in their `.env`. They may have changed it.
- **Don't suggest editing `local_path` after the fact** without re-cloning.
  The farm uses it as the docker bind source — changing it requires a
  matching directory move on the host or things break opaquely.

## Invocation triggers

Russian or English, any shape:
- "create a ralphex farm task for <plan>" / "создай тикет в ферме на <plan>"
- "add <repo> to the farm" / "добавь <repo> в ферму"
- "запусти план через ферму" / "run this plan via ralphex"
- "the farm is not picking up <issue>" / "ферма не берёт <issue>"
- "what slug should I use in repos.yaml" / similar config questions
- Any direct mention of `<!-- ralphex-farm`, `repos.yaml` in farm context, or
  paths under `/var/ralphex/`.
