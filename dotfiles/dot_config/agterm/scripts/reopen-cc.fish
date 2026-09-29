#!/opt/homebrew/bin/fish
# @agt.name Reopen every CC session
# @agt.desc park the tmux side and resume every mapped conversation here
# @agt.name Reopen this CC session -- "$AGT_SESSION_ID"
# @agt.desc park just this conversation on the tmux side and resume it here
# Bring Claude conversations home to agterm (single-client model): kill tmux-side
# window claudes and stale agterm TUIs, then resume each mapped session's conversation
# in its agterm session. With an argument - only that session (id or prefix): just
# its own tmux-side claude is parked, the rest of both sides is left alone.
set -l AGTERMCTL /opt/homebrew/bin/agtermctl
set -l JQ /opt/homebrew/bin/jq
set -l MAP ~/.local/state/agterm/cc-map
set -l PARK ~/.config/agterm/scripts/cc-park.fish

set -l only $argv[1]
if test -z "$only"
    $PARK tmux
    $PARK agterm
end

for id in ($AGTERMCTL tree --json | $JQ -r '[.result.tree.workspaces[].sessions[]] | .[].id')
    set -l entry $MAP/$id
    test -f $entry; or continue
    if test -n "$only"
        string match -qi "$only*" -- $id; or continue
    end

    # a session still running something is left alone: typing a resume into a
    # busy pane would land in whatever is on screen
    set -l ok ""
    for i in (seq 20)
        set -l fg ($AGTERMCTL tree --json | $JQ -r --arg id $id \
            '[.result.tree.workspaces[].sessions[]] | .[] | select(.id==$id) | (.foreground // []) | join(" ")')
        if test -z "$fg"
            set ok 1
            break
        end
        sleep 0.25
    end
    if test -z "$ok"
        $AGTERMCTL notify "reopen-cc: session $id busy, skipped" --title reopen-cc
        continue
    end

    set -l conv ($JQ -r '.conv // empty' $entry)
    test -n "$conv"; or continue
    # a mirrored conversation is still live in its tmux window; resuming it here
    # without parking that one first would put two clients on it
    test -n "$only"; and $PARK tmux $id >/dev/null 2>&1
    set -l cmd "CLAUDE_CODE_NO_FLICKER=1 claude --enable-auto-mode --resume $conv"
    test ($JQ -r '.profile // "personal"' $entry) = work; and set cmd "CLAUDE_CONFIG_DIR=~/.claude-work $cmd"
    printf '%s\n' $cmd | $AGTERMCTL session type --stdin --target $id
    # drop the parked marker cc-park left on the row: the agent-status hooks only
    # fire from the first prompt onward, so a resumed session would keep it until
    # the next message
    $AGTERMCTL session status idle --target $id >/dev/null 2>&1
end
