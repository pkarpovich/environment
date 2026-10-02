#!/bin/bash
set -u

repo=$(cd "$(dirname "$0")/.." && pwd)
src="$repo/dotfiles"
failed=0

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

absent() {
    [ ! -e "$1" ] && [ ! -L "$1" ]
}

linked_into_source() {
    [ -L "$1" ] && case $(readlink "$1") in "$src"/*) true ;; *) false ;; esac
}

config=$(chezmoi dump-config --format json)
check "chezmoi runs in symlink mode" jq -e '.mode == "symlink"' <<<"$config"
check "chezmoi source is this repo" jq -e --arg r "$repo" '.sourceDir == $r' <<<"$config"
check "chezmoi verify is clean" chezmoi verify

for f in .gitconfig .gitconfig.darwin .gitignore_global; do
    check "~/$f links into the source" linked_into_source "$HOME/$f"
done
check "commits are signed through .gitconfig.darwin" test "$(git config --get commit.gpgsign)" = true
check "core.excludesfile points at an existing file" test -f "$(git config --get --path core.excludesfile)"

bare=$(mktemp -d)
cp "$src/dot_gitconfig" "$bare/.gitconfig"
check "without .gitconfig.darwin git still reads the shared config" env HOME="$bare" git config --get alias.s
check "without .gitconfig.darwin nothing is signed" test -z "$(HOME="$bare" git config --get commit.gpgsign)"
rm -rf "$bare"

check "~/.Brewfile links into the source" linked_into_source "$HOME/.Brewfile"
check "~/brewfiles is not installed" absent "$HOME/brewfiles"
check "the Brewfile lists what the fixture lists" \
    diff "$repo/scripts/fixtures/brewfile-darwin.txt" <(brew bundle list --global --all 2>/dev/null | sort)

check "~/.config/starship.toml links into the source" linked_into_source "$HOME/.config/starship.toml"
check "starship_narrow points at an existing config" \
    fish -c 'starship_narrow >/dev/null 2>&1; test -f $STARSHIP_CONFIG'

fish_src="$src/dot_config/fish"
for f in "$fish_src"/config.fish "$fish_src"/conf.d/*.fish "$fish_src"/functions/*.fish; do
    check "fish parses ${f#"$src"/}" fish --no-execute "$f"
done
check "shared config.fish has no OS or tool-presence guards" \
    sh -c "! grep -nE 'type -q|uname|command -q' '$fish_src/config.fish'"
check "~/.config/fish/config.fish links into the source" linked_into_source "$HOME/.config/fish/config.fish"
check "~/.config/fish/conf.d/darwin.fish links into the source" linked_into_source "$HOME/.config/fish/conf.d/darwin.fish"
check "conf.d/linux.fish is not installed" absent "$HOME/.config/fish/conf.d/linux.fish"
check "ls is eza" fish -l -c 'functions ls | string match -q "*eza*"'
check "rx is defined" fish -l -c 'functions -q rx'
check "mise never installs on its own" test "$(mise settings get not_found_auto_install)" = false
check "EDITOR is zed" test "$(fish -l -c 'echo $EDITOR')" = "zed --wait"

for f in .claude/settings.json .zshrc .config/agterm/keymap.conf .config/zed/settings.json \
    "Library/Application Support/Tuna/config.toml" Library/LaunchAgents/com.pavel-karpovich.colima.plist; do
    check "~/$f links into the source" linked_into_source "$HOME/$f"
done
check "~/.claude-work/settings.json links into the source" linked_into_source "$HOME/.claude-work/settings.json"
check "~/.agents links to the skill store" test "$(readlink "$HOME/.agents")" = "$src/agents"
check "Caddyfile in the Homebrew prefix links into the source" test "$(readlink /opt/homebrew/etc/Caddyfile)" = "$src/Caddyfile"
check "caddy imports this host's site snippet" test "$(readlink /opt/homebrew/etc/caddy-site.caddy)" = "$src/caddy/default.caddy"
check "~/.config/karabiner links to the generator output" test "$(readlink "$HOME/.config/karabiner")" = "$repo/karabiner/output"
check "Karabiner reads what the generator wrote" cmp "$repo/karabiner/output/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
check "an agterm script runs through its link" test -x "$HOME/.config/agterm/scripts/attach-remote.fish"
dangling=$(find "$HOME/.config" "$HOME/.claude" "$HOME/.claude-work" "$HOME/Library/LaunchAgents" -maxdepth 7 \
    -lname "$repo/*" ! -exec test -e {} \; -print 2>/dev/null)
check "no link in \$HOME points at a missing repo file" test -z "$dangling"

exit $failed
