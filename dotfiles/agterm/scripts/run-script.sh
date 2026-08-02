#!/bin/sh
# Run one of this directory's scripts through agterm's native picker (agterm >=
# 0.19.0). A script joins the palette by carrying a marker comment, so the list
# lives in the scripts themselves and nothing has to be kept in sync here:
#
#   # @agt.name Fork this Claude conversation
#   # @agt.desc same directory, both copies continue independently
#   # @agt.name Reopen this CC session -- "$AGT_SESSION_ID"
#
# @agt.desc is optional and belongs to the @agt.name line above it; the picker
# shows it as the row's subtitle.
#
# Everything after " -- " is passed as arguments and expanded at run time, which is
# how one script contributes several rows (cc-park has one per side). The hooks and
# the watcher carry no marker: running them by hand would corrupt the map rather
# than do anything useful. tuna-scripts stay out of this on purpose - they already
# have their own chords in Tuna, and a second way in is just a longer list.
#
# Runs as a keymap custom command, so the runner exports AGT_* and sends stdout and
# stderr to /dev/null - anything the reader must see goes through `notify`.
set -eu

AGTERMCTL=/opt/homebrew/bin/agtermctl
JQ=/opt/homebrew/bin/jq
DIR="$HOME/.config/agterm/scripts"

agt() {
    if [ -n "${AGT_SOCKET:-}" ]; then
        "$AGTERMCTL" "$@" --socket "$AGT_SOCKET"
    else
        "$AGTERMCTL" "$@"
    fi
}

fail() {
    agt notify "$1" --title "Run Script" >/dev/null 2>&1 || true
    exit 1
}

[ -x "$JQ" ] || fail "jq is not at $JQ"

# one TSV line per marker: the command to run, then the label the row shows
rows() {
    # any language: the marker is a "#" comment in sh, fish and zsh alike
    for f in "$DIR"/*; do
        [ -f "$f" ] || continue
        # awk rather than sed: a row is built from two lines (name, optional desc),
        # so the scan needs to hold the previous one until the next name arrives
        awk -v file="$f" '
            sub(/^#[ \t]*@agt\.name[ \t]*/, "") {
                if (name != "") print cmd "\t" name "\t" desc
                desc = ""
                if (match($0, / -- /)) {
                    name = substr($0, 1, RSTART - 1)
                    cmd = file " " substr($0, RSTART + 4)
                } else {
                    name = $0
                    cmd = file
                }
                next
            }
            sub(/^#[ \t]*@agt\.desc[ \t]*/, "") { desc = $0; next }
            END { if (name != "") print cmd "\t" name "\t" desc }
        ' "$f"
    done
}

LIST=$(rows)
[ -n "$LIST" ] || fail "no script carries an @agt.name marker"

ITEMS=$(printf '%s\n' "$LIST" |
    "$JQ" -R -s 'split("\n") | map(select(length > 0) | split("\t"))
                 | map({id: .[0], label: .[1]}
                       + (if (.[2] // "") == "" then {} else {subtitle: .[2]} end))')

set +e
CHOICE=$(printf '%s' "$ITEMS" | agt pick --prompt "run" --window "${AGT_WINDOW_ID:-active}")
rc=$?
set -e
case $rc in
    0) ;;
    2) exit 0 ;;  # cancelled at the picker, a normal way out
    *) fail "picker failed (exit $rc)" ;;
esac

CMD=$(printf '%s' "$CHOICE" | "$JQ" -r 'select(.result == "picked") | .id' 2>/dev/null || true)
[ -n "$CMD" ] || exit 0

# the marker writes its arguments as shell words ("$AGT_SESSION_ID"), so they are
# expanded here rather than handed over literally
eval "exec $CMD"
