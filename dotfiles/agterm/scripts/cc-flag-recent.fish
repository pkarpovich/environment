#!/opt/homebrew/bin/fish
# @agt.name Flag the sessions Claude answered in the last 24h
# @agt.desc clear every flag, then flag each session whose conversation has an assistant message newer than a day
#
# The flagged view becomes "what moved recently" instead of a list that only
# grows. agterm itself keeps no message times - statusChangedAt lives only while
# a glyph is up - so the time comes from the transcript: the cc-map entry ccm
# keeps per session names the conversation and profile, and the last record of
# type "assistant" in that .jsonl carries the timestamp. The file's mtime is not
# that signal: Claude appends bookkeeping records with no dialogue behind them.
#
# A session with no cc-map entry (no Claude in it, or a batch runner's) stays
# unflagged. Nothing else about a session changes.
set -l AGTERMCTL /opt/homebrew/bin/agtermctl
set -l JQ /opt/homebrew/bin/jq
set -l MAP ~/.local/state/agterm/cc-map
set -l WINDOW_S 86400

function fail --argument-names msg
    /opt/homebrew/bin/agtermctl notify $msg --title Flags >/dev/null 2>&1
    exit 1
end

set -l win active
test -n "$AGT_WINDOW_ID"; and set win $AGT_WINDOW_ID

set -l cutoff (math (date +%s) - $WINDOW_S)

set -l ids ($AGTERMCTL tree --json --window $win 2>/dev/null | $JQ -r '.result.tree.workspaces[].sessions[].id')
test (count $ids) -gt 0; or fail "no sessions in this window"

$AGTERMCTL session flag clear --window $win >/dev/null 2>&1; or fail "could not clear flags"

set -l flagged 0
for id in $ids
    set -l entry $MAP/$id
    test -f $entry; or continue

    set -l conv ($JQ -r '.conv // empty' $entry)
    test -n "$conv"; or continue
    set -l root ~/.claude
    test ($JQ -r '.profile // empty' $entry) = work; and set root ~/.claude-work

    set -l transcript $root/projects/*/$conv.jsonl
    test -f "$transcript[1]"; or continue

    # the last assistant record sits within the final few hundred KB even behind
    # a large tool result, and reading the whole file would cost seconds on the
    # 90 MB ones
    set -l stamp (tail -c 400000 $transcript[1] | grep '"type":"assistant"' | tail -1 | $JQ -r '.timestamp // empty')
    test -n "$stamp"; or continue

    set -l epoch (date -j -u -f '%Y-%m-%dT%H:%M:%S' (string replace -r '\.\d+Z$' '' -- $stamp) +%s 2>/dev/null)
    test -n "$epoch"; or continue
    test $epoch -ge $cutoff; or continue

    $AGTERMCTL session flag on --target $id --window $win >/dev/null 2>&1; and set flagged (math $flagged + 1)
end

$AGTERMCTL notify "$flagged of "(count $ids)" sessions answered in the last 24h" --title Flags >/dev/null 2>&1
