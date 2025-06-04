# add pnpm via mise
set -gx PNPM_HOME "$(mise where pnpm)/bin"
fish_add_path $PNPM_HOME

# add GOROOT
set -gx GOROOT (mise where go)

# Load PATH
fish_add_path ~/.local/bin
fish_add_path ~/.local/share/mise/shims

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

source ~/.config/fish/functions.fish

alias cd 'z'
alias cdi 'zi'
alias ls 'eza --color=always --icons --group-directories-first'
alias la 'eza --color=always --icons --group-directories-first --all'
alias ll 'eza --color=always --icons --group-directories-first --all --long'
alias l 'eza --group --header --group-directories-first --long --git --all --binary --all --icons always'
alias cat 'moar --no-linenumbers --quit-if-one-screen'
alias tree 'eza --tree'
alias pui 'pnpm update --interactive --latest -r --include-workspace-root'
alias pu 'pnpm update -r --include-workspace-root'
alias cls 'clear'
alias curl 'curlie'
alias ping 'gping'
alias dig 'doggo'
alias htop 'glances'
alias lg 'lazygit'

zoxide init fish | source
starship init fish | source