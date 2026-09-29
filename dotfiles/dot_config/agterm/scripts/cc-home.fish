#!/opt/homebrew/bin/fish
# Send the conversation mirrored into this tmux window back to the Mac: find the
# cc-map entry ccm stamped with this window id and hand its agterm session id to
# reopen-cc, which parks the client here and resumes the conversation there.
# Window ids are unique server-wide, so twindow alone identifies the entry.
set -l JQ /opt/homebrew/bin/jq
set -l MAP ~/.local/state/agterm/cc-map

set -l want $argv[1]
test -n "$want"; or set want (tmux display-message -p '#{window_id}' 2>/dev/null)
if test -z "$want"
    echo "cc-home: no tmux window to resolve - run this from inside tmux" >&2
    exit 1
end

for entry in $MAP/*
    test -f $entry; or continue
    set -l tw ($JQ -r '.twindow // empty' $entry 2>/dev/null)
    test "$tw" = "$want"; or continue
    exec ~/.config/agterm/scripts/reopen-cc.fish (path basename $entry)
end

echo "cc-home: window $want is not a mirror of any mapped session" >&2
exit 1
