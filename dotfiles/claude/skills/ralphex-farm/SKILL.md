---
name: ralphex-farm
description: >
  Work with ralphex-farm: a control plane that polls Linear, picks up Todo issues
  whose description carries a `<!-- ralphex-farm -->` YAML block (repo + plan +
  branch, optional mode), hands the job to a runner that executes ralphex in
  Docker, and opens a PR. Invoke whenever the user wants to: create a Linear
  ticket for a plan ("create a ralphex farm task", "add task for plan", "queue
  plan to the farm"), re-run or recover a failed task ("re-run", "recover",
  "review only", "move back to Todo"), add a new repository to the farm, deploy
  or update a runner, trigger an immediate sync, debug why a ticket was not
  picked up or why a PR got the fallback description, or answer questions about
  how the farm works. Also trigger on any mention of the `<!-- ralphex-farm -->`
  metadata block, repository declarations in stash, the farm's `/api/sync`,
  `/api/repos` or `/api/repos/resync` endpoints, the finalize prompt the farm
  ships, or Claude plugin provisioning in the farm.
allowed-tools:
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git push:*)
metadata:
  version: "0.3.0"
---

# ralphex-farm

Operator skill for ralphex-farm (https://github.com/pkarpovich/ralphex-farm).

## What the farm does

It runs as **two processes**, and almost every operational mistake comes from
forgetting which one owns what.

- The **farm** (control plane, one instance, on bravo) owns Linear, the pending
  queue, leases, the run history and the dashboard. It never executes anything
  and holds no execution credentials - no docker socket, no git, no `gh`, no ssh.
- The **runners** (executors) long-poll the farm for jobs and run ralphex against
  their own local clones. They hold everything dangerous: the docker socket,
  `GH_TOKEN`, the claude credential, ssh keys. Adding capacity is starting
  another runner.

The farm polls one Linear team every `POLL_INTERVAL` (default 5m). For each issue
in `Todo` with a valid metadata block it enqueues a job; a runner claims it,
prepares the branch, runs ralphex in a task container, pushes, opens a PR,
comments the URL back on the issue and the farm moves it to `In Review`. Failures
move the issue to `Error` with a comment. A transient Claude rate-limit makes
ralphex wait and retry rather than die (`RALPHEX_WAIT_ON_LIMIT`, default 30m).

Linear is the source of truth for **what to run**; the farm additionally keeps a
SQLite run history and per-run logs under `FARM_RUNS_DIR` for the dashboard.

Dashboard: `https://ralphex-farm.pkarpovich.space/`, one run at `#/run/<run_id>`.

## The metadata block

The farm matches this with a strict regex and requires `repo`, `plan` and
`branch`. Omit any one, or get a value wrong, and the issue is **silently
skipped** - the one failure that surfaces no error anywhere.

```
<!-- ralphex-farm
repo: <slug>
plan: <repo-relative-path-to-plan-md>
branch: <feature-branch-name>
mode: review
-->
```

Rules:
- `<!--` and `-->` markers each on their own line.
- `repo` matches a slug declared in stash and advertised by a connected runner.
  `GET /api/repos` lists what is actually served right now.
- `plan` is repo-relative and the file must exist **on the repo's default
  branch** (the runner does `git fetch && reset --hard origin/<default>` first).
- `branch` is the feature branch and the single source of truth for the name: it
  is passed to ralphex as `--branch` and pushed verbatim. It must differ from the
  default branch.
- `mode` is optional. Only `review` or empty are valid; any other value
  invalidates the block and the issue is skipped. `mode: review` re-runs only the
  review pipeline on an existing branch.
- The first matching block wins; the rest of the description is free-form.

## Workflow A: queue a plan

### 1. Confirm the repo is served

```bash
curl -s https://ralphex-farm.pkarpovich.space/api/repos
# -> [{"slug":"turtle-hub","default_branch":"main"}, ...]
```

An empty `default_branch` means a runner has declared it but the clone is still
landing. A slug that is absent entirely needs Workflow B first.

### 2. Land the plan on the default branch

This is the most common reason a ticket never runs. If the plan was just
written, commit that one file and push it to `master`/`main` before creating the
ticket - invoking this skill right after writing a plan is itself the
authorization to do so, so do not stop to ask. Never sweep other working-tree
changes into that push.

Verify before continuing:

```bash
gh api "repos/<owner>/<repo>/contents/<plan-path>?ref=<default-branch>" --jq .path
```

### 3. Create the issue

Find the team with `mcp__claude_ai_Linear__list_teams` (it is the one named for
the farm), then `mcp__claude_ai_Linear__save_issue` with `state: Todo` and the
metadata block first in the description, followed by a human summary and a link
to the plan on the default branch. Pass the description as raw markdown with
literal newlines.

### 4. Pick it up now instead of waiting

```bash
curl -s -X POST https://ralphex-farm.pkarpovich.space/api/sync   # -> {"status":"triggered"}
```

## Workflow B: add a repository

A repository is declared **once, in stash**, and every runner picks it up itself.
There is no `repos.yaml`, no ssh to a host, no manual `git clone`, no restart.

**No credential is involved.** stash runs with authentication disabled - it is a
LAN-only service - so the write needs no token and you never have to source one
from anywhere. Do **not** reach into the runner container for `STASH_TOKEN`: that
variable exists in its environment but the server never checks it, and going
after it reads as credential exploration and gets blocked, which has already
cost one session half an hour and three refusals.

```bash
curl -X PUT -d '{"clone_url":"git@github.com:<owner>/<repo>.git"}' \
  https://stash.pkarpovich.space/kv/ralphex-farm/repos/<slug>

curl -X POST https://ralphex-farm.pkarpovich.space/api/repos/resync
```

- `<slug>` must match `^[a-z0-9_-]+$`. It is simultaneously the directory name
  under `RUNNER_REPOS_ROOT` and the value `repo:` matches against.
- Use the **SSH** form of the clone URL even for public repos - the runner pushes
  the feature branch with it.
- `image` is an optional third field overriding `RALPHEX_IMAGE` for that
  repository. Rarely needed: the default is already the mise image.
- The clone path and the default branch are **derived, never declared** - the
  branch is re-read from the remote on every pass so it cannot drift.

Every runner learns about it within 30s and clones in the background; the slug
becomes claimable as its clone completes. Removing a declaration stops the
repository being advertised but never deletes the clone - recovery depends on
branches living there. A declaration set that reads as empty never replaces a
working one, so removing the *last* repository does not retire it.

If a write ever comes back 401, authentication has since been enabled on stash -
stop and ask for a token scoped to the `ralphex-farm/*` prefix rather than
hunting for one, since a prefix-scoped token deliberately does not carry
`secrets/*` access.

## Workflow C: re-run or recover

Recovery is keyed on the **branch**, which survives worktree removal, container
teardown and restarts - committed work lives on `refs/heads/<branch>`.

- **Resume an interrupted run**: move the issue back to `Todo`, unchanged. The
  branch already exists, so the runner checks it out and continues in place
  rather than starting from the default branch.
- **Re-run only the review pipeline**: add `mode: review` and move to `Todo`.
  Requires the branch to exist already.

PR creation is idempotent: an existing PR is reused, and its title and body are
refreshed if this run generated a description. A resumed run may land on a
different runner - safe, because the branch is on origin, but uncommitted
worktree state does not carry over.

Split-specific failure reasons, all recoverable the same way: `runner_lost`
(lease expired, 3m), `runner_shutdown` (drain timeout exceeded), `canceled`
(dashboard kill), `farm_restart` (no runner re-claimed in the grace period).

## Deploying and updating a runner

**The farm auto-deploys; the runner does not.** The updater webhook redeploys the
farm only, so after any merge the runner keeps executing the old binary until
someone recreates it. Check what it is actually running:

```bash
docker logs ralphex-runner 2>&1 | grep -o '"revision":"[^"]*"' | tail -1
# -> "revision":"master-<sha>-<timestamp>"   the sha is the merge commit
```

**The compose file that deploys the runner is not in the farm repository.** The
farm ships `docker-compose.runner.yml` as reference documentation and it deploys
nothing; the live one is `compose-ralphex-runner.yml` in the `home-environment`
repo. Confirm before editing anything:

```bash
docker inspect ralphex-runner --format '{{index .Config.Labels "com.docker.compose.project.config_files"}}'
```

Update (on the runner host, farm idle - check `in_flight_count` first):

```fish
cd ~/Projects/home-environment
docker compose -p runners --env-file .env.mbp -f compose-ralphex-runner.yml pull
docker compose -p runners --env-file .env.mbp -f compose-ralphex-runner.yml up -d
```

A compose change (not just a new image) needs the recreate above; `pull` alone
will not apply it.

## Generated PR descriptions

The farm owns ralphex's **finalize step**. Before each task container it writes
its own `prompts/finalize.txt` into `RALPHEX_CONFIG_DIR`, sets
`finalize_enabled = true` in the ralphex config there, and creates
`farm-out/<run_id>/` for the output, handing the container the path in
`FARM_PR_FILE`. The finalize session runs last - after codex and the post-codex
review - reads the plan, the diff, the commits and the progress log, and writes a
title and body. The runner appends the footer (ticket link, plan path, run id)
itself.

Everything about it is best-effort: a failed write, a missing file or one that
fails validation logs a warning and the PR opens with the old
`<identifier>: <title>` and a footer-only body. So **a PR with the three-line
template means one of those warnings fired** - check the run log first, and check
that `RALPHEX_CONFIG_DIR` is mounted read-write into the runner (it must not be
`:ro`, or every write fails with EROFS and every description silently degrades).

## Claude plugins in task containers

The in-container `claude` starts with an empty `~/.claude`. Point
`FARM_CLAUDE_CONFIG_DIR` at a populated config dir and the runner mounts it
read-only, copies it into each task container and rewrites the host paths the
plugin metadata records.

"Populated" means it contains `settings.json` - the runner checks for that file,
not just the directory, and warns that the agent will run without skills when it
is missing. Bootstrap it **at its own absolute path**, because claude records
absolute paths and the runner's rewrite looks for exactly `FARM_CLAUDE_CONFIG_DIR`:

```bash
docker run --rm -v /var/ralphex/claude:/var/ralphex/claude \
  -e CLAUDE_CONFIG_DIR=/var/ralphex/claude \
  <RALPHEX_IMAGE> \
  sh -c 'claude plugin marketplace add <owner>/<repo> && claude plugin install <name>@<marketplace>'
```

## Gotchas

Every one of these has actually happened, and none surfaces as an obvious error.

1. **Plan not on the default branch.** The runner resets to `origin/<default>`
   first; a plan only on a feature branch yields `plan file not found`.
2. **Missing `branch`, or `mode` set to anything but `review`.** The block is
   invalid and the issue is never picked up, silently.
3. **`branch` equals the default branch.** Rejected - work merges via PR.
4. **Wrong Linear team or wrong state.** The farm polls one team and only `Todo`.
5. **Slug not advertised.** Declared in stash but no connected runner has cloned
   it yet: the issue sits in `Todo` with a warning in the farm log.
6. **The runner is still on the old image.** Nothing redeploys it automatically.
7. **Editing `docker-compose.runner.yml` in the farm repo.** It deploys nothing.
8. **`RALPHEX_CONFIG_DIR` mounted `:ro`.** Descriptions silently fall back.
9. **Codex without `auth.json`.** The runner skips the mount with a warning and
   external review then dies mid-run with `401 Missing bearer`.
10. **Claude seed bootstrapped under a different path.** The path rewrite matches
    nothing, `sed` exits 0, and the run loads zero plugins.

## Where things live

| What | Where |
|---|---|
| Farm | bravo (`192.168.199.72:7077`), behind `ralphex-farm.pkarpovich.space` |
| Runner (mbp) | container `ralphex-runner`, compose in `home-environment/compose-ralphex-runner.yml`, env `.env.mbp` |
| Runner state | `$HOME/ralphex/{repos,config,codex,claude,mise,gocache}` on the Mac |
| Repository declarations | stash, `ralphex-farm/repos/<slug>` |
| Run history + logs | `FARM_RUNS_DIR` on the farm host (SQLite + per-run `output.log`) |
| Health | `GET /health` - poller staleness, error window, connected runners |
| Repos served | `GET /api/repos` |
| Force a Linear poll | `POST /api/sync` |
| Force a declaration re-read | `POST /api/repos/resync` |
| Farm logs | `docker compose logs farm` in the farm's compose dir |
| Runner logs | `docker logs ralphex-runner` |

Full reference lives in the repo: `docs/configuration.md` (env tables and the
declaration format), `docs/runner.md` (job protocol, leases, recovery, the
reconcile pass), `docs/web-dashboard.md`, `docs/observability.md`,
`docs/ci-cd.md`.
