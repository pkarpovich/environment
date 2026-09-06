# nas-automount

SMB shares of the Synology (`archive`, `media`) mounted on demand by autofs at
`/mnt/nas/<share>`, with `~/archive` and `~/media` as plain symlinks to them.

Why a daemon: every macOS update rewrites `/etc/auto_master` and drops our map
line. Without it automountd never creates `/mnt`, and everything pointing at
the shares dies until someone notices. `com.user.fix-nas-automount` runs at
boot, puts the line back if it is missing and reloads automount. Same label
and script as the MBP, which had this by hand since 2026-03.

Pieces:

- `fix-nas-automount.sh` -> `/usr/local/bin/`, run by the daemon at every boot.
- `com.user.fix-nas-automount.plist` -> `/Library/LaunchDaemons/`.
- `setup.sh` - installs both, loads the daemon, fixes the home symlinks.
  Run as the user, it sudo's where needed: `sh dotfiles/nas-automount/setup.sh`.

Not in the repo: `/etc/auto_nas` holds the SMB credentials. Create it by hand
on a new machine, mode 600, one line per share:

```
archive    -fstype=smbfs,soft,nodev,nosuid    ://USER:PASSWORD@192.168.198.2/archive
media      -fstype=smbfs,soft,nodev,nosuid    ://USER:PASSWORD@192.168.198.2/media
```
