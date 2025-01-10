local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.color_scheme = "Earthsong"
config.window_frame = {
    font_size = 12,
}
config.command_palette_font_size = 16
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = false
config.window_decorations = "RESIZE"
config.font = wezterm.font_with_fallback({
    { family = "Iosevka Nerd Font", weight = "Light" },
    { family = "Victor Mono", weight = "Regular" },
})
config.font_size = 18
config.front_end = "OpenGL"
config.freetype_load_target = "Light"
config.freetype_render_target = "HorizontalLcd"
config.cell_width = 0.9
config.window_background_opacity = 0.99
config.initial_rows = 40
config.initial_cols = 150
config.native_macos_fullscreen_mode = true

config.leader = { key = "L", mods = "ALT|SHIFT", timeout_milliseconds = 2000 }
config.keys = require("keybinds")

local bar = wezterm.plugin.require("https://github.com/adriankarlen/bar.wezterm")
bar.apply_to_config(config, {
    modules = {
        username = { enabled = false },
        hostname = { enabled = false },
        clock = { enabled = false },
    }
})

local domains = wezterm.plugin.require("https://github.com/DavidRR-F/quick_domains.wezterm")
domains.apply_to_config(config)

do
    local onep_auth = string.format("%s/.1password/agent.sock", wezterm.home_dir)

    if #wezterm.glob(onep_auth) == 1 then
        config.default_ssh_auth_sock = onep_auth
    end
end

require("workspaces")(config)

wezterm.on("gui-startup", function(cmd)
    wezterm.log_info("gui-startup")
    local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
    window:gui_window():maximize()
end)

return config