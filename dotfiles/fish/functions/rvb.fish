function rvb --description "revdiff: review own branch changes since divergence from default branch"
    set -l default_branch (git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null | string replace 'origin/' '')
    if test -z "$default_branch"
        for candidate in main master
            if git show-ref --verify --quiet refs/heads/$candidate
                set default_branch $candidate
                break
            end
        end
    end
    if test -z "$default_branch"
        echo "rvb: could not detect default branch (main/master)" >&2
        return 1
    end

    set -l base (git merge-base $default_branch HEAD 2>/dev/null)
    if test -z "$base"
        echo "rvb: could not find merge-base with $default_branch" >&2
        return 1
    end

    revdiff $base $argv
end

