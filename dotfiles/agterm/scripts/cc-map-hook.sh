#!/bin/bash
# Claude Code SessionStart hook: record which conversation lives in which agterm
# session. One file per agterm session (atomic mv - no races), consumed by
# ccz (zellij tabs on the second Mac) and reopen-cc.sh.
JQ=/opt/homebrew/bin/jq

[ -n "$AGTERM_SESSION_ID" ] || exit 0
[ "$AGTERM_PANE" = "left" ] || exit 0

input=$(cat)
conv=$(printf '%s' "$input" | "$JQ" -r '.session_id // empty')
cwd=$(printf '%s' "$input" | "$JQ" -r '.cwd // empty')
[ -n "$conv" ] || exit 0

profile=personal
case "$CLAUDE_CONFIG_DIR" in *claude-work*) profile=work ;; esac

dir="$HOME/.local/state/agterm/cc-map"
mkdir -p "$dir"
tmp=$(mktemp "$dir/.tmp.XXXXXX") || exit 0
"$JQ" -n --arg conv "$conv" --arg profile "$profile" --arg cwd "$cwd" \
    '{conv: $conv, profile: $profile, cwd: $cwd, ts: (now | floor)}' > "$tmp"
mv -f "$tmp" "$dir/$AGTERM_SESSION_ID"
