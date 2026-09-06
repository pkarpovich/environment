#!/bin/sh
set -eu
PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# a VM the Virtualization framework kills outright leaves ha.pid/ha.sock/vz.pid
# behind. `colima start` inspects the instance through that dead socket, gets a
# connection refused, calls it a configuration error and exits before booting
# anything - so the 5-minute retry below can never clear it on its own. Only
# `colima stop -f` removes the stale files; on a healthy or stopped VM this
# branch is never taken.
if colima list 2>/dev/null | awk '$1 == "default" && $2 == "Broken" { found = 1 } END { exit !found }'; then
    colima stop -f
fi

# sized per machine: the MBP (10 cores / 64 GiB) gets 6/12, the Air (8 cores /
# 24 GiB) 4/8. vz allocates memory lazily, the number is a ceiling.
case "$(scutil --get LocalHostName)" in
    Pavels-MacBook-Air) cpus=4; memory=8 ;;
    *) cpus=6; memory=12 ;;
esac

colima start --vm-type vz --vz-rosetta --cpus "$cpus" --memory "$memory" --disk 80

# colima's Ubuntu image ships without systemd-resolved and /etc/resolv.conf is a
# dangling symlink, so dockerd falls back to [::1]:53 and every pull fails.
# Point it at the lima gateway DNS: it proxies to the macOS resolver, preserving
# split-horizon answers (git.pkarpovich.space -> LAN IP) and Tailscale names.
# Public resolvers here would break docker login/push to LAN-hosted registries.
# rm first: writing through the dangling symlink would create the wrong file.
colima ssh -- sudo sh -c 'gw=$(ip route | awk "/default/ {print \$3; exit}"); rm -f /etc/resolv.conf; { echo "nameserver $gw"; echo "nameserver 1.1.1.1"; } > /etc/resolv.conf'
