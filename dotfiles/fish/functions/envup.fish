function envup --description "refresh the full dev environment: brew, fisher, mise tools, claude"
    # first, because `mas upgrade` needs root: the password gets asked at the start of
    # the run rather than minutes into it. Skipped entirely when nothing is stale, so
    # the usual run never prompts
    if command -q mas
        set -l stale (mas outdated)
        if test (count $stale) -gt 0
            echo "==> mas upgrade"
            printf '%s\n' $stale
            sudo mas upgrade
            echo
        end
    end

    # missing Brewfile entries next, for the same reason mas goes first: a new mas()
    # entry needs root. This is also the step that applies the Brewfile's trusted:
    # flags. Upgrades stay with brewup, which runs brew update first
    echo "==> brew bundle install --global --no-upgrade"
    brew bundle install --global --no-upgrade
    echo

    echo "==> brewup"
    brewup
    echo

    if command -q fisher
        echo "==> fisher update"
        fisher update
        echo
    end

    if command -q mise
        echo "==> mise upgrade"
        mise upgrade
        echo
        # upgrade leaves every superseded version behind; 25 had piled up on the Air
        echo "==> mise prune"
        mise prune
        echo
    end

    if command -q claude
        echo "==> claude update"
        claude update
        echo
        # plugins live per config dir, so the work profile needs its own pass. Without
        # it that side just falls behind silently - it sat on planning 3.4.0 while this
        # one was on 3.8.5. Passing the path explicitly for both keeps the two
        # iterations identical, and nothing leaks into the calling shell
        for cfg in ~/.claude ~/.claude-work
            test -d $cfg; or continue
            echo "==> claude plugins ("(basename $cfg)")"
            env CLAUDE_CONFIG_DIR=$cfg claude plugin marketplace update
            for plugin in (env CLAUDE_CONFIG_DIR=$cfg claude plugin list --json | jq -r '.[].id')
                echo "    -> $plugin"
                env CLAUDE_CONFIG_DIR=$cfg claude plugin update $plugin
            end
            echo
        end

        # the work profile cannot install these plugins at all - org policy allows
        # exactly one - so cc-vendor symlinks them in from the personal profile. Those
        # links pin the version they were made against, and the update above deletes
        # it: 10 of 22 were dangling before this ran here
        if functions -q cc-vendor
            echo "==> cc-vendor apply"
            cc-vendor apply
            echo
        end
    end

    echo "==> envup done"
end

