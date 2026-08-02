#!/opt/homebrew/bin/fish
# jump to the Nth session in sidebar order (workspaces flattened top-to-bottom)
set -l AGTERMCTL /opt/homebrew/bin/agtermctl
set -l JQ /opt/homebrew/bin/jq

set -l ids ($AGTERMCTL tree --json | $JQ -r '.result.tree.workspaces[].sessions[].id')
set -l n $argv[1]
test (count $ids) -ge "$n" 2>/dev/null; or exit 0
exec $AGTERMCTL session select --target $ids[$n]
