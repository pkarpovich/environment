#!/opt/homebrew/bin/fish
# @agt.name Shelve this workspace
# @agt.desc write it to disk, park its Claudes and close it
# Put a finished project away: serialise the workspace this session belongs to
# (its sessions, their directories and what each one is running), park the Claude
# clients in it, and delete the workspace. ws-unshelve brings it back.
#
# Conversations come from cc-map, not from the running argv: a resumed Claude
# rewrites its process title and drops the conversation id, so a snapshot built
# from `foreground` alone would restore an empty session. Anything that is not a
# Claude keeps its foreground argv, which is enough to re-run a server or a tail.
# A session attached from another host (`zmx attach`) keeps only the host and the
# remote session id: its local cwd is HOME and its argv is agterm's own ssh line.
# The id comes from `zmx tree HOST`, matched by the daemon name in that argv, so
# two remote sessions with the same name cannot be confused.
set -l AGTERMCTL /opt/homebrew/bin/agtermctl
set -l JQ /opt/homebrew/bin/jq
set -l MAP ~/.local/state/agterm/cc-map
set -l SHELF ~/.local/state/agterm/shelved
set -l PARK ~/.config/agterm/scripts/cc-park.fish

function fail --argument-names msg
    /opt/homebrew/bin/agtermctl notify $msg --title Shelve >/dev/null 2>&1
    exit 1
end

set -l sid $AGT_SESSION_ID
test -n "$sid"; or fail "no session to resolve the workspace from"

set -l tree ($AGTERMCTL tree --json | string collect)
set -l ws (printf '%s' $tree | $JQ -r --arg id $sid '.result.tree.workspaces[] | select(.sessions[].id == $id) | .id' | head -1)
set -l ws_name (printf '%s' $tree | $JQ -r --arg id $sid '.result.tree.workspaces[] | select(.sessions[].id == $id) | .name' | head -1)
test -n "$ws"; or fail "this session belongs to no workspace"

# one JSON per session: what the sidebar showed, where it sat, and how to bring
# it back - a conversation id when cc-map knows one, the live argv otherwise
set -l sessions (printf '%s' $tree | $JQ -c --arg ws $ws '.result.tree.workspaces[] | select(.id == $ws) | .sessions[] | {id, name, cwd, foreground, remoteHost}')
test (count $sessions) -gt 0; or fail "workspace $ws_name has no sessions"

set -l items
for s in $sessions
    set -l id (printf '%s' $s | $JQ -r '.id')
    set -l host (printf '%s' $s | $JQ -r '.remoteHost // empty')
    if test -n "$host"
        set -l daemon (printf '%s' $s | $JQ -r '.foreground | join(" ") | capture("(?<d>agterm-[0-9a-f]{32})") | .d')
        set -l remote ($AGTERMCTL zmx tree $host --json | $JQ -r --arg d "$daemon" \
            '.result.remote.sessions[] | select(.panes[].daemon == $d) | {id, cwd}' | string collect)
        test -n "$remote"; or fail "$host no longer lists session "(printf '%s' $s | $JQ -r '.name')
        set -a items (printf '%s' $s | $JQ -c --arg host $host --argjson remote "$remote" \
            '{name, host: $host, remote_id: $remote.id, cwd: $remote.cwd}')
        continue
    end
    set -l entry $MAP/$id
    set -l conv ""
    if test -f $entry
        set conv ($JQ -r '.conv // empty' $entry)
    end
    set -a items (printf '%s' $s | $JQ -c --arg conv "$conv" \
        '{name, cwd, conv: (if $conv == "" then null else $conv end),
          foreground: (if (.foreground // []) | length > 0 then (.foreground | join(" ")) else null end)}')
end

mkdir -p $SHELF
set -l slug (string replace -ra '[^a-z0-9_.-]' '-' (string lower $ws_name))
set -l file $SHELF/$slug.json
printf '%s\n' $items | $JQ -s --arg name "$ws_name" --arg ts (date +%s) \
    '{workspace: $name, shelved_at: ($ts | tonumber), sessions: .}' > $file

# park each Claude first so it exits on its own terms rather than being torn
# down with the pane; this also clears the restore pins of sessions that are
# about to stop existing
for s in $sessions
    set -l id (printf '%s' $s | $JQ -r '.id')
    test -f $MAP/$id; and $PARK agterm $id >/dev/null 2>&1
end

$AGTERMCTL workspace delete --target $ws >/dev/null 2>&1
$AGTERMCTL notify "$ws_name shelved ("(count $items)" sessions)" --title Shelve >/dev/null 2>&1
