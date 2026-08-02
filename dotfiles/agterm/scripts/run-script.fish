#!/opt/homebrew/bin/fish
# Run one of this directory's scripts through agterm's native picker (agterm >=
# 0.19.0). A script joins the palette by carrying a marker comment, so the list
# lives in the scripts themselves and nothing has to be kept in sync here:
#
#   # @agt.name Fork this Claude conversation
#   # @agt.desc new session below this one, both copies continue independently
#   # @agt.name Reopen this CC session -- "$AGT_SESSION_ID"
#
# @agt.desc is optional and belongs to the @agt.name line above it; the picker
# shows it as the row's subtitle. Everything after " -- " is passed as arguments
# and expanded at run time, which is how one script contributes several rows
# (cc-park has one per side). The hooks and the watcher carry no marker: running
# them by hand would corrupt the map rather than do anything useful.
#
# Runs as a keymap custom command, so the runner exports AGT_* and sends stdout
# and stderr to /dev/null - anything the reader must see goes through `notify`.
set -l AGTERMCTL /opt/homebrew/bin/agtermctl
set -l JQ /opt/homebrew/bin/jq
set -l DIR ~/.config/agterm/scripts
set -l TAB (printf '\t')

function fail --argument-names msg
    set -l agt /opt/homebrew/bin/agtermctl
    if test -n "$AGT_SOCKET"
        $agt notify $msg --title "Run Script" --socket $AGT_SOCKET >/dev/null 2>&1
    else
        $agt notify $msg --title "Run Script" >/dev/null 2>&1
    end
    exit 1
end

set -l rows
for f in $DIR/*
    test -f $f; or continue
    set -l cmd ""
    set -l label ""
    set -l desc ""
    for line in (grep -E '^#[ \t]*@agt\.(name|desc)[ \t]' $f 2>/dev/null)
        set -l name_m (string match -r '^#[ \t]*@agt\.name[ \t]+(.*)$' -- $line)
        if test (count $name_m) -eq 2
            test -n "$label"; and set -a rows "$cmd$TAB$label$TAB$desc"
            set desc ""
            set -l spec (string trim -- $name_m[2])
            if string match -q '* -- *' -- $spec
                set label (string trim -- (string replace -r ' -- .*$' '' -- $spec))
                set cmd "$f "(string replace -r '^.* -- ' '' -- $spec)
            else
                set label $spec
                set cmd $f
            end
            continue
        end
        set -l desc_m (string match -r '^#[ \t]*@agt\.desc[ \t]+(.*)$' -- $line)
        test (count $desc_m) -eq 2; and set desc (string trim -- $desc_m[2])
    end
    test -n "$label"; and set -a rows "$cmd$TAB$label$TAB$desc"
end

test (count $rows) -gt 0; or fail "no script carries an @agt.name marker"

set -l items (printf '%s\n' $rows | $JQ -R -s 'split("\n") | map(select(length > 0) | split("\t"))
    | map({id: .[0], label: .[1]}
          + (if (.[2] // "") == "" then {} else {subtitle: .[2]} end))' | string collect)

set -l choice (printf '%s' $items | $AGTERMCTL pick --prompt run --window (test -n "$AGT_WINDOW_ID"; and echo $AGT_WINDOW_ID; or echo active))
set -l rc $status
switch $rc
    case 0
    case 2
        exit 0   # cancelled at the picker, a normal way out
    case '*'
        fail "picker failed (exit $rc)"
end

set -l picked (printf '%s' $choice | $JQ -r 'select(.result == "picked") | .id' 2>/dev/null)
test -n "$picked"; or exit 0

# the marker writes its arguments as shell words ("$AGT_SESSION_ID"), so they are
# expanded here rather than handed over literally
eval exec $picked
