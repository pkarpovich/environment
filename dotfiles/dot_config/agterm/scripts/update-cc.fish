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
# No argument: every session whose main pane runs an idle Claude older than the
# installed build, resumed. Claude also updates itself in the background, so
# `claude update` saying "up to date" does not mean the running processes are; the
# build a process runs is the versions/ directory its executable was mapped from.
# With a session (id or prefix): only that one, whatever its status or build, and a
# pane sitting at a shell prompt is started too.
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

for row in ($AGTERMCTL tree --json | $JQ -r '
    [.result.tree.workspaces[].sessions[]] | .[]
    | ((.foreground // [])[0] // "" | test("(^|/)claude$")) as $cc
    | "\(.id)\t\($cc)\t\(.status // "idle")\t\(.foregroundShell // "")"')

    set -l f (string split \t -- $row)
    set -l id $f[1]
    set -l cc $f[2]
    set -l agent_status $f[3]
    set -l shell $f[4]

    # a batch leaves a mid-task agent alone: killing it would drop the tool call in
    # flight. A session named explicitly is the user's own call
    if test -n "$only"
        string match -qi "$only*" -- $id; or continue
    else
        test $cc = true; and test $agent_status != active; or continue
    end

    # anything other than Claude or a bare shell (an editor, a server) is not ours to kill
    if test $cc != true; and test -z "$shell"
        $AGTERMCTL notify "update-cc: $id runs something else, skipped" --title update-cc
        set skipped (math $skipped + 1)
        continue
    end

    set -l conv ""
    set -l entry $MAP/$id
    if test -f $entry
        set conv ($JQ -r '.conv // empty' $entry)
    end

    if test -z "$conv"
        $AGTERMCTL notify "update-cc: no mapped conversation for $id, skipped" --title update-cc
        set skipped (math $skipped + 1)
        continue
    end

    if test -z "$only"
        set -l pid ($JQ -r '.pid // empty' $entry)
        set -l running ""
        test -n "$pid"; and set running (lsof -a -p $pid -d txt -Fn 2>/dev/null | string match -r -g '/claude/versions/([^/]+)$')[1]
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

    set -l cmd "CLAUDE_CODE_NO_FLICKER=1 claude --enable-auto-mode --resume $conv"
    if $AGTERMCTL session restart --pane left --target $id --command $cmd >/dev/null 2>&1
        set done (math $done + 1)
    else
        $AGTERMCTL notify "update-cc: restarting $id failed" --title update-cc
        set skipped (math $skipped + 1)
    end
end

if test -z "$only"
    $AGTERMCTL notify "update-cc: $done restarted on $current, $uptodate already on it, $skipped skipped" --title update-cc
end
