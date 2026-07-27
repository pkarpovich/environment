#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract data from JSON
model_name=$(echo "$input" | jq -r '.model.display_name')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
effort=$(echo "$input" | jq -r '.effort.level // empty')

# Which account this session belongs to. The transcript path carries the config
# dir, so it is right from the first render - rate_limits only appear after the
# first API call, and keying off them showed the API spend on a fresh
# subscription session until the first message.
profile=personal
case "$(echo "$input" | jq -r '.transcript_path // empty')" in
    */.claude-work/*) profile=work ;;
esac

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

# API-account monthly spend (ccusage, claude-only) - shown only on the API-billed
# account (no rate_limits in payload). Render reads a cache; ccusage runs detached.
SPEND_CAP=1000
SPEND_DATA_DIR="$HOME/.claude-work"
SPEND_CACHE="/tmp/cc-month-spend-claude"
SPEND_LOCK="/tmp/cc-month-spend-claude.lock"
SPEND_TTL=600
MISE_SHIMS="$HOME/.local/share/mise/shims"

# Count Mon-Fri among the first N days of a month whose 1st falls on weekday W1 (1=Mon..7=Sun)
count_wd() {
    local n="$1" w1="$2" full rem i wd c
    full=$((n / 7)); rem=$((n % 7)); c=$((full * 5)); i=0
    while [ "$i" -lt "$rem" ]; do
        wd=$(((w1 - 1 + i) % 7 + 1))
        [ "$wd" -le 5 ] && c=$((c + 1))
        i=$((i + 1))
    done
    echo "$c"
}

# Burn pace vs the ideal straight line: always shown, but gray within +/-5% so a
# small drift does not read as an alarm
pace_badge() {
    local d="$1" color arrow
    if [ "$d" -gt 5 ]; then
        color="$FX_RED"; arrow="↑"
    elif [ "$d" -lt -5 ]; then
        color="$FX_GREEN"; arrow="↓"
    elif [ "$d" -gt 0 ]; then
        color="$GRAY"; arrow="↑"
    elif [ "$d" -lt 0 ]; then
        color="$GRAY"; arrow="↓"
    else
        color="$GRAY"; arrow="="
    fi
    [ "$d" -lt 0 ] && d=$((-d))
    printf " ${color}%s%d%%${RESET}" "$arrow" "$d"
}

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

    pace_badge "$pace_delta"

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

# Monthly API spend - only on the API-billed account
if [ "$profile" = work ] && [ -d "$SPEND_DATA_DIR" ]; then
    now=$(date +%s)

    # Refresh the cache in the background if stale - never blocks the render
    refresh=1
    if [ -f "$SPEND_CACHE" ]; then
        mtime=$(stat -f %m "$SPEND_CACHE" 2>/dev/null || stat -c %Y "$SPEND_CACHE" 2>/dev/null || echo 0)
        [ $((now - mtime)) -lt "$SPEND_TTL" ] && refresh=0
    fi
    if [ "$refresh" -eq 1 ]; then
        if [ -d "$SPEND_LOCK" ]; then
            lmtime=$(stat -f %m "$SPEND_LOCK" 2>/dev/null || stat -c %Y "$SPEND_LOCK" 2>/dev/null || echo 0)
            [ $((now - lmtime)) -gt 300 ] && rmdir "$SPEND_LOCK" 2>/dev/null
        fi
        if mkdir "$SPEND_LOCK" 2>/dev/null; then
            (
                export PATH="$MISE_SHIMS:/opt/homebrew/bin:$PATH"
                cur=$(date +%Y-%m)
                tmp="${SPEND_CACHE}.tmp.$$"
                if CLAUDE_CONFIG_DIR="$SPEND_DATA_DIR" bunx ccusage monthly --json --offline 2>/dev/null \
                    | jq -r --arg m "$cur" '[.monthly[] | select(.period==$m) | .modelBreakdowns[] | select((.modelName // "") | ascii_downcase | test("claude")) | .cost] | add // 0' > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
                    mv "$tmp" "$SPEND_CACHE"
                fi
                rm -f "$tmp"
                rmdir "$SPEND_LOCK" 2>/dev/null
            ) >/dev/null 2>&1 </dev/null &
        fi
    fi

    # Display from cache (instant)
    if [ -f "$SPEND_CACHE" ]; then
        spent=$(cat "$SPEND_CACHE" 2>/dev/null)
        if [ -n "$spent" ]; then
            spent_int=$(printf "%.0f" "$spent" 2>/dev/null || echo 0)
            spend_pct=$((spent_int * 100 / SPEND_CAP))

            # Working-day pacing (Mon-Fri): days left + actual vs ideal burn
            dom=$((10#$(date +%d)))
            dim=$((10#$(date -v1d -v+1m -v-1d +%d)))
            w1=$(date -v1d +%u)
            elapsed_wd=$(count_wd "$dom" "$w1")
            total_wd=$(count_wd "$dim" "$w1")
            left_wd=$((total_wd - elapsed_wd))
            ideal_pct=$((elapsed_wd * 100 / total_wd))
            pace=$((spend_pct - ideal_pct))

            if [ "$spend_pct" -gt 80 ]; then
                SP_COLOR="$FX_RED"
            elif [ "$spend_pct" -gt 60 ]; then
                SP_COLOR="$FX_ORANGE"
            elif [ "$spend_pct" -gt 40 ]; then
                SP_COLOR="$FX_YELLOW"
            elif [ "$spend_pct" -gt 20 ]; then
                SP_COLOR="$FX_CYAN"
            else
                SP_COLOR="$FX_GREEN"
            fi

            printf "${sep}${GRAY}mo${RESET} ${SP_COLOR}\$%d${RESET}${GRAY}/\$%d${RESET} ${GRAY}(${RESET}${SP_COLOR}%d%%${RESET}${GRAY})${RESET} ${GRAY}·${RESET} ${GRAY}%dd${RESET}" "$spent_int" "$SPEND_CAP" "$spend_pct" "$left_wd"

            pace_badge "$pace"

            sep=" ${WHITE}|${RESET} "
        fi
    fi
fi

printf "${sep}${FX_GREEN}%s${RESET}" "$model_name"

if [ -n "$effort" ] && [ "$effort" != "null" ]; then
    case "$effort" in
        low)    EFF_COLOR="$FX_GREEN" ;;
        medium) EFF_COLOR="$FX_CYAN" ;;
        high)   EFF_COLOR="$FX_YELLOW" ;;
        xhigh)  EFF_COLOR="$FX_ORANGE" ;;
        max)    EFF_COLOR="$FX_RED" ;;
        *)      EFF_COLOR="$GRAY" ;;
    esac
    printf " ${GRAY}·${RESET} ${EFF_COLOR}%s${RESET}" "$effort"
fi

printf " ${GRAY}in${RESET} ${FX_BLUE}%s${RESET}" "$dir_name"

if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
    printf " ${GRAY}on${RESET} ${FX_PURPLE}%s${RESET}" "$branch"

    if [ -n "$changed_files_count" ] && [ "$changed_files_count" -gt 0 ]; then
        printf " ${FX_ORANGE}~%s${RESET}" "$changed_files_count"
    fi
fi