#!/bin/bash
# @tuna.name 1Password Copy
# @tuna.subtitle Fuzzy-pick a login and copy its password to the clipboard
# @tuna.mode inline

# Replicates how the Raycast 1Password extension works: it just shells out to the
# `op` CLI (op item list --format=json, then op read op://vault/item/field). Here
# we list logins, show a native fuzzy picker (choose - a Spotlight-like GUI that
# works from tuna without a terminal/TTY, unlike fzf), then copy the chosen
# item's password. Auth uses the 1Password desktop app integration (Touch ID).

OP=/opt/homebrew/bin/op
JQ=/opt/homebrew/bin/jq
CHOOSE=/opt/homebrew/bin/choose

LIST=$("$OP" item list --categories Login --format=json 2>/dev/null \
  | "$JQ" -r '.[] | "\(.title)\t\(.vault.id)/\(.id)"')

if [ -z "$LIST" ]; then
  osascript -e 'display notification "Could not list items - unlock 1Password and enable CLI integration" with title "1Password"'
  exit 0
fi

CHOSEN=$(printf '%s\n' "$LIST" | cut -f1 | "$CHOOSE")
[ -z "$CHOSEN" ] && exit 0

REF=$(printf '%s\n' "$LIST" | awk -F '\t' -v t="$CHOSEN" '$1 == t {print $2; exit}')
[ -z "$REF" ] && exit 0

PW=$("$OP" read "op://$REF/password" 2>/dev/null)
if [ -n "$PW" ]; then
  printf '%s' "$PW" | pbcopy
  osascript -e 'display notification "Password copied to clipboard" with title "1Password"'
else
  osascript -e 'display notification "No password field on that item" with title "1Password"'
fi
