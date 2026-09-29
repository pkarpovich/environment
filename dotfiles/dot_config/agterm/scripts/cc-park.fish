#!/opt/homebrew/bin/fish
# @agt.name Park every Claude on the Mac -- agterm
# @agt.desc kill the agterm-side clients, leave the mirrored ones running
# @agt.name Park every Claude on the tmux side -- tmux
# @agt.desc kill the mirrored clients, the Mac side keeps working
# Kill interactive Claude TUIs on one side of the MBP<->tmux pair (single-client model):
#   agterm - claudes whose ancestry includes the agterm app
#   tmux   - claudes whose ancestry includes a tmux server
# Only interactive TUIs match (argv has --enable-auto-mode) - ralphex/headless runs untouched.
# macOS forbids reading other processes' env, so side detection walks the parent chain.
# With a second argument (an agterm session id) only that session's claude is parked,
# by the pid the cc-map hook recorded - the conversation id is NOT a reliable argv
# marker (a resumed claude rewrites its process title and drops it). A claude older
# than that hook has no recorded pid and is identified by working directory instead.
# CC_PARK_DRYRUN=1 prints matching pids instead of killing.
set -l JQ /opt/homebrew/bin/jq
set -l AGTERMCTL /opt/homebrew/bin/agtermctl
set -l MAP ~/.local/state/agterm/cc-map
set -l PARKED_COLOR '#8B7EC8'
set -l PARKED_SHAPE diamond

set -l side $argv[1]
set -l target $argv[2]
switch "$side"
    case agterm tmux
    case '*'
        echo "usage: cc-park.fish agterm|tmux [session-id]" >&2
        exit 1
end

# macOS ps shows the tmux server under the argv that spawned it (`tmux
# new-session … claude --enable-auto-mode`), never as a "tmux: server" title
function is_tmux --argument-names cmd
    string match -qr '^(.*/)?tmux( |$)|^tmux: server' -- $cmd
end

function side_of --argument-names start
    set -l p $start
    while test -n "$p"; and test "$p" -gt 1 2>/dev/null
        set -l cmd (ps -o command= -p $p 2>/dev/null)
        if is_tmux "$cmd"
            echo tmux
            return
        end
        if string match -q '*agterm.app/Contents/MacOS/agterm*' -- $cmd
            echo agterm
            return
        end
        set p (ps -o ppid= -p $p 2>/dev/null | string trim)
    end
    echo none
end

# -a: without it pgrep hides its own ancestors, so a park invoked from inside a
# Claude session would silently skip that very claude.
# The tmux server itself is dropped: a session started as `tmux new-session …
# claude --enable-auto-mode …` carries that argv, so the server matches both the
# pgrep filter and the *claude* one below - killing it would take down every
# session on that side instead of one client.
set -l all_pids
for pid in (pgrep -a -f -- '--enable-auto-mode' 2>/dev/null)
    is_tmux (ps -o command= -p $pid 2>/dev/null); and continue
    set -a all_pids $pid
end

set -l pids
if test -z "$target"
    set pids $all_pids
else
    set pids ($JQ -r '.pid // empty' $MAP/$target 2>/dev/null)
    # the recorded pid is whichever claude ran the hook, i.e. the agterm-side one;
    # parking the tmux side of the same session falls through to the directory
    # match below
    test -n "$pids"; and test (side_of $pids) != "$side"; and set pids
end

if test -n "$target"; and test -z "$pids"
    set -l want ($JQ -r '.cwd // empty' $MAP/$target 2>/dev/null)
    set -l claimed
    for e in $MAP/*
        test -f $e; or continue
        test (path basename $e) = "$target"; and continue
        set -l p ($JQ -r '.pid // empty' $e 2>/dev/null)
        test -n "$p"; and set -a claimed $p
    end
    for pid in $all_pids
        contains -- $pid $claimed; and continue
        test (side_of $pid) = "$side"; or continue
        set -l pcwd (/usr/sbin/lsof -a -d cwd -p $pid -Fn 2>/dev/null | string replace -r '^n' '')
        test "$pcwd" = "$want"; or continue
        set -a pids $pid
    end
    if test (count $pids) -gt 1
        echo "cc-park: several unclaimed claudes in $want ($pids) - open that session on the Mac once so the hook records its pid" >&2
        exit 1
    end
    if test (count $pids) -eq 1; and test -z "$CC_PARK_DRYRUN"
        set -l tmp (mktemp $MAP/.tmp.XXXXXX)
        and $JQ --argjson p $pids[1] '.pid = $p' $MAP/$target > $tmp
        and mv -f $tmp $MAP/$target
    end
end

set -l killed_pids
for pid in $pids
    string match -q '*claude*' -- (ps -o command= -p $pid 2>/dev/null); or continue
    test (side_of $pid) = "$side"; or continue
    set -a killed_pids $pid
    if test -n "$CC_PARK_DRYRUN"
        echo $pid
    else
        kill $pid 2>/dev/null
    end
end

if test -n "$target"; and test (count $killed_pids) -eq 0
    echo "cc-park: no live claude for $target on the $side side" >&2
    exit 1
end

# sticky restore pins would resurrect the killed claudes on the next agterm
# launch (e.g. a reboot while working from the MBA) - drop them; reopen-cc's
# resume re-pins each one via the SessionStart hook
if test "$side" = agterm; and test -z "$CC_PARK_DRYRUN"
    if test -n "$target"
        $AGTERMCTL session restore --clear --target $target >/dev/null 2>&1
    else
        for entry in $MAP/*
            test -f $entry; or continue
            $AGTERMCTL session restore --clear --target (path basename $entry) >/dev/null 2>&1
        end
    end

    # mark every parked row so the sidebar shows at a glance which conversations
    # moved to the MBA and need a reopen. The tint holds because nothing else sets
    # a status while the session sits at its shell - resuming the conversation
    # fires the agent-status hooks, which drop the override on their own
    for entry in $MAP/*
        test -f $entry; or continue
        set -l id (path basename $entry)
        if test -n "$target"
            test "$id" = "$target"; or continue
        else
            set -l p ($JQ -r '.pid // empty' $entry 2>/dev/null)
            test -n "$p"; or continue
            contains -- $p $killed_pids; or continue
        end
        $AGTERMCTL session status completed --color $PARKED_COLOR --shape $PARKED_SHAPE \
            --target $id >/dev/null 2>&1
    end
end
exit 0
