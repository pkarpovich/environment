#!/bin/bash
# @tuna.name WhatsApp Strip
# @tuna.subtitle Drop the "[date, time] Name:" prefix from copied WhatsApp messages, clipboard in, clipboard out
# @tuna.mode inline

# A multi-message copy out of WhatsApp arrives as one line per message:
#   [08/09/2026, 4:54:59 AM] Stephen Gonzalez: i have a situation
# Only the text after the first ": " past the closing bracket is kept. A line
# without that prefix is a continuation of the previous message and passes
# through untouched, which is also why the whole thing is one sed call.

set -euo pipefail

notify() { osascript -e "display notification \"$1\" with title \"WhatsApp Strip\""; }

INPUT=$(pbpaste)
if [ -z "$INPUT" ]; then
  notify "Clipboard is empty"
  exit 0
fi

OUTPUT=$(printf '%s\n' "$INPUT" | sed -E 's/^\[[^]]*\] [^:]*: //')

if [ "$OUTPUT" = "$INPUT" ]; then
  notify "No WhatsApp prefixes found, clipboard left as is"
  exit 0
fi

printf '%s' "$OUTPUT" | pbcopy
notify "$(printf '%s\n' "$INPUT" | grep -c -E '^\[[^]]*\] [^:]*: ') messages stripped"
