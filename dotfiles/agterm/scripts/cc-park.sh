#!/bin/sh
# Kill interactive Claude TUIs on one side of the MBP<->tmux pair (single-client model):
#   agterm - claudes whose ancestry includes the agterm app
#   tmux   - claudes whose ancestry includes a tmux server
# Only interactive TUIs match (argv has --enable-auto-mode) - ralphex/headless runs untouched.
# macOS forbids reading other processes' env, so side detection walks the parent chain.
# With a second argument (an agterm session id) only that session's claude is parked,
# by the pid the cc-map hook recorded - the conversation id is NOT a reliable argv
# marker (a resumed claude rewrites its process title and drops it). A claude older
# than that hook has no recorded pid and is identified by working directory instead.
# CC_PARK_DRYRUN=1 prints matching pids instead of killing.
JQ=/opt/homebrew/bin/jq
AGTERMCTL=/opt/homebrew/bin/agtermctl
MAP="$HOME/.local/state/agterm/cc-map"
PARKED_COLOR=#8B7EC8
PARKED_SHAPE=diamond

side="$1"
target="$2"
case "$side" in
  agterm|tmux) ;;
  *) echo "usage: cc-park.sh agterm|tmux [session-id]" >&2; exit 1 ;;
esac

# macOS ps shows the tmux server under the argv that spawned it (`tmux
# new-session … claude --enable-auto-mode`), never as a "tmux: server" title
is_tmux() {
  case "$1" in
    tmux|"tmux "*|*"/tmux"|*"/tmux "*|"tmux: server"*) return 0 ;;
  esac
  return 1
}

side_of() {
  p="$1"
  while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null; do
    cmd=$(ps -o command= -p "$p" 2>/dev/null)
    if is_tmux "$cmd"; then echo tmux; return; fi
    case "$cmd" in
      *agterm.app/Contents/MacOS/agterm*) echo agterm; return ;;
    esac
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  done
  echo none
}

# -a: without it pgrep hides its own ancestors, so a park invoked from inside a
# Claude session would silently skip that very claude.
# The tmux server itself is dropped: a session started as `tmux new-session …
# claude --enable-auto-mode …` carries that argv, so the server matches both the
# pgrep filter and the *claude* one below - killing it would take down every
# session on that side instead of one client.
all_pids=""
for pid in $(pgrep -a -f -- '--enable-auto-mode' 2>/dev/null); do
  is_tmux "$(ps -o command= -p "$pid" 2>/dev/null)" && continue
  all_pids="$all_pids $pid"
done

if [ -z "$target" ]; then
  pids=$all_pids
else
  pids=$("$JQ" -r '.pid // empty' "$MAP/$target" 2>/dev/null)
  # the recorded pid is whichever claude ran the hook, i.e. the agterm-side one;
  # parking the tmux side of the same session falls through to the directory
  # match below
  [ -n "$pids" ] && [ "$(side_of "$pids")" != "$side" ] && pids=""
fi

if [ -n "$target" ] && [ -z "$pids" ]; then
  want=$("$JQ" -r '.cwd // empty' "$MAP/$target" 2>/dev/null)
  claimed=""
  for e in "$MAP"/*; do
    [ -f "$e" ] || continue
    [ "${e##*/}" = "$target" ] && continue
    p=$("$JQ" -r '.pid // empty' "$e" 2>/dev/null)
    [ -n "$p" ] && claimed="$claimed $p"
  done
  for pid in $all_pids; do
    case " $claimed " in *" $pid "*) continue ;; esac
    [ "$(side_of "$pid")" = "$side" ] || continue
    [ "$(/usr/sbin/lsof -a -d cwd -p "$pid" -Fn 2>/dev/null | sed -n 's/^n//p')" = "$want" ] || continue
    pids="$pids $pid"
  done
  set -- $pids
  if [ "$#" -gt 1 ]; then
    echo "cc-park: several unclaimed claudes in $want ($*) - open that session on the Mac once so the hook records its pid" >&2
    exit 1
  fi
  pids="$*"
  if [ -n "$pids" ] && [ -z "$CC_PARK_DRYRUN" ]; then
    tmp=$(mktemp "$MAP/.tmp.XXXXXX") &&
      "$JQ" --argjson p "$1" '.pid = $p' "$MAP/$target" > "$tmp" &&
      mv -f "$tmp" "$MAP/$target"
  fi
fi

killed=0
killed_pids=""
for pid in $pids; do
  case "$(ps -o command= -p "$pid" 2>/dev/null)" in
    *claude*) ;;
    *) continue ;;
  esac
  [ "$(side_of "$pid")" = "$side" ] || continue
  killed=$((killed + 1))
  killed_pids="$killed_pids $pid"
  if [ -n "$CC_PARK_DRYRUN" ]; then
    echo "$pid"
  else
    kill "$pid" 2>/dev/null
  fi
done

if [ -n "$target" ] && [ "$killed" -eq 0 ]; then
  echo "cc-park: no live claude for $target on the $side side" >&2
  exit 1
fi

# sticky restore pins would resurrect the killed claudes on the next agterm
# launch (e.g. a reboot while working from the MBA) - drop them; reopen-cc's
# resume re-pins each one via the SessionStart hook
if [ "$side" = "agterm" ] && [ -z "$CC_PARK_DRYRUN" ]; then
  if [ -n "$target" ]; then
    "$AGTERMCTL" session restore --clear --target "$target" >/dev/null 2>&1
  else
    for entry in "$MAP"/*; do
      [ -f "$entry" ] || continue
      "$AGTERMCTL" session restore --clear --target "${entry##*/}" >/dev/null 2>&1
    done
  fi

  # mark every parked row so the sidebar shows at a glance which conversations
  # moved to the MBA and need a reopen. The tint holds because nothing else sets
  # a status while the session sits at its shell - resuming the conversation
  # fires the agent-status hooks, which drop the override on their own
  for entry in "$MAP"/*; do
    [ -f "$entry" ] || continue
    id=${entry##*/}
    if [ -n "$target" ]; then
      [ "$id" = "$target" ] || continue
    else
      p=$("$JQ" -r '.pid // empty' "$entry" 2>/dev/null)
      [ -n "$p" ] || continue
      case " $killed_pids " in *" $p "*) ;; *) continue ;; esac
    fi
    "$AGTERMCTL" session status completed --color "$PARKED_COLOR" --shape "$PARKED_SHAPE" \
      --target "$id" >/dev/null 2>&1
  done
fi
exit 0
