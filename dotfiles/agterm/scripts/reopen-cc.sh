#!/bin/bash
# Bring Claude conversations home to agterm (single-client model): kill zellij-side
# tab claudes and stale agterm TUIs, then resume each mapped session's conversation
# in its agterm session. With an argument - only that session (id or prefix), and
# nothing is killed (the session must be idle at its prompt).
AGTERMCTL=/opt/homebrew/bin/agtermctl
JQ=/opt/homebrew/bin/jq
MAP="$HOME/.local/state/agterm/cc-map"
PARK="$HOME/.config/agterm/scripts/cc-park.sh"

if [ -z "$1" ]; then
  "$PARK" zellij
  "$PARK" agterm
fi

sids=$("$AGTERMCTL" tree --json | "$JQ" -r '[.result.tree.workspaces[].sessions[]] | .[].id')
for id in $sids; do
  entry="$MAP/$id"
  [ -f "$entry" ] || continue
  if [ -n "$1" ]; then
    want=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]')" in
      "$want"*) ;;
      *) continue ;;
    esac
  fi

  ok=""
  for _ in $(seq 20); do
    fg=$("$AGTERMCTL" tree --json | "$JQ" -r --arg id "$id" \
      '[.result.tree.workspaces[].sessions[]] | .[] | select(.id==$id) | (.foreground // []) | join(" ")')
    if [ -z "$fg" ]; then ok=1; break; fi
    sleep 0.25
  done
  if [ -z "$ok" ]; then
    "$AGTERMCTL" notify "reopen-cc: session $id busy, skipped" --title "reopen-cc"
    continue
  fi

  conv=$("$JQ" -r '.conv // empty' "$entry")
  [ -n "$conv" ] || continue
  cmd="CLAUDE_CODE_NO_FLICKER=1 claude --enable-auto-mode --resume $conv"
  [ "$("$JQ" -r '.profile // "personal"' "$entry")" = "work" ] && cmd="CLAUDE_CONFIG_DIR=~/.claude-work $cmd"
  printf '%s\n' "$cmd" | "$AGTERMCTL" session type --stdin --target "$id"
done
