#!/bin/bash
[ -z "$WEZTERM_PANE" ] && exit 0
rm -f "$HOME/.local/state/wezterm-status/$WEZTERM_PANE"
