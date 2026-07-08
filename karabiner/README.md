# Karabiner Elements configuration
## Installation

1. Install & start [Karabiner Elements](https://karabiner-elements.pqrs.org/)
2. Clone this repository
3. Generate `output/karabiner.json` (it is not committed) with `go run .` (see "Generating the configuration" below)
4. Delete the default `~/.config/karabiner` folder
5. Symlink the generated folder: `ln -s "$PWD/output" ~/.config/karabiner` (run from this directory)
6. [Restart karabiner_console_user_server](https://karabiner-elements.pqrs.org/docs/manual/misc/configuration-file-path/) with `` launchctl kickstart -k gui/$(id -u)/org.pqrs.karabiner.karabiner_console_user_server ``

## Generating the configuration

The rules live in Go (standard library only, no third-party dependencies), so a Go toolchain is required (`mise` provisions the pinned version automatically). Regenerate `output/karabiner.json` with:

```sh
go run .
```

Or run `mise run setup_keyboard` from the repo root to regenerate and reload Karabiner in one step.