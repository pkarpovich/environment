#!/opt/homebrew/bin/fish
# Claude Code SessionEnd hook: when the user deliberately quits claude at the
# prompt (Ctrl+C/Ctrl+D/exit, /logout), forget the session's cc-map entry and
# restore pin so nothing resurrects the conversation - not reopen-cc, not ccm,
# not the next agterm launch. Any other end reason (clear, teardown on app
# quit/restart) keeps both: that is exactly the state a restart must restore.
# The entry is removed only if it still points to THIS conversation, so a late
# end event from an old one cannot wipe a newer mapping.
set -l JQ /opt/homebrew/bin/jq
set -l MAP ~/.local/state/agterm/cc-map

test -n "$AGTERM_SESSION_ID"; or exit 0
test "$AGTERM_PANE" = left; or exit 0

set -l input (cat | string collect)
set -l conv (printf '%s' $input | $JQ -r '.session_id // empty')
set -l reason (printf '%s' $input | $JQ -r '.reason // empty')
test -n "$conv"; or exit 0
switch $reason
    case prompt_input_exit logout exit
    case '*'
        exit 0
end

set -l entry $MAP/$AGTERM_SESSION_ID
test -f $entry; or exit 0
set -l have ($JQ -r '.conv // empty' $entry)
test "$have" = "$conv"; or exit 0

rm -f $entry
/opt/homebrew/bin/agtermctl session restore --clear --target $AGTERM_SESSION_ID >/dev/null 2>&1
exit 0
