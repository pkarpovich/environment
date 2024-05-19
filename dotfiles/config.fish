# add pnpm via mise
set -gx PNPM_HOME "$(mise where pnpm)/bin"
fish_add_path $PNPM_HOME

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

function br --wraps=broot
    set -l cmd_file (mktemp)
    if broot --outcmd $cmd_file $argv
        read --local --null cmd < $cmd_file
        rm -f $cmd_file
        eval $cmd
    else
        set -l code $status
        rm -f $cmd_file
        return $code
    end
end

alias ls 'eza --color=always --icons --group-directories-first'
alias la 'eza --color=always --icons --group-directories-first --all'
alias ll 'eza --color=always --icons --group-directories-first --all --long'
alias cat 'bat -pp'
alias tree 'eza --tree'

zoxide init fish | source
starship init fish | source
