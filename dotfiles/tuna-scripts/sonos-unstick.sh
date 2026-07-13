#!/bin/bash
# @tuna.name Unstick Sonos Arc
# @tuna.subtitle Kick the wedged Arc off Wi-Fi so it reassociates (~30s cure)
#
# Cure the Sonos Arc "network freeze" without walking to the power plug.
#
# Symptom (Arc on fw 95.1+): the speaker keeps its Wi-Fi association but its
# userspace network stack wedges - ICMP ping still replies, yet every TCP/UDP
# service (port 1400, the Sonos app, AirPlay, Home Assistant) stops responding
# until the Wi-Fi link is reset. A UniFi deauth (kick-sta) forces a clean
# reassociation and fixes it in ~30s, exactly like a power cycle.
#
# Detection = "ICMP alive AND :1400 dead" (the precise wedge signature; a plain
# power-off would fail ICMP too, so we never kick a genuinely offline speaker).
#
# Usage:
#   sonos-unstick.sh           detect, and kick ONLY if actually wedged
#   sonos-unstick.sh --force   kick regardless of current state
#   sonos-unstick.sh --check   detect only, never kick (exit 0 healthy / 1 wedged)
#
# The UniFi local API key is read from 1Password (only when a kick is needed).
# Create the item once, then never touch it again:
#   op item create --category "API Credential" --title "UniFi Network API" \
#     credential="<key from UniFi > Settings > Control Plane > Integrations>"
# Override the lookup with OP_KEY_REF, or bypass op entirely with UNIFI_API_KEY.

set -euo pipefail

# --- config (matches Magellan UDR7 / Living Room Arc) ---
UNIFI_HOST="192.168.198.1"
SITE="default"
ARC_IP="192.168.199.83"
ARC_MAC="38:42:0b:e4:81:8c"
OP_KEY_REF="${OP_KEY_REF:-op://Private/UniFi Network API/credential}"
RECOVER_WAIT=45            # seconds to wait for the Arc to come back after a kick

OP=/opt/homebrew/bin/op

# --- probes ---
icmp_ok() { ping -c1 -t2 "$ARC_IP" >/dev/null 2>&1; }
http_ok() { curl -s -m4 -o /dev/null "http://$ARC_IP:1400/xml/device_description.xml"; }

state() {
  if http_ok; then echo healthy
  elif icmp_ok; then echo wedged
  else echo offline
  fi
}

get_key() {
  if [ -n "${UNIFI_API_KEY:-}" ]; then printf '%s' "$UNIFI_API_KEY"; return; fi
  "$OP" read "$OP_KEY_REF" 2>/dev/null || {
    echo "Could not read the UniFi API key from 1Password ($OP_KEY_REF)." >&2
    echo "Unlock 1Password + enable the CLI, or run with UNIFI_API_KEY=... set." >&2
    exit 1
  }
}

kick() {
  local key resp
  key=$(get_key)
  resp=$(curl -sk -m10 -X POST \
    -H "X-API-KEY: $key" -H "Content-Type: application/json" \
    -d "{\"cmd\":\"kick-sta\",\"mac\":\"$ARC_MAC\"}" \
    "https://$UNIFI_HOST/proxy/network/api/s/$SITE/cmd/stamgr")
  case "$resp" in
    *'"rc":"ok"'*) return 0 ;;
    *) echo "Kick failed - UniFi replied: $resp" >&2; return 1 ;;
  esac
}

# --- args ---
mode="auto"
case "${1:-}" in
  --check) mode="check" ;;
  --force) mode="force" ;;
  "")      mode="auto" ;;
  *) echo "usage: $(basename "$0") [--check|--force]" >&2; exit 2 ;;
esac

st=$(state)
echo "Arc $ARC_IP: $st"

if [ "$mode" = "check" ]; then
  [ "$st" = "healthy" ] && exit 0 || exit 1
fi

if [ "$st" = "offline" ]; then
  echo "Arc does not answer even ICMP - it is truly off the network, not wedged."
  echo "A kick will not help; check power / Wi-Fi."
  exit 1
fi

if [ "$mode" = "auto" ] && [ "$st" = "healthy" ]; then
  echo "Nothing to do."
  exit 0
fi

echo "Kicking Arc off Wi-Fi to force a clean reassociation..."
kick

printf "Waiting for recovery"
for ((i = 0; i < RECOVER_WAIT; i += 3)); do
  if http_ok; then
    echo " - back after ${i}s."
    echo "Arc $ARC_IP: $(state)"
    exit 0
  fi
  printf "."
  sleep 3
done

echo " - still down after ${RECOVER_WAIT}s."
echo "The kick did not revive it this time - a physical power cycle is the fallback." >&2
exit 1
