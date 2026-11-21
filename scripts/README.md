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

# Base address of the streamcast service for the stream function
set -gx STREAMCAST_URL https://streamcast.example.com
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

---

### 5. oauth-token and stream

**Functions:** `oauth-token`, `stream` (macOS only)
**Script:** `oauth_token.py`

`oauth-token` signs in to a service once with the OAuth 2.0 device authorization grant (RFC 8628), keeps the sign in in the macOS Keychain and prints an access token for other tools. It needs Python 3.11 or later and uses the standard library only.

In fish, the `oauth-token` function runs `scripts/oauth_token.py` with `python3`. It passes every argument, the stdout and the exit status through unchanged. Another shell runs the script by its path: `python3 ~/Projects/environment/scripts/oauth_token.py token media`.

#### Usage
```fish
oauth-token login media            # sign in in the browser
oauth-token token media            # print the access token
oauth-token token --header media   # print "Authorization: Bearer <token>"
oauth-token logout media           # remove the stored sign in

oauth-token token --header media | curl -sfN -H @- https://media.example.com/feed
```

`curl -H @-` reads the header from stdin, so the token is in no process argument. `token` writes the token or the header line to stdout and nothing else. Messages go to stderr and never contain a token, a refresh token or a device code.

#### Configuration

`~/.config/oauth-token/config.toml`, not in this repository:

```toml
issuer = "https://auth.example.com"
client_id = "cli"

[services.media]
resource = "https://media.example.com"
scope = "media:watch"
```

`issuer` must be an `https` address. The command reads `device_authorization_endpoint` and `token_endpoint` from `<issuer>/.well-known/openid-configuration`. It refuses a document whose `issuer` differs from the configured one and an endpoint that is not `https`. Requests time out after 10 s and never follow a redirect. A service name may use letters, digits, `_` and `-`.

A server with a certificate from a private certificate authority needs `SSL_CERT_FILE` set to a PEM file that holds that authority (for example in `~/.config/fish/local.fish`), because Python does not read the macOS Keychain trust store.

One sign in is one service. `login` asks for the service's `scope` plus `offline_access` and sends the service's `resource`. A refresh sends only `client_id` and the refresh token, with no `resource` and no `scope`.

#### Exit statuses

| Status | Meaning |
|---|---|
| 0 | ok |
| 1 | error: configuration, a refused discovery document, a denied or expired sign in, a server answer with no refresh token, the Keychain |
| 2 | wrong arguments |
| 3 | sign in needed: no stored sign in, a stored sign in for another issuer, client, resource or scope, or the server rejected the refresh token (`invalid_grant`, the stored sign in is removed) |
| 4 | temporary failure: network, timeout, `5xx` or any other failed refresh. The stored sign in stays. |

#### What the authorization server needs

- A public client (no secret) with the grant types `urn:ietf:params:oauth:grant-type:device_code` and `refresh_token`.
- The `offline_access` scope on that client. Without it the server sends no refresh token and `login` fails.
- The service's scope, and the `resource` parameter (RFC 8707) with the service's address as an allowed audience.
- `device_authorization_endpoint` in the discovery document.

#### How the sign in is kept

- One Keychain generic password per service: service `oauth-token`, account `<service>`. The command writes it with `security -i`, which reads the command from stdin, and passes the value as hex (`-X`). So the value is in no process argument. `security -i` reads lines of at most 4096 bytes and cuts a longer one, so a bigger sign in is refused and not stored. `security add-generic-password -w` with no value also reads stdin, but it cuts the value at 128 bytes.
- The stored access token is reused until 60 s before it expires. Then one refresh gets a new one.
- Every refresh returns a new refresh token, and a second use of an old one revokes the whole sign in. So `token` holds an exclusive `flock` on `~/.local/state/oauth-token/<service>.lock` from the read of the stored sign in until the new tokens are stored. `login` and `logout` take the same lock.

#### Tests

The tests use a fake authorization server, no network and no Keychain:

```sh
mise run test_oauth_token
# or: cd scripts && python3 -m unittest -v test_oauth_token
```

#### stream

`stream <channel>` plays a Twitch channel. `stream <platform> <channel>` names the platform. The base address comes from `STREAMCAST_URL` in `~/.config/fish/local.fish` (see Prerequisites). The function gets the header from `oauth-token token --header streamcast`, so the configuration needs a `[services.streamcast]` table. It sends the header to `curl -fsSN -H @-` on stdin and plays the answer with `mpv -`. When the request fails, curl names the HTTP status and the function returns curl's status. Platform and channel may use letters, digits, `_` and `-`.

```fish
stream somechannel
stream kick somechannel
```
