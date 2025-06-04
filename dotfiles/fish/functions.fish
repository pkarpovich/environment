function br --wraps=broot
    set -l cmd_file (mktemp)
    if broot --outcmd $cmd_file $argv
        read --local --null cmd < $cmd_file
        rm -f $cmd_file
        eval $cmd
    else
        set -l code $status
        rm -f $cmd_file
        return $code
    end
end

function fish_greeting
    yafetch
end

function y
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	yazi $argv --cwd-file="$tmp"
	if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
		builtin cd -- "$cwd"
	end
	rm -f -- "$tmp"
end

function gm
    if test (count $argv) -eq 0
        echo "Usage: gm <message>"
        return 1
    end

    set message $argv[1]

    set result (eval 'lumen draft --context "$message"')
    echo $result | pbcopy

    echo $result
end

function gmi
    if test (count $argv) -eq 0
        echo "Usage: gmi <message>"
        return 1
    end

    set result (eval gm $argv[1])
    git commit -m $result
    lazygit
end

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

function sync-to-gitea
    set -l script_path ~/Projects/environment/scripts/sync_to_gitea.py
    
    if not test -f $script_path
        echo "Error: sync_to_gitea.py not found at $script_path"
        return 1
    end
    
    set -l args
    
    # Add token if GITEA_TOKEN is set
    if set -q GITEA_TOKEN
        set args $args --token $GITEA_TOKEN
    else
        echo "Error: GITEA_TOKEN environment variable not set"
        return 1
    end
    
    # Add username if GITEA_USERNAME is set
    if set -q GITEA_USERNAME
        set args $args --username $GITEA_USERNAME
    else
        echo "Error: GITEA_USERNAME environment variable not set"
        return 1
    end
    
    # Add gitea URL if GITEA_URL is set
    if set -q GITEA_URL
        set args $args --gitea-url $GITEA_URL
    else
        echo "Error: GITEA_URL environment variable not set"
        return 1
    end
    
    # Default projects directory
    set -l projects_dir .
    
    # Parse arguments
    set -l auto_yes false
    for arg in $argv
        if string match -q -- "--projects-dir=*" $arg
            set projects_dir (string split --max 1 "=" $arg)[2]
        else if test "$arg" = "--yes" -o "$arg" = "-y"
            set auto_yes true
        else
            set projects_dir $arg
        end
    end
    
    set args $args --projects-dir $projects_dir --remove-remote
    
    if test "$auto_yes" = true
        set args $args --yes
    end
    
    python3 $script_path $args
end

function stable-to-master
    set -l script_path ~/Projects/environment/scripts/git-stable-master-sync.sh
    
    if not test -f $script_path
        echo "Error: git-stable-master-sync.sh not found at $script_path"
        return 1
    end
    
    if test (count $argv) -lt 2
        echo "Usage: stable-to-master <source-branch> <target-branch> [base-source-branch] [base-target-branch]"
        echo "Example: stable-to-master PBI-110614-s PBI-110614-m"
        echo "Example: stable-to-master PBI-110614-s PBI-110614-m release/stable master"
        echo ""
        echo "If base branches are not provided, defaults will be used:"
        echo "  - Base source branch: release/stable"
        echo "  - Base target branch: master"
        return 1
    end
    
    bash $script_path $argv
end