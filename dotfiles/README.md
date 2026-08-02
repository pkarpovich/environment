# Dotfiles

Config files symlinked into place by dotbot - the map of what goes where is
[`install.conf.yaml`](install.conf.yaml). Tools themselves are installed from
the [`Brewfile`](Brewfile) (`brew bundle install`), so that file doubles as
the prerequisites list.

```sh
mise run link_dotfiles     # from the repo root; or: dotbot -c ./dotfiles/install.conf.yaml
```

## Notable pieces

- **`agterm/`** - keymap and ghostty overrides for the
  [agterm](https://github.com/umputun/agterm) terminal, plus control scripts:
  numbered session jumps, the Claude-conversation map hook, side parking and
  reopen for the two-Mac flow. **Start with
  [`agterm/README.md`](agterm/README.md)** - it documents the whole
  Claude-session system, whose parts are spread across `agterm/`, `fish/`,
  `claude/` and `tmux/`.
- **`fish/`** - `config.fish` plus one autoloaded function per file in
  `fish/functions/` (`wt`, `ccl`, `ccm`, the `claude` wrapper, `zw`, `gcrb`, ...).
- **`tmux/`** - the SSH/mosh attach point for the second Mac and the phone;
  `ccm` mirrors agterm's Claude sessions into its windows. It replaced zellij
  because Moshi's chat integration is tmux-only.
- **`claude/`** - Claude Code settings, hooks, agents, and custom skills;
  linked into both `~/.claude` and `~/.claude-work` profiles.
- **`zed/`**, **`tuna/`**, **`yashiki/`**, **`revdiff/`** - editor, launcher,
  tiling WM, and diff-review configs.
- **`starship.toml`** / **`starship-narrow.toml`** - two prompt presets,
  switchable at runtime.
- `karabiner.json` is linked from `../karabiner/dist/` - it is generated, see
  the karabiner generator in the repo root.
- `wezterm/` is the pre-agterm setup, kept for reference.
