#!/usr/bin/env fish

ln -sf "/Applications/Sublime Merge.app/Contents/SharedSupport/bin/smerge" ~/.local/bin/smerge

ln -sf ~/Projects/environment/dotfiles/.gitignore_global ~/.gitignore_global
ln -sf ~/Projects/environment/dotfiles/.gitconfig ~/.gitconfig
ln -sf ~/Projects/environment/dotfiles/mise.config.toml ~/.config/mise/config.toml
ln -sf ~/Projects/environment/dotfiles/config.fish ~/.config/fish/config.fish
ln -sf ~/Projects/environment/dotfiles/fish_plugins ~/.config/fish/fish_plugins
ln -sf ~/Projects/environment/dotfiles/starship.toml ~/.config/starship.toml
rm ~/.config/wezterm || true
ln -sf ~/Projects/environment/dotfiles/wezterm ~/.config/wezterm