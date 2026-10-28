function skills-restore --description "reinstall every skill recorded in ~/.agents/.skill-lock.json"
    set -l lock ~/.agents/.skill-lock.json
    if not test -f $lock
        echo "skills-restore: no lock at $lock" >&2
        return 1
    end

    # `skills` has no restore-from-lock for the global scope - experimental_install
    # only reads a project-level skills-lock.json - so replay the lock by hand.
    # One `add` per source+ref, the way the CLI itself rebuilds a source: the ref
    # rides along as `<url>#<ref>`, and skills are named with repeated -s flags.
    set -l groups (jq -r '
        .skills | to_entries
        | group_by(.value.sourceUrl + "#" + (.value.ref // ""))
        | .[]
        | (.[0].value.sourceUrl + (if .[0].value.ref then "#" + .[0].value.ref else "" end))
          + "\t" + ([.[].key] | join(" "))' $lock)

    for group in $groups
        set -l parts (string split \t -- $group)
        set -l names (string split " " -- $parts[2])
        set -l args
        for n in $names
            set -a args -s $n
        end

        echo "-> $parts[1] ("(count $names)")"
        # naming a second agent is what buys a symlink: with one target directory
        # the CLI short-circuits to copying, and ~/.agents stops being canonical.
        # Zed is not decoration - its skills dir IS ~/.agents/skills
        npx --yes skills@latest add $parts[1] -g -a claude-code -a zed -y $args
    end
end
