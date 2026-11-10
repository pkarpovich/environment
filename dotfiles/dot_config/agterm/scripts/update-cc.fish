#!/opt/homebrew/bin/fish
# @agt.name Update Claude in every session
# @agt.desc restart each idle Claude on its own conversation, so a new build takes over
# @agt.name Update Claude in this session -- "$AGT_SESSION_ID"
# @agt.desc restart this Claude and resume its conversation on the new build
# A `claude update` replaces the binary, but every running process keeps the old one
# mapped until it exits. `agtermctl session restart` (Live sessions mode) ends the main
# pane's shell together with its Claude and starts a new shell running the given line,
# in the same directory, so the new build takes over with no /exit typing and no
# waiting for the old TUI to tear down. The conversation comes from cc-map,
# which the SessionStart hook keeps current.
#
# No argument: every pane running an idle Claude older than the installed build,
# in every session. Claude also updates itself in the background, so `claude update`
# saying "up to date" does not mean the running processes are; the build a process
# runs is the versions/ directory its executable was mapped from. The main pane
# resumes its conversation from cc-map; any other pane of a split holds a Claude
# cc-map does not know, so it restarts with the pane's own command line, which is
# what agterm replays without --command. With a session (id or prefix): only that
# one, whatever its status or build, and a main pane at a shell prompt is started too.
# A pane is matched to its Claude by AGTERM_PANE_ID in the process environment.
set -l AGTERMCTL /opt/homebrew/bin/agtermctl
set -l JQ /opt/homebrew/bin/jq
set -l MAP ~/.local/state/agterm/cc-map

set -l only $argv[1]

# the native install downloads new builds in the background, but only a restart
# runs one; `claude update` makes sure the build is there before any pane goes
if not claude update >/dev/null 2>&1
    $AGTERMCTL notify "update-cc: claude update failed" --title update-cc
    exit 1
end
set -l current (path basename (readlink ~/.local/bin/claude))

set -l done 0
set -l skipped 0
set -l uptodate 0

# pid, pane id and build of every interactive Claude, one line each
set -l claudes
for pid in (pgrep -x claude)
    set -l pane (ps -Ewww -p $pid -o command= 2>/dev/null | string match -r -g 'AGTERM_PANE_ID=([0-9A-F-]+)')[1]
    test -n "$pane"; or continue
    set -l build (lsof -a -p $pid -d txt -Fn 2>/dev/null | string match -r -g '/claude/versions/([^/]+)$')[1]
    set -a claudes "$pid $pane $build"
end

for row in ($AGTERMCTL tree --json | $JQ -r '
    [.result.tree.workspaces[].sessions[]] | .[]
    | ((.foreground // [])[0] // "" | test("(^|/)claude$")) as $cc
    | "\(.id)\t\($cc)\t\(.status // "idle")\t\(.foregroundShell // "")\t\([.surfaces[]? | .paneID] | join(" "))"')

    set -l f (string split \t -- $row)
    set -l id $f[1]
    set -l cc $f[2]
    set -l agent_status $f[3]
    set -l shell $f[4]
    set -l panes (string split ' ' -- $f[5])

    if test -n "$only"
        string match -qi "$only*" -- $id; or continue
    else
        # a batch leaves a mid-task agent alone: killing it would drop the tool call
        # in flight. A session named explicitly is the user's own call
        test $agent_status != active; or continue
    end

    set -l conv ""
    set -l entry $MAP/$id
    test -f $entry; and set conv ($JQ -r '.conv // empty' $entry)

    for pane in $panes
        set -l main false
        test "$pane" = "$panes[1]"; and set main true
        set -l hit (string match -r "^\d+ $pane .*" -- $claudes)
        set -l running (string split ' ' -- $hit)[3]

        if test -z "$hit"
            # no Claude here: only the main pane at a bare shell is ours to start,
            # and only when the user named the session
            test -n "$only"; and test $main = true; and test -n "$shell"; or continue
        else if test -z "$only"
            if test "$running" = "$current"
                set uptodate (math $uptodate + 1)
                continue
            end
            if test -z "$running"
                $AGTERMCTL notify "update-cc: cannot tell which build $id runs, skipped" --title update-cc
                set skipped (math $skipped + 1)
                continue
            end
        end

        set -l args --pane-id $pane --target $id
        if test $main = true
            if test -z "$conv"
                $AGTERMCTL notify "update-cc: no mapped conversation for $id, skipped" --title update-cc
                set skipped (math $skipped + 1)
                continue
            end
            set -a args --command "CLAUDE_CODE_NO_FLICKER=1 claude --enable-auto-mode --resume $conv"
        end
        if $AGTERMCTL session restart $args >/dev/null 2>&1
            set done (math $done + 1)
        else
            $AGTERMCTL notify "update-cc: restarting $id ($pane) failed" --title update-cc
            set skipped (math $skipped + 1)
        end
    end
end

if test -z "$only"
    $AGTERMCTL notify "update-cc: $done restarted on $current, $uptodate already on it, $skipped skipped" --title update-cc
end
