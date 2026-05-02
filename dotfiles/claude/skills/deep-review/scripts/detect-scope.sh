#!/usr/bin/env bash
# detect-scope.sh - emit deep-review scope info as key=value lines
#
# Output fields (always present):
#   default_branch  detected default branch name
#   baseline        current HEAD sha
#   files           number of changed files in branch vs default
#   additions       inserted lines
#   deletions       deleted lines
#   empty           true|false  - no diff vs default
#   huge            true|false  - >100 files OR >5000 lines
#   dirty           true|false  - working tree has uncommitted changes
#
# Exit non-zero only if not in a git repo or default branch undetectable.

set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "error=not in a git repository" >&2
    exit 1
fi

default_branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' || true)
if [ -z "$default_branch" ]; then
    default_branch=$(git config --get init.defaultBranch 2>/dev/null || echo "")
fi
if [ -z "$default_branch" ]; then
    for name in main master; do
        if git rev-parse --verify "$name" >/dev/null 2>&1; then
            default_branch=$name
            break
        fi
    done
fi
if [ -z "$default_branch" ]; then
    echo "error=could not detect default branch" >&2
    exit 1
fi

baseline=$(git rev-parse HEAD)

range="${default_branch}...HEAD"
stats=$(git diff --shortstat "$range" 2>/dev/null || echo "")
files=$(echo "$stats"     | grep -oE '[0-9]+ file'      | grep -oE '[0-9]+' || true)
additions=$(echo "$stats" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || true)
deletions=$(echo "$stats" | grep -oE '[0-9]+ deletion'  | grep -oE '[0-9]+' || true)
files=${files:-0}
additions=${additions:-0}
deletions=${deletions:-0}

empty=false
[ "$files" -eq 0 ] && empty=true

huge=false
total_lines=$((additions + deletions))
if [ "$files" -gt 100 ] || [ "$total_lines" -gt 5000 ]; then
    huge=true
fi

dirty=false
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    dirty=true
fi

cat <<EOF
default_branch=$default_branch
baseline=$baseline
files=$files
additions=$additions
deletions=$deletions
empty=$empty
huge=$huge
dirty=$dirty
EOF
