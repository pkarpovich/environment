# add pnpm via mise
set -gx PNPM_HOME "$(mise where pnpm)/bin"
fish_add_path $PNPM_HOME

# Load PATH
fish_add_path ~/.local/bin
fish_add_path ~/.local/share/mise/shims

alias ls "eza --color=always --icons --group-directories-first"
alias la 'eza --color=always --icons --group-directories-first --all'
alias ll 'eza --color=always --icons --group-directories-first --all --long'
alias cat "bat"

mise activate fish | source
starship init fish | source
