#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract data from JSON
model_name=$(echo "$input" | jq -r '.model.display_name')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')

# Get git branch info (skip locks for safety)
cd "$current_dir" 2>/dev/null || cd "$(echo "$input" | jq -r '.cwd')" 2>/dev/null || true

branch=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
fi

# Get directory name (basename of current directory)
dir_name=$(basename "$current_dir")

# Get current date and time with dot separator
current_date=$(date "+%b %d")
current_time=$(date "+%H:%M")
current_datetime="${current_date} • ${current_time}"

# Flexoki color palette (dark theme 400 values)
FX_CYAN="\033[38;2;58;169;159m"     # #3AA99F
FX_YELLOW="\033[38;2;208;162;21m"   # #D0A215
FX_ORANGE="\033[38;2;218;112;44m"   # #DA702C
FX_RED="\033[38;2;209;77;65m"       # #D14D41
FX_GREEN="\033[38;2;135;154;57m"    # #879A39
FX_BLUE="\033[38;2;67;133;190m"     # #4385BE
FX_PURPLE="\033[38;2;139;126;200m"  # #8B7EC8

# UI colors
GRAY="\033[38;2;128;128;128m"
WHITE="\033[37m"
BG_FILLED="\033[48;5;240m"
BG_EMPTY="\033[48;5;236m"
RESET="\033[0m"

# Get context info from API (used_percentage is pre-calculated by Claude)
max_ctx=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

context_percent=""
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
    context_percent=$(printf "%.0f" "$used_pct" 2>/dev/null || echo "$used_pct")
    [ "$context_percent" -gt 100 ] 2>/dev/null && context_percent=100
fi

# Build the statusline: "Date | ▓▓▓░░░░░░░ 30% | Model in Dir on branch ~ files"
printf "${GRAY}%s${RESET}" "$current_datetime"

if [ -n "$context_percent" ]; then
    filled=$((context_percent / 5))
    empty=$((20 - filled))
    filled_bar=""
    empty_bar=""
    for i in $(seq 1 $filled); do filled_bar="${filled_bar} "; done
    for i in $(seq 1 $empty); do empty_bar="${empty_bar} "; done

    used_k=$(( max_ctx * context_percent / 100 / 1000 ))
    max_k=$(( max_ctx / 1000 ))

    if [ "$context_percent" -gt 60 ]; then
        CTX_COLOR="$FX_RED"
    elif [ "$context_percent" -gt 40 ]; then
        CTX_COLOR="$FX_ORANGE"
    else
        CTX_COLOR="$FX_CYAN"
    fi

    printf " ${WHITE}|${RESET} ${BG_FILLED}%s${RESET}${BG_EMPTY}%s${RESET} ${CTX_COLOR}%dk${RESET}${GRAY}/${RESET}${FX_CYAN}%dk${RESET} ${GRAY}(${RESET}${CTX_COLOR}%d%%${RESET} ${GRAY}used)${RESET}" "$filled_bar" "$empty_bar" "$used_k" "$max_k" "$context_percent"
fi

printf " ${WHITE}|${RESET} ${FX_GREEN}%s${RESET} ${GRAY}in${RESET} ${FX_BLUE}%s${RESET}" "$model_name" "$dir_name"

if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
    printf " ${GRAY}on${RESET} ${FX_PURPLE}%s${RESET}" "$branch"
fi