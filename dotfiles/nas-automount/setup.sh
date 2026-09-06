#!/bin/sh
# run as the user; asks for sudo where root is needed. Idempotent.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"

[ -f /etc/auto_nas ] || { echo "no /etc/auto_nas yet: create it first, see README.md" >&2; exit 1; }
sudo chmod 600 /etc/auto_nas

sudo install -m 755 -o root -g wheel "$here/fix-nas-automount.sh" /usr/local/bin/fix-nas-automount.sh
sudo install -m 644 -o root -g wheel "$here/com.user.fix-nas-automount.plist" /Library/LaunchDaemons/com.user.fix-nas-automount.plist
sudo launchctl bootout system/com.user.fix-nas-automount 2>/dev/null || true
sudo launchctl bootstrap system /Library/LaunchDaemons/com.user.fix-nas-automount.plist
sudo /usr/local/bin/fix-nas-automount.sh
sudo automount -vc

# the shares as plain links in the home directory; /mnt is what automountd creates
for share in archive media; do
    ln -sfn "/mnt/nas/$share" "$HOME/$share"
done
[ -L "$HOME/nas" ] && rm -f "$HOME/nas"

ls /mnt/nas/media >/dev/null && echo "nas automount ok: /mnt/nas/media answers"
