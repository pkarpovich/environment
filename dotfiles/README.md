# Dotfiles

This directory is the [chezmoi](https://www.chezmoi.io/) source (`.chezmoiroot`
at the repo root points here): every file sits at the path it gets in `$HOME`,
with chezmoi's `dot_` prefix for a leading dot - `dot_config/fish/config.fish`
is `~/.config/fish/config.fish`, `Library/LaunchAgents/...` is
`~/Library/LaunchAgents/...`. chezmoi runs in symlink mode, so every target is a
symlink back into this repo: edit either end, the change is in git. A new file
needs `chezmoi apply` once to get its link; `chezmoi status` shows anything that
drifted, including an app that replaced its link with a real file.

One tree serves the Mac and the Linux boxes. What exists on one OS only is
decided in one place, [`.chezmoiignore`](.chezmoiignore); the shared files
carry no OS or `type -q` conditions. Its first block lists what here is not a
`$HOME` file at all: `agents/` (linked whole as `~/.agents`), `colima/` (scripts
launchd runs from the repo), `Caddyfile` (linked into the Homebrew prefix by a
script), `brewfiles/`, and a few configs nothing links anymore.

Three things chezmoi does not do by itself are scripts in
[`.chezmoiscripts/`](.chezmoiscripts/): `~/.claude-work` gets the same links as
`~/.claude`, the Caddyfile link outside `$HOME`, and the Linux bootstrap below.

Tools come from Homebrew on both OSes: [`dot_Brewfile`](dot_Brewfile)
lists the shell and everything its aliases resolve to, and loads
`brewfiles/darwin.rb` (the Mac's apps and CLI tools) or `brewfiles/linux.rb`
by `uname`. `darwin.rb` in turn loads `<LocalHostName>.rb` for one Mac's extras.

```sh
mise run link_dotfiles     # from the repo root: chezmoi init --apply
```

A new Linux box (needs `curl` and passwordless `sudo` for the Homebrew prefix):

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply pkarpovich/environment
```

That installs Homebrew into `/home/linuxbrew/.linuxbrew`, the Brewfile, fisher
and its plugins, and one line in `~/.bashrc`: bash stays the login shell, so
`ssh host '<cmd>'` keeps a POSIX shell, while an interactive terminal execs
fish (`dot_config/bash/exec-fish.bash`; `BASH_STAY=1` opts out). The clone
lives wherever `chezmoi init` put it; on the Pis it was moved to `~/environment`
with `chezmoi init --source ~/environment --apply`.

What one machine needs and no other should see stays out of the repo:
`~/.config/fish/local.fish` for the shell, `~/.gitconfig.local` for git (included
last, so it wins; a missing file is fine).

## Notable pieces

- **`dot_config/agterm/`** - keymap and ghostty overrides for the
  [agterm](https://github.com/umputun/agterm) terminal, plus control scripts:
  numbered session jumps, the Claude-conversation map hook, side parking and
  reopen for the two-Mac flow. **Start with
  [`dot_config/agterm/README.md`](dot_config/agterm/README.md)** - it documents the whole
  Claude-session system, whose parts are spread across
  `dot_config/agterm/`, `dot_config/fish/`, `dot_claude/` and
  `dot_config/tmux/`.
- **`dot_config/fish/`** - `config.fish` is shared; what one OS needs goes
  to `conf.d/darwin.fish` or `conf.d/linux.fish`, which fish sources before
  `config.fish`. One autoloaded function per file in `functions/` (`wt`, `ccl`,
  `ccm`, the `claude` wrapper, `zw`, `gcrb`, ...); the Mac-only ones are listed
  in `.chezmoiignore`.
- **`dot_config/tmux/`** - the SSH/mosh attach point for the second Mac and the phone;
  `ccm` mirrors agterm's Claude sessions into its windows. It replaced zellij
  because Moshi's chat integration is tmux-only.
- **`dot_claude/`** - Claude Code settings, hooks, agents, and our own skills;
  linked into `~/.claude`, and into `~/.claude-work` by a script.
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
- **`dot_config/zed/`**, **`Library/Application Support/Tuna/`**,
  **`dot_config/yashiki/`**, **`dot_config/revdiff/`** - editor, launcher,
  tiling WM, and diff-review configs.
- **`dot_config/starship.toml`** / **`starship-narrow.toml`** - two
  prompt presets, switchable at runtime.
- `~/.config/karabinder.json` links to `../karabiner/dist/karabiner.json`
  (`dot_config/symlink_karabinder.json.tmpl`) - it is generated, see
  the karabiner generator in the repo root.
- `dot_config/wezterm/` is the pre-agterm setup, kept for reference.
