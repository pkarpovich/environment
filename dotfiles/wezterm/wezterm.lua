local wezterm = require("wezterm")
local keybinds = require("keybinds")
local workspaces = require("workspaces")

local function get_appearance()
    if wezterm.gui then
        return wezterm.gui.get_appearance()
    end
    return 'Dark'
end

local function scheme_for_appearance(appearance)
    if appearance:find("Dark") then
        return "Earthsong"
    else
        -- Codeschool (light) (terminal.sexy)
        -- Atelier Cave Light (base16)
        -- Atelier Cave Light (base16)
        return "Earthsong"
    end
end

local function load_plugins()
    return {
        bar = wezterm.plugin.require("https://github.com/adriankarlen/bar.wezterm"),
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

local function configure_plugins(config, plugins)
    plugins.bar.apply_to_config(config, {
        padding = {
            left = 2,
            right = 10,
        },
        separator = {
            space = 2,
        },
        modules = {
            tabs = {
                active_tab_fg = 2,
                inactive_tab_fg = 8,
            },
            leader = {
                enabled = true,
                icon = utf8.char(0x1f30a)
            },
            pane = { enabled = false },
            username = { enabled = false },
            hostname = { enabled = false },
            clock = { enabled = false },
        },
    })

    plugins.domains.apply_to_config(config)
end

local function configure_gui_startup(plugins)
    wezterm.on("gui-startup", function(cmd)
        wezterm.log_info("gui-startup")
        local _, _, window = wezterm.mux.spawn_window(cmd or {})
        window:gui_window():maximize()
        plugins.resurrect.resurrect_on_gui_startup()
    end)
end

local function main()
    local appearance = get_appearance()
    local color_scheme = scheme_for_appearance(appearance)
    local plugins = load_plugins()
    local colors = require("colors").configure_colors(color_scheme)

    local config = {
        default_workspace = "~",
        color_scheme = color_scheme,
        colors = colors,
        font = wezterm.font_with_fallback({
            { family = "Iosevka Nerd Font", weight = "Light" },
            { family = "Victor Mono",       weight = "Regular" },
        }),
        font_size = 18,
        window_frame = { font_size = 12 },
        command_palette_font_size = 16,
        cell_width = 0.9,
        window_background_opacity = 0.97,
        window_decorations = "RESIZE",
        front_end = "OpenGL",
        freetype_load_target = "Light",
        freetype_render_target = "HorizontalLcd",
        tab_bar_at_bottom = true,
        hide_tab_bar_if_only_one_tab = false,
        native_macos_fullscreen_mode = true,
        leader = { key = "L", mods = "ALT|SHIFT", timeout_milliseconds = 2000 },
        keys = keybinds.configure_keys(plugins.resurrect, plugins.workspace_switcher),
    }

    workspaces.configure_workspaces(plugins.resurrect, plugins.workspace_switcher, colors)
    configure_ssh(config)
    configure_plugins(config, plugins)
    configure_gui_startup(plugins)

    return config
end

return main()