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
    { family = "Victor Mono", weight = "Regular" },
    -- { family = "Iosevka Nerd Font", weight = "Light" },
})
config.font_size = 18
config.front_end = "OpenGL"
config.freetype_load_target = "Light"
config.freetype_render_target = "HorizontalLcd"
config.cell_width = 0.9
config.window_background_opacity = 0.99
config.initial_rows = 40
config.initial_cols = 150
config.ssh_backend = "Ssh2"
config.native_macos_fullscreen_mode = true

local SSH_AUTH_SOCK = os.getenv 'SSH_AUTH_SOCK'
if
    SSH_AUTH_SOCK
    == string.format('%s/keyring/ssh', os.getenv 'XDG_RUNTIME_DIR')
then
    local onep_auth =
        string.format('%s/.1password/agent.sock', wezterm.home_dir)
    -- Glob is being used here as an indirect way to check to see if
    -- the socket exists or not. If it didn't, the length of the result
    -- would be 0
    if #wezterm.glob(onep_auth) == 1 then
        config.default_ssh_auth_sock = onep_auth
    end
end

config.leader = { key = "L", mods = "ALT|SHIFT", timeout_milliseconds = 2000 }
config.keys = require("keybinds")

local bar = wezterm.plugin.require("https://github.com/adriankarlen/bar.wezterm")
bar.apply_to_config(config)

require("workspaces")(config)

wezterm.on("gui-startup", function(cmd)
    wezterm.log_info("gui-startup")
    local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
    window:gui_window():maximize()
end)

return config