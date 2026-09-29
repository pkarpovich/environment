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

    # the CLI only knows about ~/.claude, so the work profile ends up without any of
    # this. Mirror every skill that is a symlink in the personal profile - that is
    # exactly the set nothing else manages: the vendored ones point into
    # ~/.agents/skills, peon-ping's into its brew keg. Skills that dotbot links from
    # the repo are directories, not symlinks, and it already links them into both.
    set -l work ~/.claude-work/skills
    mkdir -p $work
    set -l mirrored 0
    for src in ~/.claude/skills/*
        set -l name (basename $src)
        test -e $work/$name; and continue
        if test -L $src
            # vendored: the whole skill directory is one link into ~/.agents/skills
            ln -s (readlink $src) $work/$name
        else if test -L $src/SKILL.md
            # brew-installed (peon-ping): a real directory holding one linked SKILL.md.
            # Repo skills look the same but dotbot already put them in both profiles,
            # so the `test -e` above has skipped them by now
            mkdir -p $work/$name
            ln -s (readlink $src/SKILL.md) $work/$name/SKILL.md
        else
            # real files that live only here on purpose - client-specific ones that must
            # not leave this machine, so they are never in the repo and get no backup.
            # The work profile links to them where they lie rather than taking a copy
            ln -s $src $work/$name
        end
        set mirrored (math $mirrored + 1)
    end
    echo "-> mirrored $mirrored skill(s) into ~/.claude-work/skills"
end
