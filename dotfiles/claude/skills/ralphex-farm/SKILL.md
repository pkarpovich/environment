---
name: ralphex-farm
description: >
  Work with ralphex-farm: an autonomous executor that polls Linear, picks up
  Todo issues whose description carries a `<!-- ralphex-farm -->` YAML block
  (repo + plan + branch, optional mode), runs ralphex against the named plan
  inside Docker, and opens a PR. Invoke whenever the user wants to: create a
  Linear ticket for a plan ("create a ralphex farm task", "add task for plan",
  "queue plan to the farm"), re-run or recover a failed task ("re-run", "recover",
  "review only", "move back to Todo"), add a new repository to the farm, trigger
  an immediate sync, debug why a ticket was not picked up, or answer questions
  about how the farm works. Also trigger on any mention of the
  `<!-- ralphex-farm -->` metadata block, repos.yaml in the farm context,
  `/var/ralphex/...` host paths, the farm's `/api/sync` or `/api/repos`
  endpoints, or Claude plugin provisioning in the farm.
allowed-tools:
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git push:*)
metadata:
  version: "0.2.2"
---

# ralphex-farm

Operator skill for the ralphex-farm runner (https://github.com/pkarpovich/ralphex-farm).

## What the farm does

Polls one Linear team every N minutes (default 5m). For each issue in `Todo`
whose description contains a valid `<!-- ralphex-farm -->` metadata block, it
runs ralphex inside a Docker container against the named plan in the named
repo, on the branch named in the block, then pushes that feature branch, opens
a GitHub PR, comments the PR URL back on the Linear issue, and moves the issue
to `In Review`. On any failure the issue moves to `Error` with a comment. On a
transient Claude rate-limit/overload it waits and retries instead of dying
(`RALPHEX_WAIT_ON_LIMIT`, default 30m).

The farm is stateless - Linear is the source of truth. Repo clones live at
`<repos-root>/<name>` on the host (the operator picks the root, conventionally
`/var/ralphex/repos`).

## The metadata block

The farm matches this block with a strict regex and requires `repo`, `plan`, and
`branch`. Omit any one (or get a value wrong) and the issue is silently skipped -
the one failure that surfaces no error anywhere, so it is worth getting right.

```
<!-- ralphex-farm
repo: <linear_slug>
plan: <repo-relative-path-to-plan-md>
branch: <feature-branch-name>
mode: review
-->
```

Rules:
- `<!--` and `-->` markers each on their own line.
- `repo` matches a `linear_slug` (or repo key) in the operator's `repos.yaml`.
- `plan` is repo-relative; the file must exist on the repo's default branch (the
  farm does `git fetch && reset --hard origin/<default>` before checking).
- `branch` is the feature branch name, and the single source of truth: the farm
  passes it to ralphex via `--branch` so both sides use the exact same name (this
  replaced the old derive-from-filename logic that caused push failures). It must
  differ from the repo's default branch.
- `mode` is optional. Only `review` or empty are valid (any other value rejects
  the block and the issue is skipped). `mode: review` = review-only recovery
  (Workflow C); omit it for a normal full run.
- The first matching block wins; the rest of the description is free-form.

## Workflow A: Create a Linear ticket for a plan

Use this when the user has a plan and wants the farm to execute it.

### Step 1 - confirm the repo and its default branch (`GET /api/repos`)

Hit the farm's repos endpoint first to see which repos it actually serves and
each one's default branch - so you use a valid `repo:` slug and know whether the
default branch is `main` or `master` (needed for the plan-push step below, the
`gh api` check, and the plan link). No SSH needed:

```bash
curl -s https://ralphex-farm.pkarpovich.space/api/repos
# -> [{"slug":"turtle-hub","default_branch":"main"},{"slug":"ovq","default_branch":"master"}, ...]
```

If the target repo is not in the list, the farm does not serve it - run
Workflow B (add a repository) first. Otherwise use the returned `slug` for
`repo:` and the returned `default_branch` everywhere a default branch is
referenced below.

### Step 2 - put the plan on the default branch first

The farm runs `git reset --hard origin/<default>` and reads the plan from there,
so the plan file must exist on the repo's default branch (`main`/`master`) before
the ticket is picked up - this is the most common reason a ticket never runs.

So if the plan was just created and is not yet on the default branch, commit and
push the plan file to master/main, then create the ticket - in that order.

Invoking this skill right after a plan was created is itself the user's
authorization to land that plan on the default branch: stage only the plan file,
commit it (conventional message), and `git push origin <default>` directly -
proceed without stopping to ask for push permission or offering PR/manual
alternatives (the `allowed-tools` in this skill's frontmatter pre-approve these
git commands). Commit the plan file alone; never sweep other working-tree changes
into a default-branch push.

- If the plan is uncommitted in the target repo's working tree: stage just the
  plan file, commit it (conventional message), `git push origin <default>`.
