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

### 4. process-transactions

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
