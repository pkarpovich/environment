#!/bin/bash
# @tuna.name Join Next Meeting
# @tuna.subtitle Open the video link for a meeting around now (+/- 30 min)
# @tuna.mode inline

# Opens the join link of the meeting whose START is within +/- 30 minutes of now
# (so you can join a few minutes early, or up to ~30 min late). Among those it
# picks the earliest one that has a link. Matches Google Meet / Zoom / Teams
# (classic + new) join URLs only - a dial-in tel: number is never opened.
#
# Needs the launching app (tuna or a terminal) to hold Calendar access, since
# icalBuddy's read is attributed to that responsible process.

if [ -x /opt/homebrew/bin/icalBuddy ]; then
  ICAL=/opt/homebrew/bin/icalBuddy
else
  ICAL=/usr/local/bin/icalBuddy
fi

RAW=$("$ICAL" -nc -npn -nrd -b "@@EVT@@ " -df "%Y-%m-%d" -tf "%H:%M" \
  -iep "datetime,title,url,notes" -nnr " " eventsToday+1 2>&1)

URL=$(printf '%s' "$RAW" | python3 -c '
import sys, re, time, datetime
raw = sys.stdin.read()
now = time.time()
WINDOW = 30 * 60
meeting = re.compile(r"https://meet\.google\.com/[a-zA-Z0-9-]+|https://[a-zA-Z0-9.-]+\.zoom\.us/j/[0-9][^\s>\"]*|https://teams\.microsoft\.com/(?:l/meetup-join|meet)/[^\s>\"]+|https://teams\.live\.com/meet/[^\s>\"]+")
dt = re.compile(r"(\d{4}-\d{2}-\d{2}) (?:at )?(\d{2}:\d{2})")
best = None
for block in raw.split("@@EVT@@"):
    m = dt.search(block)
    if not m:
        continue
    try:
        start = time.mktime(datetime.datetime.strptime(m.group(1) + " " + m.group(2), "%Y-%m-%d %H:%M").timetuple())
    except Exception:
        continue
    if abs(start - now) > WINDOW:
        continue
    u = meeting.search(block)
    if not u:
        continue
    if best is None or start < best[0]:
        best = (start, u.group(0))
if best:
    print(best[1])
')

if [ -n "$URL" ]; then
  open "$URL"
else
  osascript -e 'display notification "No meeting around now (+/- 30 min)" with title "Join Next Meeting"'
fi