- If the plan sits on a feature branch only: cherry-pick / open a tiny PR with
  just the plan file and merge it (plans are documents - merging them alone is
  safe), or push it straight to the default branch if direct pushes are allowed.
- If the plan lives in a different repo than the one running it (e.g. a smoke
  plan authored into a playground repo), push it to that repo's default branch.

Verify it landed before continuing:

```bash
gh api "repos/<owner>/<repo>/contents/<plan-path>?ref=<default-branch>" --jq .path
```

If 404, get the plan onto the default branch before creating the ticket.

### Step 3 - decide the branch name

For a fresh task, pick a clear new feature-branch name (ralphex creates it). For
a re-run, reuse the existing branch name (Workflow C). It must differ from the
repo's default branch.

### Step 4 - find the Linear team

The farm runs against one team (`LINEAR_TEAM_ID` in the operator's `.env`).
Discover at runtime:

```
mcp__claude_ai_Linear__list_teams
```

If only one team fits the farm naming convention (often contains "ralphex" or
"farm"), use it; otherwise present the list and ask. Cache the choice.

### Step 5 - create the issue

Use `mcp__claude_ai_Linear__save_issue` (Linear MCP must be authenticated; if
not, tell the user to run `/mcp`). Fields:

- `team`: the team ID from above.
- `title`: short, action-oriented (use the plan's intent, not the filename).
- `state`: `Todo`. Anything else and the poller skips it.
- `description`: metadata block first (so the regex catches it), then a human
  summary, then a link to the plan on the default branch.

Description template:

```markdown
<!-- ralphex-farm
repo: <linear_slug>
plan: <repo-relative-plan-path>
branch: <feature-branch-name>
-->

<one-paragraph summary of what the plan does - pull from the plan/commit, or ask>

Plan: [<relative-path>](<https-url-to-plan-on-default-branch>)
```

Pass the description as raw markdown with literal newlines, which the Linear MCP
requires (escaped `\n` will not render).

### Step 6 - after creation

Report the issue identifier and URL. The farm picks it up on the next poll
(`POLL_INTERVAL`, default 5m - confirm it if timing matters). To run it now
instead of waiting, hit the sync endpoint:

```bash
curl -s -X POST https://ralphex-farm.pkarpovich.space/api/sync   # -> {"status":"triggered"}
```

(Or `docker compose restart farm` on the host, but `/api/sync` is cheaper.)

## Workflow B: Add a new repository to the farm

Use this when `repo:` names a slug not yet in `repos.yaml`. All steps run on the
host running the farm (a home server reachable over SSH).

### 1. Clone the repo

```fish
sudo mkdir -p /var/ralphex/repos
cd /var/ralphex/repos
sudo git clone <clone-url> <name>
sudo chown -R <app-uid>:<app-uid> <name>
```

`<app-uid>` must match the uid owning the OTHER repos here (commonly `1000`).
The farm auto-detects it from the directory owner and passes it as `APP_UID`.
Mixed ownership breaks write-back. For private repos use SSH (`git@github.com:...`);
the farm container mounts `~/.ssh`.

### 2. Add to `repos.yaml`

Edit the file at `REPOS_CONFIG_PATH` in the farm's `.env` (mounted into the
container at `/etc/farm/repos.yaml`).

```yaml
<key>:
  clone_url: <https-or-git@-url>
  local_path: /var/ralphex/repos/<name>   # absolute, must match step 1
  default_branch: <main|master|...>       # gh repo view --json defaultBranchRef
  # linear_slug: <slug>                   # defaults to <key>
  # image: <registry>/ralphex-mise:latest # only to override RALPHEX_IMAGE
```

Rules (from `pkg/config/config.go::LoadRepos`): `clone_url`, `local_path`,
`default_branch` required; `local_path` absolute; `linear_slug` unique.

### 3. Apply

```fish
cd /home/<user>/ralphex-farm   # the compose dir
docker compose up -d
docker compose logs --tail=50 farm
```

The farm validates `repos.yaml` at startup; a malformed file keeps the container
down (clear error in the logs), so check the logs after restarting. Health check:
`curl http://localhost:7077/health`. You can also confirm the loaded set via
`GET /api/repos`.

## Workflow C: Re-run or recover a task

The farm recovers on the branch (the durable unit), not the worktree.

- **Resume a full run** (e.g. a transient failure mid-task): move the issue
  `Error -> Todo`. Keep `repo`/`plan`/`branch` as they were; the farm fetches
  the existing branch and continues. (A fresh-from-scratch run uses a branch
  that does not exist yet; recovery reuses the one that does.)
- **Review-only recovery** (the task finished its code work and died during
  review, or you only want the review pipeline re-run): set `mode: review` in
  the block and move the issue to `Todo`. The farm checks out the existing
  `branch` and runs `ralphex --review` in place, then pushes + opens/updates the
  PR. `mode: review` needs the branch to already exist.

Either way: edit the block (add/confirm `branch`, optionally `mode: review`) via
`mcp__claude_ai_Linear__save_issue`, set `state: Todo`, and the farm takes it on
the next poll (or hit `/api/sync`).

## Claude plugins / skills in the farm

The in-container `claude` (which ralphex drives) gets the operator's Claude Code
plugins/skills from a host dir set by `FARM_CLAUDE_CONFIG_DIR` (e.g.
`/var/ralphex/claude`). The farm mounts it read-only into each task container and
copies it on start to a writable `CLAUDE_CONFIG_DIR=/home/app/.claude-farm`.
Empty `FARM_CLAUDE_CONFIG_DIR` = feature off.

Important - the paths must match the runtime location. Claude Code records
absolute `installPath`s in `plugins/installed_plugins.json` and
`known_marketplaces.json`; they have to match the path the container uses
(`/home/app/.claude-farm`), or every plugin shows "failed to load". So build and
update the config inside a container at that exact path:

```fish
docker run --rm \
  -e CLAUDE_CONFIG_DIR=/home/app/.claude-farm \
  -v /var/ralphex/claude:/home/app/.claude-farm \
  --env-file /home/<user>/ralphex-farm/.env \
  --entrypoint sh <RALPHEX_IMAGE> \
  -c 'claude plugin marketplace add <owner>/<repo> && claude plugin install <name>@<marketplace>'
# then: sudo chown -R <app-uid>:<app-uid> /var/ralphex/claude
```

Bootstrapping on a different path (a laptop `/tmp`, or the bare host dir) and
copying it over leaves the recorded paths mismatched, so the plugins fail to
load. Verify with `claude plugin list` run the same way (mount the dir, copy, list).

## Gotchas (none surface as an obvious error)

These come from real failures.

1. **Plan not on default branch.** Farm resets to `origin/<default>` first; a
   plan only on a feature branch (or uncommitted) yields `plan file not found`.
   Push the plan to the default branch before creating the ticket (Workflow A
   step 2).
2. **Missing `branch` field.** The block needs `repo` + `plan` + `branch`; a
   `repo`+`plan`-only block is invalid and the issue is silently never picked up.
3. **`mode` other than `review`.** Any value besides empty or `review` rejects
   the block -> skipped.
4. **`branch` equals the default branch.** Rejected - work runs on a feature
   branch and merges via PR.
5. **Wrong Linear team.** The farm polls one team; tickets elsewhere are invisible.
6. **Wrong state.** Only `Todo` is picked up. Re-opening: move explicitly to `Todo`.
7. **`linear_slug` mismatch.** `repo:` must match `linear_slug` (or the map key)
   in `repos.yaml`.
8. **`local_path` ownership.** All repos owned by the same uid (commonly 1000).
9. **Claude config path mismatch.** See the Claude plugins section - build the
   config at `/home/app/.claude-farm` or plugins fail to load.

## Discovering farm config (when hands-on)

| What | Where |
|---|---|
| `.env` | `/home/<user>/ralphex-farm/.env` (conventional) |
| `docker-compose.yml` | same dir; it is a git checkout - `git pull` updates it (the deploy pulls the IMAGE, not these files) |
| `repos.yaml` (host) | path from `REPOS_CONFIG_PATH`; in container `/etc/farm/repos.yaml` |
| Repo clones | `/var/ralphex/repos/<name>` |
| Shared ralphex config | `RALPHEX_CONFIG_DIR`, default `/var/ralphex/config` |
| Codex auth | `CODEX_CONFIG_DIR`, default `/var/ralphex/codex` |
| Claude plugins config | `FARM_CLAUDE_CONFIG_DIR`, default `/var/ralphex/claude` (feature off if env unset) |
| Wait-on-limit | `RALPHEX_WAIT_ON_LIMIT`, default `30m` |
| Mise toolchain cache | `MISE_DATA_DIR`, default `/var/ralphex/mise` |
| Health endpoint | `http://<host>:${FARM_HEALTH_PORT:-7077}/health` |
| Sync (force a poll now) | `POST /api/sync` |
| Repos the farm serves | `GET /api/repos` - returns `slug` + `default_branch` per repo; use it to pick a valid `repo:` and its default branch without SSH |
| Logs | `docker compose logs farm` from the compose dir |

## Invocation triggers

Trigger on requests touching the farm (any phrasing, any language):
- "create a ralphex farm task for <plan>" / "queue this plan"
- "re-run <issue>" / "recover <issue>" / "review only" / "move back to Todo"
- "add <repo> to the farm" / "register <repo>"
- "sync the farm now" / "force a poll"
- "the farm is not picking up <issue>"
- "what slug for repos.yaml" / farm config questions
- Claude plugin provisioning in the farm (`FARM_CLAUDE_CONFIG_DIR`, plugins not loading)
- Any direct mention of `<!-- ralphex-farm`, `repos.yaml` in farm context, or
  paths under `/var/ralphex/`.
