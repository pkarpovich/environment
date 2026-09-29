#!/bin/bash
# Bootstraps the chezmoi-managed home in a throwaway Debian 13 container from this
# working tree, the way a new Linux box gets it, then checks the result. Needs a
# running docker (Colima here); takes several minutes, most of it Homebrew.
set -u

repo=$(cd "$(dirname "$0")/.." && pwd)
name="check-home-linux-$$"
trap 'docker rm -f "$name" >/dev/null 2>&1' EXIT

docker run -d --name "$name" --platform linux/arm64 -v "$repo:/src:ro" debian:13 sleep infinity >/dev/null || exit 1
docker exec "$name" sh -c '
    apt-get update -qq && apt-get install -y -qq sudo curl ca-certificates >/dev/null
    useradd -m -s /bin/bash pk
    echo "pk ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/pk' || exit 1

docker exec -u pk -w /home/pk "$name" bash -c '
    set -e
    mkdir -p ~/.local/share/chezmoi/dotfiles
    cp /src/.chezmoiroot ~/.local/share/chezmoi/
    cp -a /src/dotfiles/home ~/.local/share/chezmoi/dotfiles/
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply --source ~/.local/share/chezmoi' || exit 1

docker exec -i -u pk -w /home/pk "$name" bash -s <<'EOF'
failed=0
src=~/.local/share/chezmoi/dotfiles/home
brew=/home/linuxbrew/.linuxbrew/bin

check() {
    local name=$1
    shift
    if "$@" >/dev/null 2>&1; then
        printf 'ok    %s\n' "$name"
    else
        printf 'FAIL  %s\n' "$name"
        failed=1
    fi
}
absent() { [ ! -e "$1" ] && [ ! -L "$1" ]; }
linked_into_source() { [ -L "$1" ] && case $(readlink "$1") in "$src"/*) true ;; *) false ;; esac; }
tty_shell() {
    sleep 30 | script -qec "$1" /dev/null >/dev/null 2>&1 &
    sleep 3
    local p c
    p=$(pgrep -n -x script)
    while c=$(pgrep -P "$p" | head -1); [ -n "$c" ]; do p=$c; done
    ps -o comm= -p "$p"
    pkill -n -x script
}

for f in .gitconfig .gitignore_global .Brewfile .config/starship.toml .config/fish/config.fish \
    .config/fish/conf.d/linux.fish .config/fish/functions/brewup.fish .config/bash/exec-fish.bash; do
    check "~/$f links into the source" linked_into_source ~/"$f"
done
for f in .gitconfig.darwin brewfiles .config/fish/conf.d/darwin.fish .config/fish/functions/wt.fish \
    .config/fish/functions/fish_greeting.fish .config/fish/functions/ccm.fish; do
    check "~/$f is not installed" absent ~/"$f"
done

expected=$(cat "$src/dot_Brewfile" "$src/brewfiles/linux.rb" | grep -oE '^brew\("[^"]+"' | cut -d'"' -f2 | sort)
check "the Brewfile resolves to exactly the shared list" test "$($brew/brew bundle list --global --all 2>/dev/null | sort)" = "$expected"
check "the Brewfile holds no casks or mas apps" sh -c "! $brew/brew bundle list --global --cask --mas 2>/dev/null | grep -q ."
check "fish comes from Homebrew" test -x $brew/fish
check "fisher is installed" $brew/fish -c 'functions -q fisher'
check "ls is eza from Homebrew" $brew/fish -l -c 'functions ls | string match -q "*eza*"; and string match -q "/home/linuxbrew/*" (command -s eza)'
for a in cat curl ping dig htop lg; do
    check "the $a alias resolves" $brew/fish -l -c "set -l c (functions $a | string match -r '^\s+(\S+)' | tail -1); command -q \$c"
done
check "Mac-only aliases are not defined" $brew/fish -l -c 'not functions -q rx; and not functions -q cb'
check "EDITOR is vim" test "$($brew/fish -l -c 'echo $EDITOR')" = vim
check "clear works under agterm's TERM" env TERM=xterm-ghostty clear
check "the mise settings file links into the source" linked_into_source ~/.config/mise/conf.d/no-implicit-installs.toml
check "commits are not signed" test -z "$(git config --get commit.gpgsign)"

check "an interactive login bash on a tty becomes fish" test "$(tty_shell 'bash -l')" = fish
check "BASH_STAY=1 keeps bash" test "$(tty_shell 'env BASH_STAY=1 bash -l')" = bash
check "bash -c stays bash" test "$(bash -c 'echo $0')" = bash
check "bash -ic stays bash" test "$(bash -ic 'echo $0' 2>/dev/null)" = bash

check "a second apply changes nothing" test -z "$(~/.local/bin/chezmoi apply -v 2>&1)"
check "the .bashrc hook is there once" test "$(grep -c exec-fish.bash ~/.bashrc)" = 1

exit $failed
EOF
