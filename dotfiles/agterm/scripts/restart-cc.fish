#!/opt/homebrew/bin/fish
# @agt.name Restart every CC session
# @agt.desc exit each Claude and resume the same conversation, so a new build takes over
# @agt.name Restart this CC session -- "$AGT_SESSION_ID"
# @agt.desc exit just this Claude and resume its conversation on the new build
# A `claude update` replaces the binary, but every running process keeps the old one
# mapped until it exits. This walks the tree, quits each Claude and resumes the same
# conversation, so the new build takes over without losing history. With an argument -
# only that session (id or prefix).
set -l AGTERMCTL /opt/homebrew/bin/agtermctl
set -l JQ /opt/homebrew/bin/jq
set -l MAP ~/.local/state/agterm/cc-map

set -l only $argv[1]
set -l done 0
set -l skipped 0

# a session whose agent is mid-task is left alone: /exit would land in the middle of a
# tool call, and the work in flight is worth more than the version bump
for row in ($AGTERMCTL tree --json | $JQ -r '
    [.result.tree.workspaces[].sessions[]] | .[]
    | select((.foreground // []) | (length > 0) and (.[0] | test("/claude$")))
    | select(.status != "active")
    | . as $s
    | (($s.foreground | index("--resume")) // -1) as $i
    | select($i >= 0)
    | "\($s.id)\t\($s.foreground[$i+1])"')

    set -l id (string split -f1 \t -- $row)
    set -l conv (string split -f2 \t -- $row)

    if test -n "$only"
        string match -qi "$only*" -- $id; or continue
    end

    printf '/exit\n' | $AGTERMCTL session type --stdin --target $id

    # wait for the process to actually go: typing the resume while Claude is still
    # tearing down would feed the line to a dying TUI instead of the shell
    set -l gone ""
    for i in (seq 40)
        set -l fg ($AGTERMCTL tree --json | $JQ -r --arg id $id \
            '[.result.tree.workspaces[].sessions[]] | .[] | select(.id==$id) | (.foreground // []) | join(" ")')
        if test -z "$fg"
            set gone 1
            break
        end
        sleep 0.25
    end
    if test -z "$gone"
        $AGTERMCTL notify "restart-cc: $id did not exit, skipped" --title restart-cc
        set skipped (math $skipped + 1)
        continue
    end

    # bare `claude`, not the absolute path the old process reported: PATH is what
    # resolves to the build that just landed
    set -l cmd "CLAUDE_CODE_NO_FLICKER=1 claude --enable-auto-mode --resume $conv"
    set -l entry $MAP/$id
    if test -f $entry
        test ($JQ -r '.profile // "personal"' $entry) = work
        and set cmd "CLAUDE_CONFIG_DIR=~/.claude-work $cmd"
    end
    printf '%s\n' $cmd | $AGTERMCTL session type --stdin --target $id
    set done (math $done + 1)
end

$AGTERMCTL notify "restart-cc: $done restarted, $skipped skipped" --title restart-cc
