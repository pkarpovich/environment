function sync-to-gitea
    set -l script_path ~/Projects/environment/scripts/sync_to_gitea.py

    if not test -f $script_path
        echo "Error: sync_to_gitea.py not found at $script_path"
        return 1
    end

    set -l args

    if set -q GITEA_TOKEN
        set args $args --token $GITEA_TOKEN
    else
        echo "Error: GITEA_TOKEN environment variable not set"
        return 1
    end

    if set -q GITEA_USERNAME
        set args $args --username $GITEA_USERNAME
    else
        echo "Error: GITEA_USERNAME environment variable not set"
        return 1
    end

    if set -q GITEA_URL
        set args $args --gitea-url $GITEA_URL
    else
        echo "Error: GITEA_URL environment variable not set"
        return 1
    end

    set -l projects_dir .
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

