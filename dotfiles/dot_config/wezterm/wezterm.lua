local wezterm = require("wezterm")
local keybinds = require("keybinds")
local workspaces = require("workspaces")
local status = require("status")

local function load_plugins()
    return {
        domains = wezterm.plugin.require("https://github.com/DavidRR-F/quick_domains.wezterm"),
        resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm"),
    }
end

local function configure_ssh(config)
    local onep_auth = string.format("%s/.1password/agent.sock", wezterm.home_dir)
    if #wezterm.glob(onep_auth) == 1 then
        config.default_ssh_auth_sock = onep_auth
    end
end

local function mosh_domain(name, host)
    return wezterm.exec_domain(name, function(cmd)
        cmd.args = { "/opt/homebrew/bin/mosh", host }
        -- the GUI inherits launchd's PATH, which has no /opt/homebrew/bin; mosh is a
        -- perl script that has to find mosh-client on it
        local env = cmd.set_environment_variables or {}
        env.PATH = "/opt/homebrew/bin:" .. (env.PATH or "/usr/bin:/bin")
        cmd.set_environment_variables = env
        return cmd
    end, "mosh " .. host)
end

local function configure_mosh(config)
    config.exec_domains = { mosh_domain("mosh-mbp", "mbp-2021") }
end

local function configure_status(config)
    status.apply(config, {})
end

wezterm.on("gui-startup", function(cmd)
    local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
    local ok = resurrect.state_manager.resurrect_on_gui_startup()
    local windows = wezterm.mux.all_windows()
    if not ok or #windows == 0 then
        local _, _, window = wezterm.mux.spawn_window(cmd or {})
        window:gui_window():maximize()
    else
        for _, w in ipairs(windows) do
            local gw = w:gui_window()
            if gw then gw:maximize() end
        end
    end
end)

local function main()
    local color_scheme = "Earthsong"
    local plugins = load_plugins()
    local colors = require("colors").configure_colors(color_scheme)
    colors.tab_bar = colors.tab_bar or {}
    colors.tab_bar.active_tab = colors.tab_bar.active_tab or {}
    colors.tab_bar.active_tab.bg_color = "#5e4b9c"
    colors.tab_bar.active_tab.fg_color = "#e0def4"

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
        leader = { key = "L", mods = "CMD|SHIFT", timeout_milliseconds = 2000 },
        key_map_preference = "Physical",
        enable_kitty_keyboard = true,
        keys = keybinds.configure_keys(plugins.resurrect),
    }

    workspaces.configure_workspaces(plugins.resurrect)
    configure_ssh(config)
    configure_mosh(config)
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