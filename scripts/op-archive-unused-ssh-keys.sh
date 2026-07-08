#!/bin/bash
# Archive (not delete) the SSH Key items in 1Password you no longer use, so they
# stop showing up in op-export-ssh-keys.sh. `op item list` hides archived items
# by default, and Archive is fully recoverable in 1Password - this is not a delete.
#
# Run in YOUR OWN terminal - op needs the 1Password desktop prompt.
# DRY-RUN by default (prints what it WOULD archive). Pass --apply to do it.
#
# KEEP = the keys you actively use, matched by the SAME name-sanitization as
# op-export-ssh-keys.sh. Edit this list when your active set changes.

set -euo pipefail

OP=/opt/homebrew/bin/op
JQ=/opt/homebrew/bin/jq

KEEP=(
  github-mbp16
  pi-home
  lasso
  launchpad
  tuclaw-rpi
  github-signing
  mbp16-incoming      # incoming: lets the Air SSH into this Mac (lives in authorized_keys, not ssh config)
)

apply=0
[ "${1:-}" = "--apply" ] && apply=1

sanitize() { printf '%s' "$1" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-'; }

in_keep() {
  local n="$1" k
  for k in "${KEEP[@]}"; do [ "$k" = "$n" ] && return 0; done
  return 1
}

items=$("$OP" item list --categories "SSH Key" --format=json) || {
  echo "Could not list SSH keys - unlock 1Password and enable the CLI integration." >&2
  exit 1
}

if [ "$apply" -eq 1 ]; then
  echo "MODE: APPLY - will archive non-kept keys"
else
  echo "MODE: dry-run - nothing changes; pass --apply to archive"
fi
echo

printf '%s' "$items" | "$JQ" -r '.[] | "\(.id)\t\(.title)"' \
| while IFS=$'\t' read -r id title; do
  name=$(sanitize "$title")
  if in_keep "$name"; then
    echo "keep           $title"
    continue
  fi
  if [ "$apply" -eq 1 ]; then
    if "$OP" item delete "$id" --archive >/dev/null 2>&1; then
      echo "archived       $title"
    else
      echo "FAIL           $title" >&2
    fi
  else
    echo "would-archive  $title"
  fi
done
