# Custom wezterm status + attention module

## Overview

Replace `bar.wezterm` + `wezterm-attention` plugins with a single self-owned Lua module `dotfiles/wezterm/status.lua` (~120 lines). It owns all tab title rendering, left-status indicators (leader + zoom), and marker-based attention indicators driven by external file markers (Claude Code hooks today, anything else tomorrow).

Why: the two upstream plugins both register `format-tab-title` on the wezterm event bus and fight over registration order. Their merging requires renderer="manual" + custom wrap_title_formatter and still produces awkward edge cases (active tab swallows indicator, workspace forced on for leader, inflexible coloring per theme). One local module under our control eliminates the conflict, drops ~80% unused code, and turns notifications into a generic "any-CLI can mark a pane" mechanism.

## Context (from discovery)

- **Files involved**:
  - `dotfiles/wezterm/wezterm.lua` (entry config, plugin loading)
  - `dotfiles/wezterm/status.lua` (new module - the deliverable)
  - `dotfiles/claude/hooks/wezterm-attention/` → rename to `wezterm-status/`
  - `dotfiles/claude/settings.json` (Claude hook paths)
  - `~/.local/state/wezterm-attention/` → rename to `~/.local/state/wezterm-status/`

- **Patterns reused**:
  - bar.wezterm: `format-tab-title` + `update-status` event split, ANSI palette indices for theming
  - wezterm-attention: poller/renderer split with in-memory cache, atomic file writes (`.tmp` + rename), JSON `{"type":"<state>"}` markers per `WEZTERM_PANE`
  - existing dotbot `~/.claude/: claude/**` symlinks new files automatically

- **Dependencies removed**:
  - `wezterm.plugin.require("https://github.com/adriankarlen/bar.wezterm")`
  - `wezterm.plugin.require("https://github.com/pro-vi/wezterm-attention")`
  - all references in `configure_plugins` and `load_plugins`

## Development Approach

- **Testing approach**: manual visual verification (no Lua test framework in this dotfiles repo; testing wezterm UI is inherently visual)
- Each task implements one logical chunk and is verified by reload/restart of wezterm before moving on
- Keep wezterm.lua diff minimal - swap plugins for `require("status").apply(config, opts)` and delete dead code
- Keep marker file format JSON-compatible with existing `mark.sh` so transition is just dir rename

## Testing Strategy

- **Manual visual checks** after each task:
  - tab format renders correctly (active vs inactive)
  - leader 🌊 appears during `Alt+Shift+L` for ~2s
  - zoom indicator appears in zoom mode
  - writing a marker file produces the expected indicator on an inactive tab
- **Edge cases to verify**:
  - empty workspace (no panes), single pane, multi-pane tab, tab title with emoji
  - light theme + dark theme (colors should adapt or stay theme-neutral)

## Progress Tracking

- Mark completed items with `[x]` immediately when done
- Add newly discovered tasks with ➕ prefix
- Document issues/blockers with ⚠️ prefix

## Implementation Steps

### Task 1: Create status.lua skeleton with config defaults
- [x] create `dotfiles/wezterm/status.lua` with module table `M`, defaults block (`dir`, `indicators`, `colors`, `priority`, `auto_clear`, `leader_icon`, `zoom_icon`)
- [x] implement `M.apply(config, opts)` that merges user opts into defaults, stores active config on module-locals
- [x] export module (`return M`)
- [x] manual check: `require("status")` in `wezterm.lua` does not error on wezterm reload (verified via stubbed-wezterm load test; wiring into wezterm.lua deferred to Task 5)

### Task 2: Marker poll + cache
- [ ] implement `read_marker(dir, pane_id)` - opens file, parses JSON via `wezterm.json_parse`, validates `type` against allowed set
- [ ] implement `M.poll(window)` - iterates all panes of all tabs in window, refreshes cache entry for each
- [ ] register `wezterm.on("update-status", function(window) M.poll(window) end)` inside `apply`
- [ ] register `wezterm.on("pane-destroyed", function(_, pane) cleanup cache + remove file end)`
- [ ] manual check: write a marker via `mark.sh stop`, run `tail -f ~/Library/Logs/wezterm/...` (or use `wezterm.log_info`) to confirm cache picks it up within 1s

### Task 3: Format-tab-title with indicators
- [ ] implement `get_tab_attention(tab)` - scans cache for all panes in tab, returns `(indicator, type, color)` of highest-priority match (or empty)
- [ ] register `wezterm.on("format-tab-title", function(tab, _, _, conf, _, _) ... end)`
- [ ] for active tab: auto-clear `stop`/`notify` markers, render `<index>: <title>` with palette `tab_bar.active_tab.fg_color`/`bg_color`
- [ ] for inactive tab: render `<indicator><index>: <title>`, optionally apply Background tint when `colors[type]` is non-false
- [ ] truncate title to `tab_max_width` with ellipsis on overflow
- [ ] manual check: switch to another tab, write `{"type":"stop"}` marker for current pane, observe `✓` indicator on tab bar

