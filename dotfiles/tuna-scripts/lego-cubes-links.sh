#!/bin/bash
# @tuna.name Lego Cubes Links
# @tuna.subtitle Open every link from the Links section of the Lego Cubes episode open in Obsidian
# @tuna.mode inline

set -euo pipefail

JQ=/opt/homebrew/bin/jq
BROWSER_ID="company.thebrowser.dia"
OBSIDIAN_CONFIG="$HOME/Library/Application Support/obsidian/obsidian.json"

DEFAULT_URLS="https://app.trakt.tv/users/taller_stk/mir/$(date -v1d -v-1m '+%Y/%-m')
https://track.toggl.com/reports/
https://cloud.ouraring.com/trends
https://grafana.pkarpovich.space/d/6LB43bzZz/drewnowska-weather-station?from=now-24h&to=now&timezone=browser&var-Station=&var-Module=\$__all&refresh=15m
https://windy.com/"

notify() { osascript -e "display notification \"$1\" with title \"Lego Cubes Links\""; }

VAULT=$("$JQ" -r '.vaults[] | select(.open == true) | .path' "$OBSIDIAN_CONFIG" | head -1)
if [ -z "$VAULT" ]; then
  notify "No open Obsidian vault"
  exit 1
fi

NOTE=$("$JQ" -r '.active as $active | .. | objects | select(.id? == $active) | .state.state.file // empty' "$VAULT/.obsidian/workspace.json" | head -1)
case "$NOTE" in
  "Lego Cubes "[0-9][0-9][0-9]" -"*.md) ;;
  *)
    notify "Open a Lego Cubes episode in Obsidian first"
    exit 1
    ;;
esac

URLS=$(awk '/^## /{inside = ($0 == "## Links"); next} inside && /^- https?:\/\//{print $2}' "$VAULT/$NOTE")

printf '%s\n%s\n' "$DEFAULT_URLS" "$URLS" | xargs open -b "$BROWSER_ID"

DEFAULT_COUNT=$(printf '%s\n' "$DEFAULT_URLS" | wc -l | tr -d ' ')
if [ -z "$URLS" ]; then
  notify "Episode ${NOTE:11:3} has no links, opened $DEFAULT_COUNT defaults"
else
  notify "Episode ${NOTE:11:3}: $(printf '%s\n' "$URLS" | wc -l | tr -d ' ') links + $DEFAULT_COUNT defaults"
fi
