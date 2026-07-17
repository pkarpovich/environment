function envup --description "refresh the full dev environment: brew, fisher, mise tools, uv tools, claude"
    echo "==> brewup"
    brewup
    echo

    if command -q agent-browser
        echo "==> agent-browser-skill-sync"
        agent-browser-skill-sync
        echo
    end

    if command -q fisher
        echo "==> fisher update"
        fisher update
        echo
    end

    if command -q mise
        echo "==> mise upgrade"
        mise upgrade
        echo
    end

    if command -q uv
        echo "==> uv self update"
        uv self update
        echo
        echo "==> uv tool upgrade --all"
        uv tool upgrade --all
        echo
    end

    if command -q claude
        echo "==> claude update"
        claude update
        echo
        echo "==> claude plugin marketplace update"
        claude plugin marketplace update
        echo
        echo "==> claude plugin update (all installed)"
        for plugin in (claude plugin list --json | jq -r '.[].id')
            echo "    -> $plugin"
            claude plugin update $plugin
        end
        echo
    end

    echo "==> envup done"
end

