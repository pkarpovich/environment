#!/bin/bash
# @tuna.name New Google Meet
# @tuna.subtitle Start a new Google Meet and copy its link
# @tuna.mode inline

# Opens an instant meeting (meet.google.com/new) in Dia - the browser where you
# are signed in to Google - waits for the redirect to resolve to the room URL,
# copies that link to the clipboard, and shows it in a notification.
#
# Reading the URL back uses AppleScript (Dia exposes active tab -> URL). When run
# from tuna the first time, macOS asks "Tuna wants to control Dia" (Automation) -
# allow it once. tuna can request this (it has an AppleEvents usage string).

BROWSER_ID="company.thebrowser.dia"
BROWSER_APP="Dia"

open -b "$BROWSER_ID" "https://meet.google.com/new"

URL=""
for _ in $(seq 1 40); do
  sleep 0.5
  CUR=$(osascript -e "tell application \"$BROWSER_APP\" to get URL of active tab of front window" 2>/dev/null)
  URL=$(printf '%s' "$CUR" | grep -oE 'https://meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}' | head -1)
  [ -n "$URL" ] && break
  URL=""
done

if [ -n "$URL" ]; then
  printf '%s' "$URL" | pbcopy
  osascript -e "display notification \"$URL\" with title \"Google Meet - link copied\""
else
  osascript -e 'display notification "Opened a new Meet, but could not read the link (signed in to Google in Dia?)" with title "New Google Meet"'
fi
