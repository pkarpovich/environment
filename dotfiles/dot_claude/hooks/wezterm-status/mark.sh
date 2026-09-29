#!/bin/bash
[ -z "$WEZTERM_PANE" ] && exit 0
[ -z "$1" ] && exit 0

dir="$HOME/.local/state/wezterm-status"
mkdir -p "$dir"
printf '{"type":"%s"}' "$1" > "$dir/$WEZTERM_PANE.tmp"
mv "$dir/$WEZTERM_PANE.tmp" "$dir/$WEZTERM_PANE"
