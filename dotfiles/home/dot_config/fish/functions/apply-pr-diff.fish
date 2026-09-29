function apply-pr-diff
    set -l script_path ~/Projects/environment/scripts/apply_pr_diff.py

    if not test -f $script_path
        echo "Error: apply_pr_diff.py not found at $script_path"
        return 1
    end

    set -l args

    if set -q GITEA_TOKEN
        set args $args --token $GITEA_TOKEN
    end

    set -l repo_url ""
    set -l prs ""

    for arg in $argv
        if string match -q -- "--prs=*" $arg
            set prs (string split --max 1 "=" $arg)[2]
        else
            if test -z "$repo_url"
                set repo_url $arg
            end
        end
    end

    if test -z "$repo_url"
        echo "Usage: apply-pr-diff <repo-url> [--prs=1,2,3]"
        echo "Example: apply-pr-diff http://gitea.example.com/owner/repo --prs=1,3"
        echo "Set GITEA_TOKEN environment variable for authentication"
        return 1
    end

    set args $args --repo-url $repo_url

    if test -n "$prs"
        set args $args --prs $prs
    end

    python3 $script_path $args
end

