#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract data from JSON
model_name=$(echo "$input" | jq -r '.model.display_name')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')

# Get git branch info (skip locks for safety)
cd "$current_dir" 2>/dev/null || cd "$(echo "$input" | jq -r '.cwd')" 2>/dev/null || true

branch=""
changed_files_count=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # Get current branch, skipping optional locks
    branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")

    # Count changed files (modified, added, deleted)
    changed_files_count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
fi

# Get directory name (basename of current directory)
dir_name=$(basename "$current_dir")

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
RESET="\033[0m"

# Get context info from API (used_percentage is pre-calculated by Claude)
max_ctx=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

context_percent=""
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
    context_percent=$(printf "%.0f" "$used_pct" 2>/dev/null || echo "$used_pct")
    [ "$context_percent" -gt 100 ] 2>/dev/null && context_percent=100
fi

weekly_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
weekly_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
fivehour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
fivehour_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

sep=""
if [ -n "$context_percent" ]; then
    used_k=$(( max_ctx * context_percent / 100 / 1000 ))
    max_k=$(( max_ctx / 1000 ))

    if [ "$context_percent" -gt 80 ]; then
        CTX_COLOR="$FX_RED"
    elif [ "$context_percent" -gt 60 ]; then
        CTX_COLOR="$FX_ORANGE"
    elif [ "$context_percent" -gt 40 ]; then
        CTX_COLOR="$FX_YELLOW"
    elif [ "$context_percent" -gt 20 ]; then
        CTX_COLOR="$FX_CYAN"
    else
        CTX_COLOR="$FX_GREEN"
    fi

    printf "${CTX_COLOR}%dk${RESET}${GRAY}/${RESET}${FX_CYAN}%dk${RESET} ${GRAY}(${RESET}${CTX_COLOR}%d%%${RESET} ${GRAY}used)${RESET}" "$used_k" "$max_k" "$context_percent"
    sep=" ${WHITE}|${RESET} "
fi

if [ -n "$weekly_pct" ] && [ -n "$weekly_reset" ]; then
    weekly_pct_int=$(printf "%.0f" "$weekly_pct" 2>/dev/null || echo "$weekly_pct")
    now=$(date +%s)
    delta=$((weekly_reset - now))
    [ "$delta" -lt 0 ] && delta=0
    days=$((delta / 86400))
    hours=$(((delta % 86400) / 3600))
    mins=$(((delta % 3600) / 60))
    if [ "$days" -gt 0 ]; then
        time_left="${days}d${hours}h"
    elif [ "$hours" -gt 0 ]; then
        time_left="${hours}h${mins}m"
    else
        time_left="${mins}m"
    fi

    if [ "$weekly_pct_int" -gt 80 ]; then
        WK_COLOR="$FX_RED"
    elif [ "$weekly_pct_int" -gt 60 ]; then
        WK_COLOR="$FX_ORANGE"
    elif [ "$weekly_pct_int" -gt 40 ]; then
        WK_COLOR="$FX_YELLOW"
    elif [ "$weekly_pct_int" -gt 20 ]; then
        WK_COLOR="$FX_CYAN"
    else
        WK_COLOR="$FX_GREEN"
    fi

    printf "${sep}${GRAY}wk${RESET} ${WK_COLOR}%s${RESET} ${GRAY}·${RESET} ${WK_COLOR}%d%%${RESET}" "$time_left" "$weekly_pct_int"

    week_seconds=604800
    elapsed=$((week_seconds - delta))
    ideal_pct=$((elapsed * 100 / week_seconds))
    pace_delta=$((weekly_pct_int - ideal_pct))

    if [ "$pace_delta" -gt 5 ]; then
        printf " ${FX_RED}↑%d%%${RESET}" "$pace_delta"
    elif [ "$pace_delta" -lt -5 ]; then
        abs_pace=$(( -pace_delta ))
        printf " ${FX_GREEN}↓%d%%${RESET}" "$abs_pace"
    fi

    sep=" ${WHITE}|${RESET} "
fi

if [ -n "$fivehour_pct" ] && [ -n "$fivehour_reset" ]; then
    fivehour_pct_int=$(printf "%.0f" "$fivehour_pct" 2>/dev/null || echo "$fivehour_pct")
    if [ "$fivehour_pct_int" -ge 80 ]; then
        now5=$(date +%s)
        delta5=$((fivehour_reset - now5))
        [ "$delta5" -lt 0 ] && delta5=0
        h5=$((delta5 / 3600))
        m5=$(((delta5 % 3600) / 60))
        if [ "$h5" -gt 0 ]; then
            time5="${h5}h${m5}m"
        else
            time5="${m5}m"
        fi
        printf "${sep}${GRAY}5h${RESET} ${FX_RED}%s${RESET} ${GRAY}·${RESET} ${FX_RED}%d%%${RESET}" "$time5" "$fivehour_pct_int"
        sep=" ${WHITE}|${RESET} "
    fi
fi

printf "${sep}${FX_GREEN}%s${RESET} ${GRAY}in${RESET} ${FX_BLUE}%s${RESET}" "$model_name" "$dir_name"

if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
    printf " ${GRAY}on${RESET} ${FX_PURPLE}%s${RESET}" "$branch"

    if [ -n "$changed_files_count" ] && [ "$changed_files_count" -gt 0 ]; then
        printf " ${FX_ORANGE}~%s${RESET}" "$changed_files_count"
    fi
fi