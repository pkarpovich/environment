#!/bin/bash

# The session that runs this keeps the PATH of the shell it was launched from, which can
# predate the shell config: jq then goes missing and the line comes out empty.
PATH="/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/bin:$PATH"

# Read JSON input from stdin
input=$(cat)

# Extract data from JSON
model_name=$(echo "$input" | jq -r '.model.display_name')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
effort=$(echo "$input" | jq -r '.effort.level // empty')

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

# Monthly usage credits, for an account without plan windows (no rate_limits in the
# payload): the same source /usage reads, cached and refreshed in the background so
# the line never waits for the network. The pace counts working days, Mon-Fri.
CREDITS_CACHE="${XDG_STATE_HOME:-$HOME/.local/state}/claude/usage-credits.json"
CREDITS_TTL=300
has_rate_limits=$(echo "$input" | jq -r '.rate_limits != null')
cc_version=$(echo "$input" | jq -r '.version // empty')

refresh_credits() {
    local token
    if [ -r "$HOME/.claude/.credentials.json" ]; then
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json")
    else
        token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty')
    fi
    [ -n "$token" ] || return
    mkdir -p "$(dirname "$CREDITS_CACHE")"
    touch "$CREDITS_CACHE"
    printf 'Authorization: Bearer %s\n' "$token" \
        | curl -sf --max-time 5 -H @- \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-code/$cc_version" \
            https://api.anthropic.com/api/oauth/usage \
        | jq -ce '.extra_usage | select(.is_enabled == true) | {used: .used_credits, limit: .monthly_limit}' \
        > "$CREDITS_CACHE.$$" 2>/dev/null && mv -f "$CREDITS_CACHE.$$" "$CREDITS_CACHE"
    rm -f "$CREDITS_CACHE.$$"
}

if [ "$has_rate_limits" = "false" ] && [ -n "$cc_version" ]; then
    cache_age=$(( $(date +%s) - $(stat -c %Y "$CREDITS_CACHE" 2>/dev/null || stat -f %m "$CREDITS_CACHE" 2>/dev/null || echo 0) ))
    [ "$cache_age" -ge "$CREDITS_TTL" ] && refresh_credits >/dev/null 2>&1 &
    if [ -s "$CREDITS_CACHE" ]; then
        read -r used_c limit_c <<< "$(jq -r '"\(.used) \(.limit)"' "$CREDITS_CACHE" 2>/dev/null)"
    fi
    if [ -n "${limit_c:-}" ] && [ "$limit_c" != "null" ] && [ "${limit_c%.*}" -gt 0 ]; then
        used_pct=$(( ${used_c%.*} * 100 / ${limit_c%.*} ))
        read -r wd_done wd_total <<< "$(jq -nr '
            (now | gmtime) as $t | $t[0] as $y | $t[1] as $m | $t[2] as $d
            | ([ $y, $m + 1, 1, 0, 0, 0, 0, 0 ] | mktime) - 86400 | gmtime[2] as $dim
            | [range(1; $dim + 1) | select(([ $y, $m, ., 0, 0, 0, 0, 0 ] | mktime | strftime("%u") | tonumber) <= 5)]
            | "\([.[] | select(. <= $d)] | length) \(length)"')"
        wd_left=$(( wd_total - wd_done ))
        ideal_pct=$(( wd_done * 100 / wd_total ))

        if [ "$used_pct" -gt 80 ]; then
            MO_COLOR="$FX_RED"
        elif [ "$used_pct" -gt 60 ]; then
            MO_COLOR="$FX_ORANGE"
        elif [ "$used_pct" -gt 40 ]; then
            MO_COLOR="$FX_YELLOW"
        elif [ "$used_pct" -gt 20 ]; then
            MO_COLOR="$FX_CYAN"
        else
            MO_COLOR="$FX_GREEN"
        fi

        printf "${sep}${GRAY}mo${RESET} ${MO_COLOR}\$%d${RESET}${GRAY}/\$%d${RESET} ${GRAY}·${RESET} ${MO_COLOR}%d%%${RESET} ${GRAY}·${RESET} ${FX_BLUE}%dwd${RESET}" \
            "$(( ${used_c%.*} / 100 ))" "$(( ${limit_c%.*} / 100 ))" "$used_pct" "$wd_left"
        pace_badge $(( used_pct - ideal_pct ))
        sep=" ${WHITE}|${RESET} "
    fi
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