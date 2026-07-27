# environment

My macOS development environment as a monorepo: terminal, shell, window
management, keyboard, and a growing layer of Claude Code automation - all
symlinked into place by [dotbot](https://github.com/anishathalye/dotbot) and
orchestrated by [mise](https://mise.jdx.dev/) tasks.

## Layout

| Path | What lives there |
|---|---|
| `dotfiles/agterm/` | [agterm](https://github.com/umputun/agterm) terminal: keymap, ghostty overrides, control scripts (session jumps, Claude conversation map, side parking) |
| `dotfiles/fish/` | fish config + autoloaded functions, one file per function |
| `dotfiles/zellij/` | zellij config and layouts - the attach point for working from a second Mac over SSH |
| `dotfiles/claude/` | Claude Code settings, hooks, and ~30 custom skills |
| `dotfiles/zed/`, `dotfiles/wezterm/`, ... | editor and terminal configs |
| `karabiner/` | Go generator that builds `karabiner.json` from rules |
| `universal-layout/` | custom EN/RU keyboard layout bundle |
| `dotfiles/yashiki/` | [yashiki](https://github.com/pkarpovich/yashiki-layout-kakejiku) tiling WM: per-monitor tag banks, app placement rules |
| `dotfiles/tuna/` | Tuna launcher bindings (app focus, project jumps) |
| `scripts/` | machine provisioning scripts |

## Workflow highlights

- **Terminal**: agterm as the daily driver, one session per task/branch,
  agent-status glyphs showing which Claude needs attention.
- **Two-Mac flow**: a zellij session on the main Mac mirrors Claude sessions
  into tabs (`ccz`), so the same conversations continue from a laptop over
  SSH; returning home swaps them back with one chord. A per-session
  conversation map (written by a Claude Code hook) makes the handoff silent -
  the whole system is documented in
  [`dotfiles/agterm/README.md`](dotfiles/agterm/README.md).
- **Worktrees**: `wt <name>` creates a git worktree via
  [gt](https://github.com/melonamin/gt) and an agterm session named after the
  branch - one parallel task, one sidebar row.
- **Keyboard**: karabiner config is generated, not hand-written; the layout
  puts symbols on the unshifted digit row.

## Setup

```sh
mise run setup_env   # brew bundle + karabiner + dotbot links + duti
```

Individual steps: `install_tools`, `setup_keyboard`, `link_dotfiles`,
`apply_duti` - see `.mise.toml`.
