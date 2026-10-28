# Scripts & Functions

This directory contains utility scripts and their corresponding fish shell functions for various development workflows.

Split rule: CLI/maintenance utilities live here; user-facing launcher actions live in `dotfiles/tuna-scripts/` (picked up by tuna, require `@tuna.name` annotations).

## Prerequisites

Before using these functions, set up the required environment variables in your `~/.config/fish/local.fish`:

```fish
# Gitea configuration
set -gx GITEA_TOKEN your_gitea_token_here
set -gx GITEA_USERNAME your_username
set -gx GITEA_URL https://your-gitea-instance.com

# Bulk sync projects (colon-separated list)
set -gx GITEA_PROJECTS "~/Projects/repo1:~/Projects/repo2:~/Work/important-project"

# Transaction processor configuration
set -gx OPENAI_API_KEY your_openai_api_key_here
set -gx GOOGLE_SHEETS_FILE_ID your_sheets_file_id_here
set -gx GOOGLE_CREDENTIALS_PATH /path/to/google-credentials.json
```

## Functions & Scripts

### 1. apply-pr-diff

**Function:** `apply-pr-diff`
**Script:** `apply_pr_diff.py`

Fetches pull requests from a Gitea repository and applies them as diffs to your local repository.

#### Usage
```fish
# List all PRs for selection
apply-pr-diff https://git.example.com/owner/repo

# Apply specific PRs
apply-pr-diff https://git.example.com/owner/repo --prs=1,3,5
```

---

### 2. sync-to-gitea

**Function:** `sync-to-gitea`
**Script:** `sync_to_gitea.py`

Syncs local Git repositories to a Gitea server with intelligent repository discovery and concurrent processing.

#### Usage
```fish
# Sync from current directory
sync-to-gitea

# Sync from specific directory
sync-to-gitea ~/MyProjects

# Auto-yes mode (no prompts)
sync-to-gitea --yes
sync-to-gitea -y

# Custom directory with auto-yes
sync-to-gitea ~/MyProjects --yes
```

---

### 3. stable-to-master

**Function:** `stable-to-master`
**Script:** `git-stable-master-sync.sh`

Automates the process of creating branches and cherry-picking commits from stable branches to master branches.

#### Usage
```fish
# Basic usage with default base branches
stable-to-master feature/auth/stable feature/auth/master

# Custom base branches
stable-to-master feature/auth/stable feature/auth/master stable master
```

#### Default Base Branches
- **Base source branch**: `release/stable`
- **Base target branch**: `master`

---

### 4. claude-usage-push

**Script:** `claude_usage_push.py` (scheduled via turtle-harbor, no fish function)

Ships Claude subscription utilization (5h / 7d windows) from the
[claude-usage-bar](https://github.com/Blimp-Labs/claude-usage-bar) menu bar app
into Loki, where the tuclaw Grafana dashboard plots it next to the in-stream
RateLimitEvent gauges.

#### How it works

- claude-usage-bar polls `api.anthropic.com/api/oauth/usage` and appends data
  points to `~/.config/claude-usage-bar/history.json` (no extra API calls are
  made by this script - it only reads that file)
- `claude_usage_push.py` runs every 10 minutes via `scripts.yml` (turtle-harbor),
  prints any new points as JSON lines, and turtled's Loki shipper delivers them
  with labels `{script="claude-usage-push", host="mbp-2021"}`
- state (last shipped point) lives in `~/.local/state/claude-usage-push/state.json`;
  first run ships only the latest point, points older than 2 days are never shipped

#### Notes

- freshness = app polling interval (Settings, default 30m) + up to 10m cron lag
- if the menu bar app is logged out or not running, the script silently ships
  nothing - the Grafana series just goes stale until the app is back
