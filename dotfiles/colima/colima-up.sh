#!/bin/sh
set -eu
PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# two half-dead shapes that the 5-minute retry below can never clear on its own,
# because `colima start` refuses to touch either of them:
#
# Broken: a VM the Virtualization framework killed outright leaves
# ha.pid/ha.sock/vz.pid behind. `colima start` inspects the instance through
# that dead socket, gets a connection refused and calls it a configuration error.
#
# Running but dead: the host agent is alive and holds the pid files, but the
# guest never booted (2026-09-14, first start after the macOS 27 upgrade: no
# sshd for 10 minutes, no guest agent, no docker.sock, an empty serial log).
# `colima start` then says "already running, ignoring" and exits; it looped
# 315 times over 26 hours. ssh into the guest is the cheapest liveness probe:
# it fails within a second when the guest is gone.
#
# Only `colima stop -f` removes the stale state; on a healthy or stopped VM
# neither branch is taken.
vm_state=$(colima list 2>/dev/null | awk '$1 == "default" { print $2 }')
case "$vm_state" in
    Broken) colima stop -f ;;
    Running) colima ssh -- true >/dev/null 2>&1 || colima stop -f ;;
esac

# sized per machine: the MBP (10 cores / 64 GiB) gets 6/12, the Air (8 cores /
# 24 GiB) 4/8. The number is a ceiling, not a reservation.
case "$(scutil --get LocalHostName)" in
    Pavels-MacBook-Air) cpus=4; memory=8 ;;
    *) cpus=6; memory=12 ;;
esac

# krunkit (libkrun >= 1.19) hands memory the guest frees back to macOS when the
# host needs it; vz keeps whatever the guest ever touched until the VM exits.
# Falls back to vz where krunkit is not installed. The type only applies when an
# instance is created: colima keeps an existing instance on its original type.
vm_type=vz
command -v krunkit >/dev/null 2>&1 && vm_type=krunkit

# colima 0.10.3 hands krunkit a 9p mount type it rejects (abiosoft/colima#1607,
# fix pending in #1641). A Lima override wins over colima's generated config;
# vz already uses virtiofs, so it changes nothing there.
mkdir -p "$HOME/.colima/_lima/_config"
printf 'mountType: virtiofs\n' > "$HOME/.colima/_lima/_config/override.yaml"

# Start only from launchd. A VM started from a terminal inherits that app as
# the responsible process for its network helper, macOS then gates it behind a
# Local Network prompt, and guest TCP dies until someone answers it.
colima start --vm-type "$vm_type" --cpus "$cpus" --memory "$memory" --disk 80

colima ssh -- sudo sh -s < "$(dirname "$0")/colima-datadisk.sh"

# Free page reporting only reports free blocks of 2^order pages (default 9 = 2 MB).
# After a CI build the guest's free memory is fragmented: 8 GB free, ~0.5 GB of it
# in 2 MB blocks, so krunkit could hand almost nothing back. 5 = 128 KB blocks.
# The parameter only exists when the balloon offers reporting (krunkit, not vz).
colima ssh -- sudo sh -c 'p=/sys/module/page_reporting/parameters/page_reporting_order; [ -w "$p" ] && echo 5 > "$p" || true'

# colima's Ubuntu image ships without systemd-resolved and /etc/resolv.conf is a
# dangling symlink, so dockerd falls back to [::1]:53 and every pull fails.
# Point it at the lima gateway DNS: it proxies to the macOS resolver, preserving
# split-horizon answers (git.pkarpovich.space -> LAN IP) and Tailscale names.
# Public resolvers here would break docker login/push to LAN-hosted registries.
# rm first: writing through the dangling symlink would create the wrong file.
colima ssh -- sudo sh -c 'gw=$(ip route | awk "/default/ {print \$3; exit}"); rm -f /etc/resolv.conf; { echo "nameserver $gw"; echo "nameserver 1.1.1.1"; } > /etc/resolv.conf'
