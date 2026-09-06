function brewup --description "refresh Homebrew against the Brewfile: update, bundle install, upgrade, bundle cleanup, cleanup"
    # brew 6 ask mode stops to confirm any upgrade plan that touches dependencies;
    # this runs unattended, the plan is still printed
    set -lx HOMEBREW_NO_ASK 1

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

    # the drift report: what is installed but not in the Brewfile. Without a tty on
    # stdin it prints the plan and exits 0 instead of asking; nothing is removed here.
    # To act on it: brew bundle cleanup --global --force (also resets the trust store)
    echo "==> brew bundle cleanup --global"
    brew bundle cleanup --global </dev/null
    echo

    # cache older than 120 days; autoremove is part of cleanup since brew 6
    echo "==> brew cleanup"
    brew cleanup
end
