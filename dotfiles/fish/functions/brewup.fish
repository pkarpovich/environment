function brewup --description "refresh Homebrew against the Brewfile: update, bundle install, upgrade, bundle cleanup, cleanup"
    echo "==> brew update"
    brew update
    echo

    # the Brewfile is the record of what this machine is meant to have: this installs
    # what is missing, upgrades what it lists and applies its trusted: flags. A new
    # mas() entry asks for the root password here, seconds into the run
    echo "==> brew bundle install --global"
    brew bundle install --global
    echo

    # what bundle does not own: bare dependencies, anything not in the Brewfile.
    # --greedy-latest picks up the :latest casks (wezterm@nightly) and leaves the
    # self-updating ones alone; plain --greedy re-downloaded those every run
    echo "==> brew upgrade --greedy-latest"
    brew upgrade --greedy-latest
    echo

    # lists what is installed but not in the Brewfile and asks. y removes it and
    # resets the trust store to the Brewfile, n keeps everything: the drift report
    echo "==> brew bundle cleanup --global"
    brew bundle cleanup --global
    echo

    # cache older than 120 days; autoremove is part of cleanup since brew 6
    echo "==> brew cleanup"
    brew cleanup
end