### Task 4: Left status (leader + zoom)
- [ ] inside the same `update-status` callback used by poller, build leader/zoom segments
- [ ] leader: if `window:leader_is_active()`, append `<leader_icon>` colored with palette `ansi[4]` (or configured ANSI index)
- [ ] zoom: if any pane in current tab is `is_zoomed`, append `<zoom_icon>` colored ANSI red (or configured)
- [ ] call `window:set_left_status(wezterm.format(cells))`
- [ ] manual check: `Alt+Shift+L` shows 🌊 for 2s; zooming a pane shows zoom indicator

### Task 5: Wire status.lua into wezterm.lua
- [ ] in `wezterm.lua`, replace `attention`+`bar` from `load_plugins` and `configure_plugins` with single `require("status").apply(config, { dir = ..., leader_icon = ..., zoom_icon = ..., colors = ... })`
- [ ] delete dead bar/attention configuration blocks (padding, separator, modules tables - they were bar-specific)
- [ ] keep `tab_bar_at_bottom = true` and `use_fancy_tab_bar = false` directly in config (bar used to set these)
- [ ] manual check: cold restart wezterm, no errors, tab bar renders with leader/zoom, indicators trigger from `mark.sh`

### Task 6: Rename hook directory and marker location
- [ ] rename `dotfiles/claude/hooks/wezterm-attention/` to `dotfiles/claude/hooks/wezterm-status/`
- [ ] update `mark.sh` and `clear.sh` to write to `~/.local/state/wezterm-status/`
- [ ] update `dotfiles/claude/settings.json` - replace all `wezterm-attention` paths with `wezterm-status`
- [ ] update `status.lua` default `dir` to `~/.local/state/wezterm-status/`
- [ ] re-run `mise run link_dotfiles` to relink
- [ ] migrate any leftover marker files from old dir, then delete old dir
- [ ] manual check: trigger Claude Code tool use, verify marker appears in new dir, plugin picks it up

### Task 7: Verify acceptance criteria
- [ ] verify all requirements from Overview are implemented
- [ ] verify edge cases (multi-pane tab, light theme, dark theme, no markers, multiple markers competing for priority)
- [ ] cold-restart wezterm and exercise: open multiple tabs, run a long command in one, switch tabs, observe `thinking` indicator on inactive tab
- [ ] confirm `bar.wezterm` and `wezterm-attention` plugin requires fully removed from `wezterm.lua`
- [ ] grep for stale `wezterm-attention` references in repo: `grep -r wezterm-attention dotfiles/`

## Technical Details

**Marker file format** (kept compatible with existing scripts):
```json
{"type": "thinking" | "stop" | "notify" | "review", "frame": <int optional>}
```

**Module API surface** (status.lua):
```lua
M.apply(config, opts)              -- registers all event handlers
M.poll(window)                     -- manual poll if user disables auto-poll
M.get_attention(pane_id)           -- read cached state
M.remove_marker(pane_id)           -- delete marker + cache entry
```

**Default config**:
```lua
{
  dir = "~/.local/state/wezterm-status",
  leader_icon = utf8.char(0x1f30a),  -- 🌊
  zoom_icon = "",
  indicators = {
    thinking_frames = { "◌ ", "◔ ", "◑ ", "◕ " },
    stop = "✓ ", notify = "! ", review = "◆ ",
  },
  colors = {                          -- false = no bg tint
    thinking = false, stop = false, notify = false, review = false,
  },
  priority = { "thinking", "review", "stop", "notify" },
  auto_clear = { "stop", "notify" },
  review_key = { key = "b", mods = "ALT" },
}
```

**Event flow**:
1. CLI hook writes `<dir>/<WEZTERM_PANE>` atomically.
2. wezterm fires `update-status` (~1s interval) → `M.poll(window)` reads markers, updates cache.
3. wezterm fires `format-tab-title` for each tab → `get_tab_attention(tab)` returns indicator from cache.
4. Active tab render auto-clears `stop`/`notify` markers (file + cache).
5. `pane-destroyed` event removes the file + cache entry to prevent stale markers.

## Post-Completion

**Manual verification**:
- run a long Claude Code task with prompt → see spinner indicator on tab while you work elsewhere
- finish the task → see ✓ indicator
- switch back to that tab → indicator clears

**Future improvements (out of scope here)**:
- per-state colors that auto-switch with light/dark appearance
- cross-window marker visibility (currently scoped to mux window)
- additional indicators (clock, hostname, custom modules) - explicitly excluded by user
