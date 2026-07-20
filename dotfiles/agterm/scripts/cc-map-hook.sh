#!/bin/bash
# Claude Code SessionStart hook: record which conversation lives in which agterm
# session. One file per agterm session (atomic mv - no races), consumed by
# ccz (zellij tabs on the second Mac) and reopen-cc.sh.
JQ=/opt/homebrew/bin/jq

[ -n "$AGTERM_SESSION_ID" ] || exit 0
[ "$AGTERM_PANE" = "left" ] || exit 0

# ignore claudes spawned by batch runners (ralphex): their per-iteration
# conversations must not overwrite the session's interactive one
p=$PPID
while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null; do
  cmd=$(ps -o command= -p "$p" 2>/dev/null)
  first=${cmd%% *}
  case "${first##*/}" in
    ralphex) exit 0 ;;
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

dir="$HOME/.local/state/agterm/cc-map"
mkdir -p "$dir"
tmp=$(mktemp "$dir/.tmp.XXXXXX") || exit 0
"$JQ" -n --arg conv "$conv" --arg profile "$profile" --arg cwd "$cwd" \
    '{conv: $conv, profile: $profile, cwd: $cwd, ts: (now | floor)}' > "$tmp"
mv -f "$tmp" "$dir/$AGTERM_SESSION_ID"
