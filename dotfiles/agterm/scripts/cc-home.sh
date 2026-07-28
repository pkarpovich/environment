#!/bin/sh
# Send the conversation mirrored into this tmux window back to the Mac: find the
# cc-map entry ccz stamped with this window id and hand its agterm session id to
# reopen-cc.sh, which parks the client here and resumes the conversation there.
# Window ids are unique server-wide, so twindow alone identifies the entry.
JQ=/opt/homebrew/bin/jq
MAP="$HOME/.local/state/agterm/cc-map"

want=${1:-$(tmux display-message -p '#{window_id}' 2>/dev/null)}
if [ -z "$want" ]; then
  echo "cc-home: no tmux window to resolve - run this from inside tmux" >&2
  exit 1
fi

for entry in "$MAP"/*; do
  [ -f "$entry" ] || continue
  [ "$("$JQ" -r '.twindow // empty' "$entry" 2>/dev/null)" = "$want" ] || continue
  exec "$HOME/.config/agterm/scripts/reopen-cc.sh" "${entry##*/}"
done

echo "cc-home: window $want is not a mirror of any mapped session" >&2
exit 1
