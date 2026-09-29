#!/bin/bash
# Read Claude Code notification payload from stdin and display via osascript.

input=$(cat)
message=$(echo "$input" | jq -c '.message // "Claude Code"')
title=$(echo "$input" | jq -c '.title // "Claude Code"')

osascript -e "display notification ${message} with title ${title} sound name \"Glass\""
