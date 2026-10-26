---
name: local-env
description: Pavel's local dev environment on the Mac - which *.localhost domain and port a service uses behind the local Caddy, how to start, check or stop a dev server (foster, the project's Zed tasks, mise tasks, ft/fa), where worktrees live, how a project pins its languages and tools in mise, and how to add a local domain or a Zed task. Use for "start the dev server", "run the app locally", "which port does X use", "is X running", "open X locally", "add a local domain", "add a Zed task", "create a worktree", "install node/go/python for this project", "which version of X", and before editing .zed/tasks.json, mise.toml or the Caddyfile.
---

# Local dev environment

A mise task holds the script that starts a service, a Zed task calls that mise task, foster runs the Zed task and attaches to it, and Caddy gives the service a stable `*.localhost` name.

## Starting and checking a service

- A service starts only from a Zed task. If the project has no task for it, add one first: the script goes into a mise task (`mise.toml`, `[tasks.dev]` with a `description`), and the Zed task in `.zed/tasks.json` runs `mise run <task>`. Then start it with `foster task <slug>`. `foster task --json` lists the tasks.
- A long-running process goes through foster, never `&`, `nohup` or `run_in_background`. The `foster` skill has the commands. Load it before you start, read or stop anything.
- Is X running: `foster ls --json` for processes, `lsof -nP -iTCP:<port> -sTCP:LISTEN` for whatever holds a port. A running foster process or a busy port is usually Pavel's. Report it, never stop it.
- A server an agent starts for itself, to check its own change, runs under `foster run` on an explicit port outside 50000-50999 and outside every port in the Caddyfile, with `--strictPort` or its equivalent. Vite silently moves to the next port when one is busy, so without it the agent's server lands on Pavel's port plus one and the two cannot be told apart. Stop it with `foster rm` when done.
- Pavel starts tasks with `ft` and attaches with `fa` (fish functions over sk). They are interactive: suggest them, never run them.

A service in this shape, from a static site:

```toml
[tasks.dev]
description = "Start the dev server"
run = "pnpm exec astro dev"
```

```jsonc
{
  "label": "dev: site",
  "command": "mise run dev",
  "cwd": "$ZED_WORKTREE_ROOT",
  "use_new_terminal": false,
}
```

`foster task dev-site` then starts it as `<repo>:dev-site`.

## Toolchains

- Every language, runtime and CLI a project needs is pinned in the project's own `mise.toml` under `[tools]`, with an exact version. A project without `mise.toml` gets one before anything else.
- Never rely on the global mise config, Homebrew or the system for a project's toolchain. The global config only holds defaults for loose shells. Never run `mise use -g` or edit the global config for a project.
- Commands run through mise: `mise run <task>`, or `mise exec -- <command>` for a one-off.
- The version to pin is the current release. Find it with `mise ls-remote <tool>`, the package registry or the GitHub releases, never from memory and never as `latest`.

## Worktrees

- A worktree lives at `~/Projects/worktrees/<repo>/<branch>`, with `/` in the branch name replaced by `-` (`feat/nikki-ui` becomes `feat-nikki-ui`). This is where Zed's worktree picker looks.
- Create it from the main checkout with `git worktree add -b <branch> ~/Projects/worktrees/<repo>/<dir> origin/main`. Never create it with Zed's picker: that gives a detached HEAD.
- Before you switch branches in Pavel's checkout, stash his tracked edits with a clear message, and move an untracked file aside and put it back afterwards. Never delete anything of his.
- Install dependencies fresh in the worktree (`node_modules` included). Copy only the gitignored local files the dev server needs, such as `.env`.
- After the PR merges, remove it with `git worktree remove` and `git branch -d`, and tell Pavel.

## Zed tasks

- Project tasks live in `.zed/tasks.json`, global ones in `~/.config/zed/tasks.json`. For fields and variables, load the `zed-config` skill and its `references/tasks.md`.
- Zed reads its config as JSON with comments and trailing commas, whatever `zed-config` says about strict JSON. Keep the style the file already has.
- A new or edited task sets `"use_new_terminal": false`. Do not flip existing tasks without asking.
- `cwd` starts from `$ZED_WORKTREE_ROOT`, so the task works in every worktree. A task that reads another `ZED_*` variable (the open file, the selection) runs only from Zed, and `foster task --json` reports it under `needs`.
- foster names a task `<repo>:<label slug>`, with the repo name taken from git, so the main checkout and its worktrees share one name.

## Local domains

- Caddy runs as a Homebrew service. Its config `/opt/homebrew/etc/Caddyfile` is a symlink to `dotfiles/Caddyfile` in `~/Projects/environment`. Each site there is `<name>.localhost { import site <port> }`, a reverse proxy to `localhost:<port>` over https with Caddy's local CA. http redirects to https.
- The Caddyfile is the source of truth for the port a service uses. Read it instead of guessing. The service's own config must listen on that port.
- Most ports sit in 50000-50999, grouped by project. A new service takes the next free port in its project's group. Check that no site in the Caddyfile and no listener already has it.
- To add a domain, add the site to `dotfiles/Caddyfile`, run `caddy reload --config /opt/homebrew/etc/Caddyfile`, then check it with `curl -sI https://<name>.localhost`.
- On the MacBook Air a site whose port does not listen there is proxied to the MacBook Pro. The `X-Served-By` response header names the machine that answered.
