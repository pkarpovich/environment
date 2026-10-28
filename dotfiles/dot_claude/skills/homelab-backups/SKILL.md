---
name: homelab-backups
description: Backup coverage rule for the home servers. Use when deploying a new service, compose project or database to a home host, adding a docker volume with state, decommissioning a service, or when asked whether something is backed up, about restic, restore or NAS storage.
---

# homelab-backups

New persistent state on a home host joins the backup coverage in the same change that creates it. The coverage lives in the `home-environment` repo under `backup/hosts/<host>/`:

- a compose project or bind-mounted data dir: its path in `includes.txt`
- a named docker volume with state: `/var/lib/docker/volumes/<name>` in `includes.txt`
- a postgres or mysql container: a dump in `pre-backup.sh`, the raw volume not included
- a sqlite file under writes: a `sqlite3 .backup` line in `pre-backup.sh`
- state that stays out on purpose (caches, rebuildable data, metrics): `audit-ignore.txt` with the reason, or the weekly audit reports it
- a decommissioned service: its entries move from includes to audit-ignore

Deploy with `git pull` on the host and `sudo ./backup/install.sh <host>`. A service on the NAS extends `offsite.sh` instead.

"Is X backed up" is answered from `includes.txt` and `audit-ignore.txt` of its host, `offsite.sh` for the NAS. Architecture, schedule, restore, monitoring and the gotchas are in `backup/README.md` of that repo.
