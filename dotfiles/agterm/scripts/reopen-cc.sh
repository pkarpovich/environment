#!/bin/bash
# Bring Claude conversations home to agterm (single-client model): kill tmux-side
# window claudes and stale agterm TUIs, then resume each mapped session's conversation
# in its agterm session. With an argument - only that session (id or prefix): just
# its own tmux-side claude is parked, the rest of both sides is left alone.
AGTERMCTL=/opt/homebrew/bin/agtermctl
JQ=/opt/homebrew/bin/jq
MAP="$HOME/.local/state/agterm/cc-map"
PARK="$HOME/.config/agterm/scripts/cc-park.sh"

if [ -z "$1" ]; then
  "$PARK" tmux
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
  # a mirrored conversation is still live in its tmux window; resuming it here
  # without parking that one first would put two clients on it
  [ -n "$1" ] && "$PARK" tmux "$id" >/dev/null 2>&1
  cmd="CLAUDE_CODE_NO_FLICKER=1 claude --enable-auto-mode --resume $conv"
  [ "$("$JQ" -r '.profile // "personal"' "$entry")" = "work" ] && cmd="CLAUDE_CONFIG_DIR=~/.claude-work $cmd"
  printf '%s\n' "$cmd" | "$AGTERMCTL" session type --stdin --target "$id"
  # drop the parked marker cc-park left on the row: the agent-status hooks only
  # fire from the first prompt onward, so a resumed session would keep it until
  # the next message
  "$AGTERMCTL" session status idle --target "$id" >/dev/null 2>&1
done
