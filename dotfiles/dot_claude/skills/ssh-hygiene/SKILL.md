---
name: ssh-hygiene
description: Audit, clean up, and structure SSH config and keys. Use when user asks to "review ssh config", "clean up ssh", "check ssh keys", "add ssh host", "remove dead ssh hosts", "organize ssh keys", or any SSH configuration management task. Also triggers on mentions of ~/.ssh/config, SSH key organization, or 1Password SSH agent setup.
---

# SSH Hygiene

Audit and restructure `~/.ssh/` for clean, secure, 1Password-integrated SSH management.

## Target Structure

```
~/.ssh/
  config
  keys/
    <host-alias>.pub
  known_hosts
```

## Config Format

```
Host *
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  IdentitiesOnly yes
  ServerAliveInterval 60
  ServerAliveCountMax 3

Host <alias>
  HostName <ip-or-hostname>
  User <username>
  IdentityFile ~/.ssh/keys/<alias>.pub
```

Rules:
- Never specify `Port 22` (default)
- `IdentityFile` always points to `.pub` in `~/.ssh/keys/` — 1Password serves private key via agent
- No private keys on disk, all in 1Password
- 2-space indent, no trailing comments, blank line between host blocks

## Workflow: Full Audit

1. Read `~/.ssh/config` and `ls ~/.ssh/`
2. Run `scripts/check_hosts.sh` to TCP-check port 22 on each host (3s timeout)
3. Present table: host, IP, alive/dead
4. Ask user which alive hosts are also no longer needed
5. Rewrite config keeping only needed hosts, applying format rules
6. Move/rename public keys to `~/.ssh/keys/<alias>.pub`
7. Delete orphaned keys (private keys on disk, keys for removed hosts)
8. Verify: `ls ~/.ssh/` and `ls ~/.ssh/keys/`

## Workflow: Add Host

1. Get alias, hostname/IP, username from user
2. Check if `.pub` exists in `~/.ssh/` or `~/.ssh/keys/`
3. If missing — user must create SSH Key in 1Password, export `.pub` to `~/.ssh/keys/<alias>.pub`
4. Append host block to config

## Workflow: Remove Host

1. Remove host block from config
2. Delete `.pub` from `~/.ssh/keys/`

## Common Fixes

- `IdentityFile` pointing to private key → change to `.pub`
- Absolute paths in `IdentityFile` → normalize to `~/.ssh/keys/<alias>.pub`
- `IdentitiesOnly yes` on individual hosts → remove (covered by `Host *`)
- `AddKeysToAgent yes` on individual hosts → remove (1Password handles this)
- Missing `ServerAliveInterval` in `Host *` → add 60/3
