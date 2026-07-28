#!/bin/bash
# Claude Code SessionStart hook: record which conversation lives in which agterm
# session. One file per agterm session (atomic mv - no races), consumed by
# ccz (tmux windows on the second Mac) and reopen-cc.sh.
JQ=/opt/homebrew/bin/jq

[ -n "$AGTERM_SESSION_ID" ] || exit 0
[ "$AGTERM_PANE" = "left" ] || exit 0

# ignore claudes spawned by batch runners (ralphex): their per-iteration
# conversations must not overwrite the session's interactive one
p=$PPID
pid=""
while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null; do
  cmd=$(ps -o command= -p "$p" 2>/dev/null)
  first=${cmd%% *}
  case "${first##*/}" in
    ralphex) exit 0 ;;
    claude) [ -n "$pid" ] || pid=$p ;;
    agterm) break ;;
  esac
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
done

input=$(cat)
conv=$(printf '%s' "$input" | "$JQ" -r '.session_id // empty')
cwd=$(printf '%s' "$input" | "$JQ" -r '.cwd // empty')
[ -n "$conv" ] || exit 0

profile=personal
case "$CLAUDE_CONFIG_DIR" in *claude-work*) profile=work ;; esac

# a brand-new conversation (fresh --session-id run, or a --fork-session child
# before its first message) has no transcript on disk yet - mapping/pinning it
# would point restore and ccl at an id --resume cannot find. Skip here; the
# UserPromptSubmit/Stop registrations of this hook converge as soon as the
# transcript exists.
base="$HOME/.claude"
[ "$profile" = "work" ] && base="$HOME/.claude-work"
set -- "$base"/projects/*/"$conv".jsonl
[ -f "$1" ] || exit 0

dir="$HOME/.local/state/agterm/cc-map"
mkdir -p "$dir"
[ -n "$cwd" ] || cwd=$("$JQ" -r '.cwd // empty' "$dir/$AGTERM_SESSION_ID" 2>/dev/null)
tmp=$(mktemp "$dir/.tmp.XXXXXX") || exit 0
prev='{}'
[ -f "$dir/$AGTERM_SESSION_ID" ] && prev=$(cat "$dir/$AGTERM_SESSION_ID")
# merged, not rebuilt: ccz records which tmux window mirrors this session
# (tsession/twindow) and must survive a hook fire; a changed conversation drops it
printf '%s' "$prev" | "$JQ" --arg conv "$conv" --arg profile "$profile" --arg cwd "$cwd" --arg pid "$pid" \
    'if .conv == $conv then . else del(.tsession, .twindow) end
     | . + {conv: $conv, profile: $profile, cwd: $cwd, ts: (now | floor),
            pid: (if $pid == "" then null else ($pid | tonumber) end)}' > "$tmp"
mv -f "$tmp" "$dir/$AGTERM_SESSION_ID"

# pin the pane's restore command to the live conversation (agterm >= 0.16.0):
# a restart then resumes it directly, instead of replaying the captured argv -
# which uses the absolute binary path (bypassing the fish wrapper's
# --session-id flip) and re-runs --fork-session verbatim, minting a new
# conversation on every launch
cmd="CLAUDE_CODE_NO_FLICKER=1 claude --enable-auto-mode --resume $conv"
[ "$profile" = "work" ] && cmd="CLAUDE_CONFIG_DIR=~/.claude-work $cmd"
/opt/homebrew/bin/agtermctl session restore "$cmd" --target "$AGTERM_SESSION_ID" >/dev/null 2>&1
exit 0
