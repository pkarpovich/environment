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
end

