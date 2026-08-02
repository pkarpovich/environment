#!/opt/homebrew/bin/fish
# agterm events watcher (launchd: com.pavel-karpovich.cc-map-watch): drop a
# session's cc-map entry the moment the session is closed (sidebar close,
# workspace or window delete), so ccl/ccm/reopen-cc never see orphans. App
# quit does not emit session.closed - the map survives restarts. agtermctl
# exits when agterm quits; launchd KeepAlive restarts the watcher (30s
# throttle) and `events` resubscribes from the current tail.
set -l AGTERMCTL /opt/homebrew/bin/agtermctl
set -l JQ /opt/homebrew/bin/jq
set -l MAP ~/.local/state/agterm/cc-map

$AGTERMCTL events --json --kind session.closed | while read -l line
    set -l id (printf '%s' $line | $JQ -r '.session // empty')
    test -n "$id"; and rm -f -- $MAP/$id
end
