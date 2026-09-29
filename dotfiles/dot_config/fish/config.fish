# tmux paints every non-ASCII glyph as "_" when the client that attached has no
# UTF-8 locale, and ssh forwards LANG only when the client sends it - mosh always
# does (LANG=C.UTF-8), wezterm over ssh does not. Set before local.fish's login
# menu execs the tmux client.
test -n "$LANG"; or set -gx LANG en_US.UTF-8

# `skills` reports every add/update to add-skill.vercel.sh; DO_NOT_TRACK is the
# convention it and a good number of other CLIs honour
set -gx DO_NOT_TRACK 1

fish_add_path ~/.local/bin

if test -f ~/.config/fish/local.fish
    source ~/.config/fish/local.fish
end

alias cd 'z'
alias cdi 'zi'
alias ls 'eza --color=always --icons --group-directories-first'
alias la 'eza --color=always --icons --group-directories-first --all'
alias ll 'eza --color=always --icons --group-directories-first --all --long'
alias l 'eza --group --header --group-directories-first --long --git --all --binary --all --icons always'
alias tree 'eza --tree'
alias cat 'moor --no-linenumbers --quit-if-one-screen'
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

bind \eOH beginning-of-line
bind \eOF end-of-line
bind \cU backward-kill-line

zoxide init fish | source
atuin init fish | source
starship init fish | source

# agterm's installer owns this block and looks for it in this exact file
# >>> agterm agent-status >>>
test -f ~/.config/agterm/agent-status/shell/integration.fish; and source ~/.config/agterm/agent-status/shell/integration.fish
# <<< agterm agent-status <<<
