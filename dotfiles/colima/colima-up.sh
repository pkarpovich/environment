#!/bin/sh
set -eu
PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

colima start --vm-type vz --vz-rosetta --cpus 6 --memory 12 --disk 80

# colima's Ubuntu image ships without systemd-resolved and /etc/resolv.conf is a
# dangling symlink, so dockerd falls back to [::1]:53 and every pull fails.
# Point it at the lima gateway DNS: it proxies to the macOS resolver, preserving
# split-horizon answers (git.pkarpovich.space -> LAN IP) and Tailscale names.
# Public resolvers here would break docker login/push to LAN-hosted registries.
# rm first: writing through the dangling symlink would create the wrong file.
colima ssh -- sudo sh -c 'gw=$(ip route | awk "/default/ {print \$3; exit}"); rm -f /etc/resolv.conf; { echo "nameserver $gw"; echo "nameserver 1.1.1.1"; } > /etc/resolv.conf'
