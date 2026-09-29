# Karabiner Elements configuration
## Installation

1. Install & start [Karabiner Elements](https://karabiner-elements.pqrs.org/)
2. Delete the default `~/.config/karabiner` folder Karabiner creates on first launch
3. `mise run link_dotfiles` from the repo root. chezmoi links `~/.config/karabiner` to
   `output/` (`dotfiles/dot_config/symlink_karabiner.tmpl`), generates
   `output/karabiner.json` (it is not committed) and restarts the console user server
   (`dotfiles/.chezmoiscripts/run_onchange_after_52-darwin-karabiner.sh.tmpl`). The same
   script runs again on any `chezmoi apply` after a `*.go` file here changed, so a
   rule edit pulled on another Mac reaches its Karabiner without a manual rebuild.

## Generating the configuration

The rules live in Go (standard library only, no third-party dependencies), so a Go toolchain is required (`mise` provisions the pinned version automatically). Regenerate `output/karabiner.json` with:

```sh
go run .
```

Or run `mise run setup_keyboard` from the repo root to regenerate and reload Karabiner in one step.