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
