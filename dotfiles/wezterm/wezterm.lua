local wezterm = require("wezterm")
local keybinds = require("keybinds")
local workspaces = require("workspaces")
local status = require("status")

local function load_plugins()
    return {
        domains = wezterm.plugin.require("https://github.com/DavidRR-F/quick_domains.wezterm"),
        resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm"),
        workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
    }
end

local function configure_ssh(config)
    local onep_auth = string.format("%s/.1password/agent.sock", wezterm.home_dir)
    if #wezterm.glob(onep_auth) == 1 then
        config.default_ssh_auth_sock = onep_auth
    end
end

local function configure_status(config)
    status.apply(config, {})
end

wezterm.on("update-status", function(window, pane)
    local domain = pane:get_domain_name()
    local overrides = window:get_config_overrides() or {}
    if domain ~= "local" then
        overrides.background = {
            { source = { Color = "#2e1d1a" }, width = "100%", height = "100%", opacity = 0.97 },
        }
    else
        overrides.background = nil
    end
    window:set_config_overrides(overrides)
end)

wezterm.on("gui-startup", function(cmd)
    wezterm.log_info("gui-startup")
    local _, _, window = wezterm.mux.spawn_window(cmd or {})
    window:gui_window():maximize()
    local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
    resurrect.state_manager.resurrect_on_gui_startup()
end)

local function main()
    local color_scheme = "Earthsong"
    local plugins = load_plugins()
    local colors = require("colors").configure_colors(color_scheme)

    local config = {
        default_workspace = "~",
        color_scheme = color_scheme,
        colors = colors,
        font = wezterm.font_with_fallback({
            { family = "Iosevka Term",          weight = "Regular" },
            { family = "Symbols Nerd Font Mono" },
        }),
        font_size = 18,
        window_frame = { font_size = 12 },
        command_palette_font_size = 16,
        window_background_opacity = 0.97,
        window_decorations = "RESIZE",
        front_end = "WebGpu",
        freetype_load_target = "Light",
        freetype_render_target = "HorizontalLcd",
        tab_bar_at_bottom = true,
        use_fancy_tab_bar = false,
        hide_tab_bar_if_only_one_tab = false,
        tab_max_width = 30,
        native_macos_fullscreen_mode = true,
        leader = { key = "L", mods = "ALT|SHIFT", timeout_milliseconds = 2000 },
        key_map_preference = "Physical",
        enable_kitty_keyboard = true,
        term = "wezterm",
        keys = keybinds.configure_keys(plugins.resurrect, plugins.workspace_switcher),
    }

    workspaces.configure_workspaces(plugins.resurrect, plugins.workspace_switcher, colors)
    configure_ssh(config)
    configure_status(config)
    plugins.domains.apply_to_config(config, {
        keys = {
            attach = { key = "d", mods = "LEADER", tbl = "" },
        },
        auto = {
            ssh_ignore = true,
        },
    })
    return config
end

return main()