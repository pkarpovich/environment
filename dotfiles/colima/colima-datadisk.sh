#!/bin/sh
# Runs inside the colima guest as root (colima-up.sh pipes it through `colima ssh`).
#
# Colima's own data-disk step guesses the device from where cidata is mounted
# (vdb or vdc). Under krunkit it runs before cidata is up, picks the ISO, and
# Docker starts on the root disk: every restart looks like all images and
# volumes are gone (abiosoft/colima#1583). Find the disk by its label instead
# and move the Docker state dirs onto it. A correctly mounted disk exits at once.
dev=$(lsblk -rno PATH,LABEL | awk '$2 ~ /^lima-colima/ {print $1; exit}')
[ -n "$dev" ] || exit 0
mp=$(ls -d /mnt/lima-colima* 2>/dev/null | grep -v cidata | head -1)
[ -n "$mp" ] || exit 0
findmnt -rn -S "$dev" -M "$mp" >/dev/null && exit 0

echo "colima-datadisk: $dev was not on $mp, moving the Docker state onto it"
systemctl stop docker.socket docker.service containerd.service || true
for d in docker containerd rancher cni ramalama; do umount "/var/lib/$d" 2>/dev/null || true; done
mount "$dev" "$mp"
for d in docker containerd rancher cni ramalama; do
    mkdir -p "$mp/$d" "/var/lib/$d"
    mount --bind "$mp/$d" "/var/lib/$d"
done
systemctl start containerd.service docker.service
