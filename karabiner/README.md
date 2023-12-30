# Karabiner Elements configuration
## Installation

1. Install & start [Karabiner Elements](https://karabiner-elements.pqrs.org/)
2. Clone this repository
3. Delete the default `~/.config/karabiner` folder
4. Create a symlink with `ln -s PATH ~/.config` (where `PATH` is your local path to where you cloned the repository)
5. [Restart karabiner_console_user_server](https://karabiner-elements.pqrs.org/docs/manual/misc/configuration-file-path/) with `` launchctl kickstart -k gui/$(id -u)/org.pqrs.karabiner.karabiner_console_user_server ``