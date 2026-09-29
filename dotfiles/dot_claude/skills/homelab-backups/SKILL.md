---
name: homelab-backups
description: Backup coverage rules for the homelab (alpha, bravo, Synology NAS, DO Spaces offsite). Activate whenever deploying a NEW service/compose project/database to alpha or bravo, adding a docker volume with state, decommissioning a service, or when the user mentions backups, restic, восстановление/restore, NAS storage, or asks "is X backed up". The core rule: new state MUST land in the backup include lists in the same change that creates it.
---

# homelab-backups

Backup system built 2026-07-16. Full design + restore runbook: `home-environment` repo `backup/README.md` and the vault note `PK Workspace/Home Backups.md`. This skill exists so new state never silently escapes coverage.

## The rule

**Any change that creates persistent state on alpha or bravo must, in the same PR/session, update backup coverage:**

1. New compose project or bind-mounted data dir -> add path to `home-environment/backup/hosts/<host>/includes.txt`.
2. New named docker volume with state -> add `/var/lib/docker/volumes/<name>` to the same includes.txt.
3. New postgres/mysql container -> add it to `backup/hosts/<host>/pre-backup.sh` (pg_dumpall pattern, POSTGRES_USER read via `docker exec printenv`); do NOT include the raw pg volume.
4. New sqlite file under active writes -> add a `sqlite3 .backup` line to pre-backup.sh.
5. Deliberately NOT backed up (caches, rebuildable, metrics, dead) -> add to `backup/hosts/<host>/audit-ignore.txt` with the reason as a `# comment` - otherwise the weekly audit will nag telegram forever.
6. Deploy: `git pull` on the host + `sudo ./backup/install.sh <host>` (idempotent). New service on the NAS -> extend `/volume2/restic_backups/offsite/offsite.sh` instead.

Decommissioned service -> move its entries includes -> audit-ignore (data stays in old snapshots for the retention window regardless).

## Architecture in one breath

Pi -> restic -> rest-server on NAS (append-only, per-host repos, `/volume2/restic_backups`) nightly 02:30 bravo / 03:30 alpha; NAS -> DO Spaces fra1 nightly 05:30 (`offsite.sh`: gitea->repo `nas`, share mirror -> `<mirror-bucket>` standard, media/me -> `<media-bucket>` cold via rclone crypt; real bucket names in the vault note). Monthly prune on NAS (DSM task, 7d/4w/6m). Monitoring: Gatus `Backups/restic-{alpha,bravo,offsite}` heartbeats 26h + weekly audit telegram. All secrets in 1Password (`restic repo alpha|bravo|nas (gitea)`, `do spaces backups`, `rclone crypt media`, `synology nas ssh`).

## Quick answers

- "Is X backed up?" -> check `backup/hosts/<host>/includes.txt` + `audit-ignore.txt` in home-environment; for NAS-side see `offsite.sh`.
- Restore commands -> `backup/README.md` (Restore section) or vault `Home Backups.md`; one-file restore: `sudo -s; . /etc/restic/env; export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE; restic restore latest --target /tmp/r --include <path>`.
- Manual run: `sudo systemctl start restic-backup.service`; status: `journalctl -u restic-backup -n 30`.
- Repo health: `restic check` (same env), stale lock -> `restic unlock`.
- NAS access: `ssh nas` (key auth, user pavel.karpovich); sudo/docker/Task Scheduler on NAS = DSM UI only (password sudo).

## Gotchas (hard-won)

- DO scoped Spaces keys deny HeadBucket -> keep `no_check_bucket = true` in rclone.conf.
- seaweedfs volume `du` shows preallocation (21G) not data (~1G apparent) - don't "fix" small snapshots.
- Gatus recreate wipes external-endpoint history -> re-push success from hosts.
- rest-server is append-only: forget/prune only via the NAS DSM task, never from clients.
- Gatus push URL is `ping.pkarpovich.space`, NOT `gatus.*`.
- DO bucket size in the dashboard INCLUDES in-flight multipart parts - killing an uploading rclone aborts its session and the number "drops"; committed objects are untouched. Stale sessions: `rclone backend list-multipart-uploads` / `rclone backend cleanup`.
- Big single-file uploads (50GB+ twitch/podcast files): default rclone death-spirals on session breaks (restart + backoff to ~0.4MB/s on a 30MB/s pipe). Use `--s3-chunk-size 64M --s3-upload-concurrency 8` and a `--log-file`.
- busybox pgrep on Synology (and kills of root-owned processes as the ssh user) fail SILENTLY - use `ps aux | grep`, and root ops via 1P: `op item get DiskStation --fields password --reveal | ssh nas 'sudo -S -p "" <cmd>'` (docker = `/usr/local/bin/docker`, acl tool = `/usr/syno/bin/synoacltool`).
- DSM Task Scheduler "skipped: task is already running" = the PREVIOUS run's process tree is still alive; offsite.sh has a flock guard, but the tree may need a root kill.

## Synology container patterns (from the tofa deploy)

- DSM docker does NOT auto-create bind-mount dirs - create them first.
- Fixed-uid images: a compose `user:` override SKIPS the entrypoint's root-phase magic (ownership repair of /data and the image's own dirs) and breaks them. Read the entrypoint first (`docker inspect --format '{{.Config.Entrypoint}}'`, then `docker run --rm --entrypoint cat IMAGE $(command -v <entrypoint>)`); prefer PUID/PGID env when supported (tofa: PUID=1026 PGID=100; PUID=0 rejected - embedded postgres).
- The media share ACL (`synoacltool -get /volume2/media`) allows ONLY `group:administrators` (gid 101) and `user:PlexMediaServer`; POSIX bits are cosmetic when the ACL is active, even for the owner. Container access to media => `group_add: ["101"]` (entrypoints that use setpriv must carry supplementary groups through the drop - tofa does). Hardware transcode: `/dev/dri` render group is gid 937 -> `group_add: ["937"]`.
