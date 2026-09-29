function starship_narrow
    set -gx STARSHIP_CONFIG ~/.config/starship-narrow.toml
    echo "🔹 Switched to narrow Starship config"
    commandline -f repaint
end

