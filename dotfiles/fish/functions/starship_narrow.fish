function starship_narrow
    set -gx STARSHIP_CONFIG ~/Projects/environment/dotfiles/starship-narrow.toml
    echo "🔹 Switched to narrow Starship config"
    commandline -f repaint
end

