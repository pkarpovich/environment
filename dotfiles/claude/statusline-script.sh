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

# Get current date and time with dot separator
current_date=$(date "+%b %d")
current_time=$(date "+%H:%M")
current_datetime="${current_date} • ${current_time}"

# Color codes
GREEN="\033[32m"    # Model name
CYAN="\033[36m"     # Directory
YELLOW="\033[33m"   # Branch
GRAY="\033[37m"     # Date/Time (dim)
WHITE="\033[37m"    # Separator
BG_FILLED="\033[48;5;240m"  # Lighter gray for filled part
BG_EMPTY="\033[48;5;236m"   # Darker gray for empty part
RESET="\033[0m"

# Calculate context usage progress bar first
context_percent=""
if [ -n "$CLAUDE_CONTEXT_USED_PERCENT" ]; then
    context_percent="$CLAUDE_CONTEXT_USED_PERCENT"
elif [ -n "$CLAUDE_CONTEXT_TOKENS_USED" ] && [ -n "$CLAUDE_CONTEXT_TOKENS_MAX" ] && [ "$CLAUDE_CONTEXT_TOKENS_MAX" -gt 0 ]; then
    context_percent=$((CLAUDE_CONTEXT_TOKENS_USED * 100 / CLAUDE_CONTEXT_TOKENS_MAX))
else
    usage=$(echo "$input" | jq '.context_window.current_usage')
    if [ "$usage" != "null" ]; then
        current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
        size=$(echo "$input" | jq '.context_window.context_window_size')
        if [ "$size" -gt 0 ]; then
            context_percent=$((current * 100 / size))
        fi
    fi
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
    printf " ${WHITE}|${RESET} ${BG_FILLED}%s${RESET}${BG_EMPTY}%s${RESET} ${GRAY}%d%%${RESET}" "$filled_bar" "$empty_bar" "$context_percent"
fi

printf " ${WHITE}|${RESET} ${GREEN}%s${RESET} in ${CYAN}%s${RESET}" "$model_name" "$dir_name"

if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
    printf " on ${YELLOW}%s${RESET}" "$branch"

    if [ -n "$changed_files_count" ] && [ "$changed_files_count" -gt 0 ]; then
        printf " ${YELLOW}~ %s files${RESET}" "$changed_files_count"
    fi
fi