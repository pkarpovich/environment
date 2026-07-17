#!/bin/sh
# jump to the Nth session in sidebar order (workspaces flattened top-to-bottom)
AGTERMCTL=/opt/homebrew/bin/agtermctl
JQ=/opt/homebrew/bin/jq
id=$("$AGTERMCTL" tree --json | "$JQ" -r '.result.tree.workspaces[].sessions[].id' | sed -n "${1}p")
[ -z "$id" ] && exit 0
exec "$AGTERMCTL" session select --target "$id"
