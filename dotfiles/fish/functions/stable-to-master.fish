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

