#!/bin/bash
# Claude Code SessionEnd hook: when the user deliberately quits claude at the
# prompt (Ctrl+C/Ctrl+D/exit, /logout), forget the session's cc-map entry and
# restore pin so nothing resurrects the conversation - not reopen-cc, not ccz,
# not the next agterm launch. Any other end reason (clear, teardown on app
# quit/restart) keeps both: that is exactly the state a restart must restore.
# The entry is removed only if it still points to THIS conversation, so a late
# end event from an old one cannot wipe a newer mapping.
JQ=/opt/homebrew/bin/jq
MAP="$HOME/.local/state/agterm/cc-map"

[ -n "$AGTERM_SESSION_ID" ] || exit 0
[ "$AGTERM_PANE" = "left" ] || exit 0

input=$(cat)
conv=$(printf '%s' "$input" | "$JQ" -r '.session_id // empty')
reason=$(printf '%s' "$input" | "$JQ" -r '.reason // empty')
[ -n "$conv" ] || exit 0
case "$reason" in
  prompt_input_exit|logout|exit) ;;
  *) exit 0 ;;
esac

entry="$MAP/$AGTERM_SESSION_ID"
[ -f "$entry" ] || exit 0
[ "$("$JQ" -r '.conv // empty' "$entry")" = "$conv" ] || exit 0

rm -f "$entry"
/opt/homebrew/bin/agtermctl session restore --clear --target "$AGTERM_SESSION_ID" >/dev/null 2>&1
exit 0
