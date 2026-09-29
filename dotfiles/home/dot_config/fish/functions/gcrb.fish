function gcrb --description "checkout a branch: exact-match argument directly, otherwise skim-pick with commit log preview"
    if test (count $argv) -ge 1
        if git show-ref --verify --quiet "refs/heads/$argv[1]"
            git checkout $argv[1]
            return
        end
        if git show-ref --verify --quiet "refs/remotes/origin/$argv[1]"
            git checkout --track origin/$argv[1]
            return
        end
    end

    set -l branch (
        git branch -a --format='%(refname:short)' |
        grep -v 'HEAD$' |
        sed 's|^origin/||' |
        sort -u |
        sk --height 50% --border --tac --query "$argv[1]" \
            --preview-window right:60% \
            --preview '(git log --oneline --graph --date=short --color=always --pretty="format:%C(auto)%cd %h%d %s" {} 2>/dev/null || git log --oneline --graph --date=short --color=always --pretty="format:%C(auto)%cd %h%d %s" origin/{}) | head -200'
    )

    test -z "$branch"; and return

    if git show-ref --verify --quiet "refs/heads/$branch"
        git checkout $branch
    else
        git checkout --track origin/$branch
    end
end

