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
    # Get current branch, skipping optional locks
    branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
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
RESET="\033[0m"

# Build the statusline: "Date/Time | Model in Directory on Branch"
printf "${GRAY}%s${RESET} ${WHITE}|${RESET} ${GREEN}%s${RESET} in ${CYAN}%s${RESET}" "$current_datetime" "$model_name" "$dir_name"

if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
    printf " on ${YELLOW}%s${RESET}" "$branch"
fi