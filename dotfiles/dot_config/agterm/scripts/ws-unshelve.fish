#!/opt/homebrew/bin/fish
# @agt.name Unshelve a workspace
# @agt.desc pick a shelved project and rebuild its sessions
# Bring back what ws-shelve wrote: recreate the workspace, its sessions and their
# directories, then start each one again - a Claude by resuming its conversation,
# anything else by re-running the argv the snapshot caught. A session that was
# attached from another host is attached again with `zmx attach`, which lands in
# the window's current workspace, so the workspace is created and selected first.
#
# The shelf file stays after a restore. It is a record of a layout that worked,
# and shelving again overwrites it; delete it by hand when the project is over
# for good.
set -l AGTERMCTL /opt/homebrew/bin/agtermctl
set -l JQ /opt/homebrew/bin/jq
set -l SHELF ~/.local/state/agterm/shelved

function fail --argument-names msg
    /opt/homebrew/bin/agtermctl notify $msg --title Unshelve >/dev/null 2>&1
    exit 1
end

set -l files $SHELF/*.json
test (count $files) -gt 0; or fail "nothing on the shelf"

set -l file $files[1]
if test (count $files) -gt 1
    set -l items ($JQ -n '[inputs | {file: input_filename}] ' $files 2>/dev/null)
    set -l rows
    for f in $files
        set -l name ($JQ -r '.workspace' $f)
        set -l n ($JQ -r '.sessions | length' $f)
        set -l when ($JQ -r '.shelved_at' $f)
        set -a rows (printf '%s\t%s\t%s sessions, shelved %s' $f $name $n (date -r $when '+%d %b'))
    end
    set -l payload (printf '%s\n' $rows | $JQ -R -s 'split("\n") | map(select(length > 0) | split("\t"))
        | map({id: .[0], label: .[1], subtitle: .[2]})' | string collect)
    set -l choice (printf '%s' $payload | $AGTERMCTL pick --prompt unshelve --window (test -n "$AGT_WINDOW_ID"; and echo $AGT_WINDOW_ID; or echo active))
    test $status -eq 0; or exit 0
    set file (printf '%s' $choice | $JQ -r 'select(.result == "picked") | .id')
    test -n "$file"; or exit 0
end

set -l ws_name ($JQ -r '.workspace' $file)
set -l n ($JQ -r '.sessions | length' $file)

set -l win (test -n "$AGT_WINDOW_ID"; and echo $AGT_WINDOW_ID; or echo active)
set -l ws ($AGTERMCTL tree --json --window $win | $JQ -r --arg name "$ws_name" '.result.tree.workspaces[] | select(.name == $name) | .id' | head -1)
test -n "$ws"; or set ws ($AGTERMCTL workspace new $ws_name --window $win)
test -n "$ws"; or fail "could not create workspace $ws_name"
$AGTERMCTL workspace select --target $ws --window $win >/dev/null 2>&1

# the order in the file becomes the order in the sidebar
for i in (seq $n)
    set -l s ($JQ -c ".sessions[$(math $i - 1)]" $file)
    set -l host (printf '%s' $s | $JQ -r '.host // empty')
    if test -n "$host"
        set -l remote_id (printf '%s' $s | $JQ -r '.remote_id')
        set -l new ($AGTERMCTL zmx attach $host $remote_id --window $win 2>/dev/null)
        if test -z "$new"
            $AGTERMCTL notify (printf '%s' $s | $JQ -r '.name')" is gone on $host" --title Unshelve >/dev/null 2>&1
            continue
        end
        $AGTERMCTL session move $ws --target $new --window $win >/dev/null 2>&1
        continue
    end
    set -l cwd (printf '%s' $s | $JQ -r '.cwd // empty')
    test -d "$cwd"; or set cwd $HOME
    set -l conv (printf '%s' $s | $JQ -r '.conv // empty')
    # --name only for a session that is not a Claude: pinning the label of one
    # that is would stop its live title from ever reaching the sidebar
    set -l name_args
    if test -z "$conv"
        set -l saved (printf '%s' $s | $JQ -r '.name // empty')
        test -n "$saved"; and set name_args --name $saved
    end
    set -l new ($AGTERMCTL session new --workspace $ws --cwd $cwd $name_args --window $win)
    test -n "$new"; or continue

    set -l cmd ""
    if test -n "$conv"
        set cmd "CLAUDE_CODE_NO_FLICKER=1 claude --enable-auto-mode --resume $conv"
    else
        set cmd (printf '%s' $s | $JQ -r '.foreground // empty')
    end
    test -n "$cmd"; or continue

    # pin before typing: a restart between the two would otherwise come back to a
    # bare shell, and the cc-map hook only re-pins once Claude is running
    $AGTERMCTL session restore "$cmd" --target $new >/dev/null 2>&1
    printf '%s\n' $cmd | $AGTERMCTL session type --stdin --target $new
end

$AGTERMCTL notify "$ws_name restored ($n sessions)" --title Unshelve >/dev/null 2>&1
