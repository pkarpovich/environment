#!/opt/homebrew/bin/fish
# Claude Code SessionStart hook: record which conversation lives in which agterm
# session. One file per agterm session (atomic mv - no races), consumed by
# ccm (tmux windows on the second Mac) and reopen-cc.
set -l JQ /opt/homebrew/bin/jq
set -l MAP ~/.local/state/agterm/cc-map

test -n "$AGTERM_SESSION_ID"; or exit 0
test "$AGTERM_PANE" = left; or exit 0

# ignore claudes spawned by batch runners (ralphex): their per-iteration
# conversations must not overwrite the session's interactive one.
# fish has no $PPID, so the walk starts from this script's own parent
set -l p (ps -o ppid= -p $fish_pid 2>/dev/null | string trim)
set -l pid ""
while test -n "$p"; and test "$p" -gt 1 2>/dev/null
    set -l cmd (ps -o command= -p $p 2>/dev/null)
    # -- : a login shell's argv[0] starts with a dash (-/opt/homebrew/bin/fish),
    # which path would otherwise read as an option
    switch (path basename -- (string split -f1 ' ' -- $cmd))
        case ralphex
            exit 0
        case claude
            test -n "$pid"; or set pid $p
        case agterm
            break
    end
    set p (ps -o ppid= -p $p 2>/dev/null | string trim)
end

set -l input (cat | string collect)
set -l conv (printf '%s' $input | $JQ -r '.session_id // empty')
set -l cwd (printf '%s' $input | $JQ -r '.cwd // empty')
test -n "$conv"; or exit 0

set -l profile personal
string match -q '*claude-work*' -- "$CLAUDE_CONFIG_DIR"; and set profile work

# a brand-new conversation (fresh --session-id run, or a --fork-session child
# before its first message) has no transcript on disk yet - mapping/pinning it
# would point restore and ccl at an id --resume cannot find. Skip here; the
# UserPromptSubmit/Stop registrations of this hook converge as soon as the
# transcript exists.
set -l base ~/.claude
test $profile = work; and set base ~/.claude-work
set -l transcript $base/projects/*/$conv.jsonl
test (count $transcript) -gt 0; or exit 0

mkdir -p $MAP
set -l entry $MAP/$AGTERM_SESSION_ID
test -n "$cwd"; or set cwd ($JQ -r '.cwd // empty' $entry 2>/dev/null)

# merged, not rebuilt: ccm records which tmux window mirrors this session
# (tsession/twindow) and must survive a hook fire; a changed conversation drops it
set -l prev '{}'
test -f $entry; and set prev (cat $entry | string collect)
set -l tmp (mktemp $MAP/.tmp.XXXXXX)
and printf '%s' $prev | $JQ --arg conv $conv --arg profile $profile --arg cwd "$cwd" --arg pid "$pid" \
    'if .conv == $conv then . else del(.tsession, .twindow) end
     | . + {conv: $conv, profile: $profile, cwd: $cwd, ts: (now | floor),
            pid: (if $pid == "" then null else ($pid | tonumber) end)}' > $tmp
and mv -f $tmp $entry

# pin the pane's restore command to the live conversation (agterm >= 0.16.0):
# a restart then resumes it directly, instead of replaying the captured argv -
# which uses the absolute binary path (bypassing the fish wrapper's
# --session-id flip) and re-runs --fork-session verbatim, minting a new
# conversation on every launch
set -l cmd "CLAUDE_CODE_NO_FLICKER=1 claude --enable-auto-mode --resume $conv"
test $profile = work; and set cmd "CLAUDE_CONFIG_DIR=~/.claude-work $cmd"
/opt/homebrew/bin/agtermctl session restore "$cmd" --target $AGTERM_SESSION_ID >/dev/null 2>&1
exit 0
