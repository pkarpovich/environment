#!/bin/sh
# agterm events watcher (launchd: com.pavel-karpovich.cc-map-watch): drop a
# session's cc-map entry the moment the session is closed (sidebar close,
# workspace or window delete), so ccl/ccz/reopen-cc never see orphans. App
# quit does not emit session.closed - the map survives restarts. agtermctl
# exits when agterm quits; launchd KeepAlive restarts the watcher (30s
# throttle) and `events` resubscribes from the current tail.
AGTERMCTL=/opt/homebrew/bin/agtermctl
JQ=/opt/homebrew/bin/jq
MAP="$HOME/.local/state/agterm/cc-map"

"$AGTERMCTL" events --json --kind session.closed | while IFS= read -r line; do
  id=$(printf '%s' "$line" | "$JQ" -r '.session // empty')
  [ -n "$id" ] && rm -f -- "$MAP/$id"
done
