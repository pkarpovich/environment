# add pnpm via mise
set -gx PNPM_HOME "$(mise where pnpm)/bin"
fish_add_path $PNPM_HOME

# add GOROOT
set -gx GOROOT (mise where go)

# Load PATH
fish_add_path ~/.local/bin
fish_add_path ~/.local/share/mise/shims

set --export EDITOR "zed"

if test -f ~/.config/fish/local.fish
    source ~/.config/fish/local.fish
end

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

function fish_greeting
    yafetch
end

function y
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	yazi $argv --cwd-file="$tmp"
	if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
		builtin cd -- "$cwd"
	end
	rm -f -- "$tmp"
end

function gm
    if test (count $argv) -eq 0
        echo "Usage: gm <message>"
        return 1
    end

    set message $argv[1]

    set result (eval 'lumen draft --context "$message"')
    echo $result | pbcopy

    echo $result
end

function gmi
    if test (count $argv) -eq 0
        echo "Usage: gmi <message>"
        return 1
    end

    set result (eval gm $argv[1])
    git commit -m $result
    lazygit
end

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