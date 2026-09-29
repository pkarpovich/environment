# Dotfiles

Two tools put these files into place, and each owns a disjoint set:

- **chezmoi** owns [`home/`](home/) - what every machine gets, Linux boxes
  included: fish, git, starship and the Brewfile. It runs in symlink mode, so
  every target is a symlink back into this repo, same as with dotbot. The files
  that exist on one OS only are picked in one place,
  [`home/.chezmoiignore`](home/.chezmoiignore); the shared files carry no OS
  or `type -q` conditions.
- **dotbot** owns the rest, which is macOS-only - the map is
  [`install.conf.yaml`](install.conf.yaml).

Tools come from Homebrew on both OSes: [`home/dot_Brewfile`](home/dot_Brewfile)
lists the shell and everything its aliases resolve to, and loads
`home/brewfiles/darwin.rb` (the Mac's apps and CLI tools) or
`home/brewfiles/linux.rb` by `uname`. `darwin.rb` in turn loads
`<LocalHostName>.rb` for one Mac's extras.

```sh
mise run link_dotfiles     # from the repo root: dotbot, then chezmoi apply
```

A new Linux box (needs `curl` and passwordless `sudo` for the Homebrew prefix):

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply pkarpovich/environment
```

That installs Homebrew into `/home/linuxbrew/.linuxbrew`, the Brewfile, fisher
and its plugins, and one line in `~/.bashrc`: bash stays the login shell, so
`ssh host '<cmd>'` keeps a POSIX shell, while an interactive terminal execs
fish (`home/dot_config/bash/exec-fish.bash`; `BASH_STAY=1` opts out).

## Notable pieces

- **`agterm/`** - keymap and ghostty overrides for the
  [agterm](https://github.com/umputun/agterm) terminal, plus control scripts:
  numbered session jumps, the Claude-conversation map hook, side parking and
  reopen for the two-Mac flow. **Start with
  [`agterm/README.md`](agterm/README.md)** - it documents the whole
  Claude-session system, whose parts are spread across `agterm/`,
  `home/dot_config/fish/`, `claude/` and `tmux/`.
- **`home/dot_config/fish/`** - `config.fish` is shared; what one OS needs goes
  to `conf.d/darwin.fish` or `conf.d/linux.fish`, which fish sources before
  `config.fish`. One autoloaded function per file in `functions/` (`wt`, `ccl`,
  `ccm`, the `claude` wrapper, `zw`, `gcrb`, ...); the Mac-only ones are listed
  in `home/.chezmoiignore`.
- **`tmux/`** - the SSH/mosh attach point for the second Mac and the phone;
  `ccm` mirrors agterm's Claude sessions into its windows. It replaced zellij
  because Moshi's chat integration is tmux-only.
- **`claude/`** - Claude Code settings, hooks, agents, and our own skills;
  linked into both `~/.claude` and `~/.claude-work` profiles.
- **`agents/`** - linked whole as `~/.agents`: the store for skills written by
  *other people*, managed by [`npx skills`](https://skills.sh). Only
  `.skill-lock.json` is committed; `agents/skills/` is gitignored the way
  `node_modules/` is, so this repo never republishes someone else's docs. Run
  `skills-restore` on a new machine to replay the lock. Claude Code sees the
  skills because the installer drops a symlink per skill into
  `~/.claude/skills`. Install with
  `npx skills add <source> -g -a claude-code -a zed` - naming a second agent is
  what makes it symlink rather than copy, and Zed reads `~/.agents/skills`
  natively. Add `CLAUDE_CONFIG_DIR=~/.claude-work` in front for the work
  profile. `npx skills update -g` refreshes everything; the `skillFolderHash`
  lines in the lock diff say which skills actually moved.
- **`zed/`**, **`tuna/`**, **`yashiki/`**, **`revdiff/`** - editor, launcher,
  tiling WM, and diff-review configs.
- **`home/dot_config/starship.toml`** / **`starship-narrow.toml`** - two
  prompt presets, switchable at runtime.
- `karabiner.json` is linked from `../karabiner/dist/` - it is generated, see
  the karabiner generator in the repo root.
- `wezterm/` is the pre-agterm setup, kept for reference.
