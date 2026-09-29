set -gx EDITOR "zed --wait"

# pnpm is provided by `mise activate` below - do NOT fish_add_path a versioned
# mise pnpm bin here: fish_add_path writes to the persistent universal
# fish_user_paths and accumulates stale pnpm version dirs that shadow mise.

set -gx GOROOT (mise where go)

fish_add_path ~/.local/share/mise/shims
fish_add_path ~/.dotnet/tools
# libpq is keg-only (it conflicts with a full PostgreSQL), so psql and pg_dump
# only exist inside its own keg
fish_add_path /opt/homebrew/opt/libpq/bin

mise activate fish | source
# if we don't have the completions installed, add them now
if ! test -f $HOME/.config/fish/completions/mise.fish
    mise completions fish > $HOME/.config/fish/completions/mise.fish
end

alias pui 'pnpm update --interactive --latest -r --include-workspace-root'
alias pu 'pnpm update -r --include-workspace-root'
alias rx 'caffeinate -i ralphex --skip-finalize'
alias rxw 'CLAUDE_CONFIG_DIR=~/.claude-work caffeinate -i ralphex --skip-finalize'
alias f 'open .'
alias cb 'pbcopy'
alias gg 'smerge .' # Git Gui
alias e 'zed .'
