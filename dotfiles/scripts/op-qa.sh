#!/bin/bash
# @tuna.name 1Password Quick Access
# @tuna.subtitle Open 1Password Quick Access
# @tuna.mode inline

# 1Password Quick Access can ONLY be opened by its global hotkey (no URL / CLI /
# AppleScript API). 1Password rejects modifier-less keys, so set the Quick Access
# shortcut to Control+Option+Command+\ and this sends that synthetic combo, so any
# launcher (tuna) can summon the real Quick Access overlay.
#
# Sending keys needs Accessibility for the calling app (tuna). Unlike Calendar,
# Accessibility IS grantable: System Settings > Privacy & Security > Accessibility
# > "+" > add Tuna (and enable). \ = key code 42.

osascript -e 'tell application "System Events" to key code 42 using {control down, option down, command down}'
