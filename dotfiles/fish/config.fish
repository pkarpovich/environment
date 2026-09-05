# tmux paints every non-ASCII glyph as "_" when the client that attached has no
# UTF-8 locale, and ssh forwards LANG only when the client sends it - mosh always
# does (LANG=C.UTF-8), wezterm over ssh does not. Set before local.fish's login
# menu execs the tmux client.
test -n "$LANG"; or set -gx LANG en_US.UTF-8

# pnpm is provided by `mise activate` below - do NOT fish_add_path a versioned
# mise pnpm bin here: fish_add_path writes to the persistent universal
# fish_user_paths and accumulates stale pnpm version dirs that shadow mise.

# add GOROOT
set -gx GOROOT (mise where go)

set -gx EDITOR "zed --wait"

# `skills` reports every add/update to add-skill.vercel.sh; DO_NOT_TRACK is the
# convention it and a good number of other CLIs honour
set -gx DO_NOT_TRACK 1

# Load PATH
fish_add_path ~/.local/bin
fish_add_path ~/.local/share/mise/shims
fish_add_path ~/.dotnet/tools
# libpq is keg-only (it conflicts with a full PostgreSQL), so psql and pg_dump
# only exist inside its own keg
fish_add_path /opt/homebrew/opt/libpq/bin

if type -q mise
    mise activate fish | source

    # if we don't have the completions installed, add them now
    if ! test -f $HOME/.config/fish/completions/mise.fish
        mise completions fish > $HOME/.config/fish/completions/mise.fish
    end
end

if test -f ~/.config/fish/local.fish
    source ~/.config/fish/local.fish
end

alias cd 'z'
alias cdi 'zi'
alias ls 'eza --color=always --icons --group-directories-first'
alias la 'eza --color=always --icons --group-directories-first --all'
alias ll 'eza --color=always --icons --group-directories-first --all --long'
alias l 'eza --group --header --group-directories-first --long --git --all --binary --all --icons always'
alias cat 'moor --no-linenumbers --quit-if-one-screen'
alias tree 'eza --tree'
alias pui 'pnpm update --interactive --latest -r --include-workspace-root'
alias pu 'pnpm update -r --include-workspace-root'
alias cls 'clear'
alias curl 'curlie'
alias ping 'gping'
alias dig 'doggo'
alias htop 'glances'
alias lg 'lazygit'
alias qq 'exit'
alias cc 'CLAUDE_CODE_NO_FLICKER=1 claude --enable-auto-mode'
alias ccr 'CLAUDE_CODE_NO_FLICKER=1 claude --enable-auto-mode --resume'
alias ccw 'CLAUDE_CONFIG_DIR=~/.claude-work CLAUDE_CODE_NO_FLICKER=1 claude --enable-auto-mode'
alias ccwr 'CLAUDE_CONFIG_DIR=~/.claude-work CLAUDE_CODE_NO_FLICKER=1 claude --enable-auto-mode --resume'
alias rx 'caffeinate -i ralphex'
alias rxw 'CLAUDE_CONFIG_DIR=~/.claude-work caffeinate -i ralphex'
alias f 'open .'
alias cb 'pbcopy'
alias gg 'smerge .' # Git Gui
alias e 'zed .'

bind \eOH beginning-of-line
bind \eOF end-of-line
bind \cU backward-kill-line

zoxide init fish | source
atuin init fish | source
starship init fish | source

# >>> agterm agent-status >>>
source '/Users/pavel.karpovich/.config/agterm/agent-status/shell/integration.fish'
# <<< agterm agent-status <<<
