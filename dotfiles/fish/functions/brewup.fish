function brewup --description "fully refresh Homebrew: update, upgrade, cleanup, autoremove"
    echo "==> brew update"
    brew update
    echo
    echo "==> brew upgrade --greedy"
    brew upgrade --greedy
    echo
    echo "==> brew cleanup"
    brew cleanup
    echo
    echo "==> brew autoremove"
    brew autoremove
    echo
    # the Brewfile is the record of what this machine is meant to have, so say so the
    # moment it stops matching rather than at the next audit
    echo "==> brew bundle check --global"
    brew bundle check --global
end

