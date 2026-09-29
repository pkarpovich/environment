#!/opt/homebrew/bin/fish
# @agt.name Attach a session from the MBP
# @agt.desc pick one of the MBP's live sessions and open it here, marked remote
# @agt.name Attach every flagged session from the MBP -- --flagged
# @agt.desc open all of the MBP's flagged sessions here in one go, skipping ones already attached
#
# Port of agterm's cookbook/remote-session-picker, reworked for two Macs:
#   - the host defaults to the MBP (ssh alias mbp-2021); pass another as the first
#     argument or set AGT_REMOTE_HOST
#   - rows carry the far side's agent status and flag, flagged ones first
#   - a session already attached here is marked and selected on pick, and --flagged skips it
#
# `zmx tree HOST` only lists sessions whose every pane has a live daemon, so the far
# side must run in Live sessions mode. It does not carry flags or agent status, so
# those come from one extra `agtermctl tree` over the same ssh.
#
# An attached row does not report which far-side session it mirrors, only its
# host, so "already attached" is matched by host plus name: picking such a row
# selects the local copy instead of attaching a second one. Two far-side sessions
# with the same name read as attached once either one is.
#
# Runs as a keymap custom command: stdout and stderr go to /dev/null, so anything
# the reader must see goes through `notify`.
set -l AGTERMCTL /opt/homebrew/bin/agtermctl
set -l JQ /opt/homebrew/bin/jq
set -l DEFAULT_HOST mbp-2021

set -l flagged_only 0
set -l host ""
for a in $argv
    switch $a
        case --flagged
            set flagged_only 1
        case '*'
            set host $a
    end
end
test -n "$host"; or set host $AGT_REMOTE_HOST
test -n "$host"; or set host $DEFAULT_HOST

set -l sock
test -n "$AGT_SOCKET"; and set sock --socket $AGT_SOCKET

function fail --argument-names msg
    set -l s
    test -n "$AGT_SOCKET"; and set s --socket $AGT_SOCKET
    /opt/homebrew/bin/agtermctl notify $msg --title "Attach Remote" $s >/dev/null 2>&1
    exit 1
end

set -l tree ($AGTERMCTL zmx tree $host --json $sock 2>&1)
or fail "$host: $tree[-1]"
set tree (string join \n -- $tree)
set -l err (printf '%s' $tree | $JQ -r 'if .ok then empty else .error end' 2>/dev/null)
or fail "unreadable answer from $host"
test -z "$err"; or fail "$host: $err"

# flags and agent status live only in the far side's own tree; without them the
# picker still works, just unsorted and unmarked
set -l meta (ssh -n -o BatchMode=yes -o ConnectTimeout=5 $host /usr/local/bin/agtermctl tree --json 2>/dev/null \
    | $JQ -c '[.result.tree.workspaces[].sessions[] | {key: .id, value: {flagged: (.flagged // false), status: (.status // "")}}] | from_entries' 2>/dev/null)
test -n "$meta"; or set meta '{}'

set -l here ($AGTERMCTL tree --json $sock 2>/dev/null \
    | $JQ -c --arg h $host '[.result.tree.workspaces[].sessions[] | select(.remoteHost == $h) | {name, id}]' 2>/dev/null)
test -n "$here"; or set here '[]'

set -l rows (printf '%s' $tree | $JQ -c --argjson meta $meta --argjson here $here '
    [.result.remote.sessions[]
     | . as $s
     | ($meta[$s.id] // {}) as $m
     | {id, name,
        flagged: ($m.flagged // false),
        status: ($m.status // ""),
        here: ([$here[] | select(.name == $s.name) | .id] | first // ""),
        where: ($s.windowName + "/" + $s.workspaceName),
        context: ($s.context // ""),
        cwd: (($s.cwd // "") | sub("^/Users/[^/]+"; "~")),
        running: ([$s.panes[].foreground // empty | select(length > 0) | .[0] | split("/") | last] | join(" | "))}]
    | sort_by((if .flagged then 0 else 1 end), .where, .name)' | string collect)
test -n "$rows"; or fail "unreadable session list from $host"

set -l total (printf '%s' $rows | $JQ 'length')
test "$total" -gt 0; or fail "nothing to attach on $host (is it in Live sessions mode?)"

if test $flagged_only -eq 1
    set -l ids (printf '%s' $rows | $JQ -r '.[] | select(.flagged and .here == "") | .id')
    test (count $ids) -gt 0; or fail "no flagged session on $host left to attach"
    set -l ok 0
    for id in $ids
        $AGTERMCTL zmx attach $host $id --window (test -n "$AGT_WINDOW_ID"; and echo $AGT_WINDOW_ID; or echo active) $sock >/dev/null 2>&1
        and set ok (math $ok + 1)
    end
    $AGTERMCTL notify "attached $ok of "(count $ids)" flagged sessions from $host" --title "Attach Remote" $sock >/dev/null 2>&1
    exit 0
end

set -l items (printf '%s' $rows | $JQ -c '
    map({id: (if .here != "" then "here:" + .here else .id end),
         label: ((if .flagged then "⚑ " else "" end) + .name
                 + (if .status == "blocked" then "  · needs input"
                    elif .status == "active" then "  · working" else "" end)),
         subtitle: ([(if .here != "" then "already here, Enter jumps to it" else empty end),
                     .where, .context, .cwd, .running]
                    | map(select(. != "")) | join("  ·  "))})' | string collect)

set -l choice (printf '%s' $items | $AGTERMCTL pick --prompt "attach from $host" \
    --window (test -n "$AGT_WINDOW_ID"; and echo $AGT_WINDOW_ID; or echo active) $sock)
set -l rc $status
switch $rc
    case 0
    case 2
        exit 0
    case '*'
        fail "picker failed (exit $rc)"
end

set -l id (printf '%s' $choice | $JQ -r 'select(.result == "picked") | .id' 2>/dev/null)
test -n "$id"; or exit 0

# a session already attached here is selected rather than attached a second time
if string match -q 'here:*' -- $id
    $AGTERMCTL session select --target (string replace 'here:' '' -- $id) $sock >/dev/null 2>&1
    or fail "could not select the attached row"
    exit 0
end

# the attach resolves the far side again, so a session gone since the listing fails
# here instead of opening a fresh shell under its name
set -l out ($AGTERMCTL zmx attach $host $id $sock 2>&1)
or fail "attach failed: $out[-1]"
