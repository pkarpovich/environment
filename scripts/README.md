# Scripts & Functions

This directory contains utility scripts and their corresponding fish shell functions for various development workflows.

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

### 4. cc-vendor

**Function:** `cc-vendor`
**Script:** `cc_vendor.py`

Vendors Claude Code plugins from the personal profile (`~/.claude`) into the
work profile (`~/.claude-work`) via symlinks.

#### Why this exists

The work profile (`ccw` alias = `CLAUDE_CONFIG_DIR=~/.claude-work claude`)
restricts `/plugin install` to a remote allowlist. Plugins you already trust
in the personal profile (`cc`) cannot be installed in `ccw` until they make it
onto that list. `cc-vendor` works around this by exposing the cached files
from `~/.claude/plugins/cache/...` to the work profile directly, with no
network access and no second install.

#### Usage
```fish
# Show current manifest + state (default subcommand)
cc-vendor
cc-vendor status

# Interactively edit which plugins to vendor (fzf multi-select)
cc-vendor pick

# Materialize the manifest: create symlinks + write settings.local.json
cc-vendor apply

# Remove everything created by this tool
cc-vendor clean
```

Run `cc-vendor apply` after any of these:
- editing the manifest (manually or via `pick`)
- `claude plugin update` (cache path includes the version, so old symlinks go
  stale on bump). `cc-vendor status` shows `BROKEN: N` when this happens.

#### Manifest

Lives at `~/.claude-work/cc-vendor.txt` (managed via dotbot from
`dotfiles/claude/cc-vendor.txt`, so it travels with the repo).

Two line formats:
```
umputun-cc-thingz/brainstorm                              # vendor whole plugin
axiom-marketplace/axiom:axiom-build,axiom-concurrency     # vendor specific skills only
```

Use the second form for "mega-plugins" like axiom where you want only a
subset of its 20+ skills.

#### What gets vendored

For each plugin in the manifest:
- **skills** -> symlinks in `~/.claude-work/skills/<skill>` pointing at the
  cache. Source location is read from the plugin's `.claude-plugin/plugin.json`
  (`"skills"` field) if present, otherwise falls back to `./skills/` by
  convention. This handles revdiff/ralphex which put skills in
  non-standard paths.
- **agents** -> symlinks in `~/.claude-work/agents/<name>.md` (same path
  resolution).
- **commands** -> symlinks in `~/.claude-work/commands/<name>.md`.
- **hooks** -> merged from each plugin's `hooks/hooks.json` into
  `~/.claude-work/settings.local.json`, with `${CLAUDE_PLUGIN_ROOT}` and
  `${CLAUDE_PLUGIN_DATA}` expanded to absolute paths. The data dir is
  emulated under `~/.claude-work/.vendored-data/<plugin>/`.

NOT vendored: `bin/`, scripts referenced from skill bodies via
`${CLAUDE_PLUGIN_ROOT}`. These still resolve correctly because the symlinks
point INTO the cache, so any relative paths inside SKILL.md still work.

#### State and safety

`~/.claude-work/.vendored-state.json` tracks every symlink and the SHA-256 of
the generated `settings.local.json`. `apply` refuses to clobber a
`settings.local.json` that was modified outside the tool. `clean` removes
only what `apply` created, leaving anything you hand-edited intact.

---

### 5. process-transactions

**Function:** `process-transactions`
**Script:** `transaction_processor/main.py`

Process bank transactions with AI categorization and currency conversion, with export to CSV and Google Sheets.

#### Usage
```fish
# Use default transactions.csv
process-transactions --sheets-name "December 2024"

# Use custom input file
process-transactions my-transactions.csv --sheets-name "December 2024"

# Skip AI categorization for testing
process-transactions --skip-categorization --sheets-name "Test Sheet"

# Custom currencies
process-transactions --currencies "USD,EUR,GBP" --sheets-name "Multi Currency"

# Override API key temporarily
process-transactions --api-key="different-key" --sheets-name "Test"
```
