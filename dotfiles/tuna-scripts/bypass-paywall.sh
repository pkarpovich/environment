#!/bin/bash
# @tuna.name Bypass Paywall
# @tuna.subtitle Reopen the current Dia tab through the best paywall bypass for that site
# @tuna.mode inline

# Reads the URL of Dia's active tab, picks the paywall-bypass service that
# actually works for that site (routing below), and opens the cleaned URL back
# in Dia. Modeled on the Raycast "remove-paywall" extension, whose whole trick is
# just building "{service}/{original_url}" - a third-party proxy renders the page.
#
# Service routing reflects what is alive and effective as of mid-2026:
#   - archive.today  - the ONLY one that beats hard, server-side paywalls
#                      (NYT, WSJ, Bloomberg, FT, Economist, WaPo, etc.).
#                      /newest/ jumps to the latest existing snapshot; if none
#                      exists yet it shows a create-snapshot page (CAPTCHA) - the
#                      one case this can't fully automate.
#   - freedium-mirror.cfd - Medium family only (medium.com + custom/family domains).
#   - smry.ai        - soft/metered paywalls + a solid default (covers Substack).
# 12ft.io and 1ft.io are intentionally absent: both dead/unreliable in 2026.
#
# Reading the tab URL uses AppleScript (Dia = chromium engine -> active tab). The
# first run from tuna triggers a one-time "Tuna wants to control Dia" prompt.

set -euo pipefail

# --- config ---
BROWSER_ID="company.thebrowser.dia"
BROWSER_APP="Dia"

MEDIUM_DOMAINS="medium.com towardsdatascience.com betterprogramming.pub levelup.gitconnected.com uxdesign.cc"
HARD_DOMAINS="nytimes.com wsj.com bloomberg.com ft.com economist.com washingtonpost.com theatlantic.com newyorker.com wired.com businessinsider.com"

notify() { osascript -e "display notification \"$1\" with title \"Bypass Paywall\""; }

# true if host equals one of the given domains or is a subdomain of it
host_matches() {
  local h=$1; shift
  local d
  for d in "$@"; do
    [ "$h" = "$d" ] && return 0
    case "$h" in *".$d") return 0 ;; esac
  done
  return 1
}

# --- read the active Dia tab ---
URL=$(osascript -e "tell application \"$BROWSER_APP\" to get URL of active tab of front window" 2>/dev/null || true)

case "$URL" in
  http://*|https://*) ;;
  *)
    notify "Could not read a web URL from Dia's active tab."
    exit 1
    ;;
esac

# --- normalize host: strip scheme, path, port, leading www., lowercase ---
host=${URL#*://}
host=${host%%/*}
host=${host%%:*}
host=${host#www.}
host=$(printf '%s' "$host" | tr 'A-Z' 'a-z')

# --- route host -> service ---
if host_matches "$host" $MEDIUM_DOMAINS; then
  service="freedium"
  target="https://freedium-mirror.cfd/$URL"
elif host_matches "$host" $HARD_DOMAINS; then
  service="archive.today"
  target="https://archive.ph/newest/$URL"
else
  service="smry.ai"
  target="https://smry.ai/$URL"
fi

open -b "$BROWSER_ID" "$target"
notify "$host -> $service"
