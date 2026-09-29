#!/opt/homebrew/bin/fish
# @agt.name Mark a session to come back to
# @agt.desc put the status glyph back next to its name, as a star
# @agt.name Clear a session mark -- --clear
# @agt.desc drop the glyph off a session you are done with
#
# The status glyph belongs to the agent: a keystroke in the pane that set it
# wipes it, so opening a finished session by accident throws away the green dot
# you were reading as a to-do. This puts it back by hand, as a yellow STAR
# instead of the default circle so the mark says "a human put this here" rather
# than "an agent finished". Nothing else about the session changes.
#
# The glyph is as fragile as the one you lost - typing in the session clears it
# again. That is the point: you take the mark off by working there.
set -l AGTERMCTL /opt/homebrew/bin/agtermctl
set -l JQ /opt/homebrew/bin/jq
set -l TAB (printf '\t')
set -l COLOR '#f5ae2e'   # the earthsong yellow the tmux status bar already uses

function fail --argument-names msg
    /opt/homebrew/bin/agtermctl notify $msg --title Mark >/dev/null 2>&1
    exit 1
end

set -l win active
test -n "$AGT_WINDOW_ID"; and set win $AGT_WINDOW_ID

set -l clear 0
contains -- --clear $argv; and set clear 1

set -l sessions ($AGTERMCTL tree --json --window $win | $JQ -r '.result.tree.workspaces[] as $w
    | $w.sessions[] | [.id, .name, $w.name, (.status // "-")] | @tsv')
test (count $sessions) -gt 0; or fail "this window has no sessions"

# clearing offers only what carries a glyph; marking offers everything
set -l rows
for s in $sessions
    set -l f (string split $TAB -- $s)
    test $clear -eq 1; and test "$f[4]" = -; and continue
    set -l sub $f[3]
    test "$f[4]" != -; and set sub "$f[4] - $f[3]"
    set -a rows "$f[1]$TAB$f[2]$TAB$sub"
end
test (count $rows) -gt 0; or fail "no session carries a status glyph"

set -l items (printf '%s\n' $rows | $JQ -R -s 'split("\n") | map(select(length > 0) | split("\t"))
    | map({id: .[0], label: .[1], subtitle: .[2]})' | string collect)
set -l prompt mark
test $clear -eq 1; and set prompt "clear mark"
set -l choice (printf '%s' $items | $AGTERMCTL pick --prompt $prompt --window $win)
test $status -eq 0; or exit 0
set -l sid (printf '%s' $choice | $JQ -r 'select(.result == "picked") | .id')
test -n "$sid"; or exit 0

if test $clear -eq 1
    $AGTERMCTL session status idle --target $sid >/dev/null 2>&1
else
    $AGTERMCTL session status completed --shape star --color $COLOR --target $sid >/dev/null 2>&1
end
