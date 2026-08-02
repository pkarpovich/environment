# colima

Replaces Docker Desktop (migrated 2026-07-21). Docker CLI + compose come from
the Brewfile; the VM autostarts via the LaunchAgent here, NOT `brew services`:
brew's service runs bare `colima start -f`, which resets `colima.yaml` to
defaults (2 CPU / 2 GiB, no DNS) on every start - discovered the hard way.

Pieces:

- `colima-up.sh` - starts the VM with explicit flags (vz, rosetta, 6 CPU,
  12 GiB, 80 GiB disk) and then repairs `/etc/resolv.conf` inside the VM:
  colima's Ubuntu image has no systemd-resolved, the symlink dangles, and
  dockerd falls back to [::1]:53 so every image pull fails with DNS errors.
  resolv.conf points at the lima gateway (192.168.5.2) which proxies to the
  macOS resolver - this preserves split-horizon DNS (git.pkarpovich.space ->
  LAN IP), without which docker login/push to the home registry times out.
  Do NOT hardcode public resolvers here.
- `com.pavel-karpovich.colima.plist` - LaunchAgent running the script at
  login; linked into `~/Library/LaunchAgents` by dotbot. Logs:
  `/tmp/colima-up.log`.

New machine notes:

- `docker compose` needs `~/.docker/config.json` (not in dotfiles - holds
  registry auth) to include:
  `"cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"]`
- gitea-runner lives in `~/gitea-runner` (bind-mounted config, mounts
  `/var/run/docker.sock` - works as-is inside the colima VM).
