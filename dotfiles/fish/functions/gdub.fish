function gdub --description "delete local branches whose upstream is gone (merged/deleted PRs)"
    git fetch --prune
    set -l gone (git branch -vv | grep ': gone]' | grep -v '^\*' | awk '{print $1}')
    if test (count $gone) -eq 0
        echo "No branches with gone upstream"
        return 0
    end
    echo "Deleting:"
    printf '  %s\n' $gone
    git branch -D $gone
end

