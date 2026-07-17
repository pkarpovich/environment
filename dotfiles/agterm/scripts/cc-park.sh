#!/bin/sh
# Kill interactive Claude TUIs on one side of the MBP<->zellij pair (single-client model):
#   agterm - claudes whose ancestry includes the agterm app
#   zellij - claudes whose ancestry includes a zellij server
# Only interactive TUIs match (argv has --enable-auto-mode) - ralphex/headless runs untouched.
# macOS forbids reading other processes' env, so side detection walks the parent chain.
# CC_PARK_DRYRUN=1 prints matching pids instead of killing.
side="$1"
case "$side" in
  agterm|zellij) ;;
  *) echo "usage: cc-park.sh agterm|zellij" >&2; exit 1 ;;
esac

side_of() {
  p="$1"
  while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null; do
    cmd=$(ps -o command= -p "$p" 2>/dev/null)
    case "$cmd" in
      *zellij*--server*) echo zellij; return ;;
      *agterm.app/Contents/MacOS/agterm*) echo agterm; return ;;
    esac
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  done
  echo none
}

for pid in $(pgrep -f -- '--enable-auto-mode' 2>/dev/null); do
  [ "$(side_of "$pid")" = "$side" ] || continue
  if [ -n "$CC_PARK_DRYRUN" ]; then
    echo "$pid"
  else
    kill "$pid" 2>/dev/null
  fi
done
exit 0
