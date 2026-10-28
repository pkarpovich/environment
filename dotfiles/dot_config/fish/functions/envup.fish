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

    echo "==> brewup"
    brewup
    echo

    # fisher is a function, not a binary: command -q never saw it and this step
    # silently skipped on every run until 2026-09-07
    if functions -q fisher
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
        mise prune --yes
        echo
    end

    if command -q claude
        echo "==> claude update"
        claude update
        echo
        echo "==> claude plugins"
        claude plugin marketplace update
        for plugin in (claude plugin list --json | jq -r '.[] | select(.scope == "user") | .id')
            echo "    -> $plugin"
            claude plugin update $plugin
        end
        echo
    end

    # third-party skills from the lock in ~/.agents
    if command -q npx; and test -f ~/.agents/.skill-lock.json
        echo "==> skills update"
        npx --yes skills@latest update -g -y
        echo
    end

    echo "==> envup done"
end

