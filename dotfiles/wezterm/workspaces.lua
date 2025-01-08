local wezterm = require("wezterm")

local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")

local colors = wezterm.color.get_builtin_schemes()["Earthsong"]

local function basename(s)
    return string.gsub(s, "(.*[/\\])(.*)", "%2")
end

local function workspaces(config)
    resurrect.periodic_save({ interval_seconds = 15 * 60, save_workspaces = true, save_windows = true, save_tabs = true })
    resurrect.set_max_nlines(5000)

    wezterm.on("resurrect.error", function(err)
        wezterm.log_error("ERROR!")
        wezterm.gui.gui_windows()[1]:toast_notification("resurrect", err, nil, 3000)
    end)

    workspace_switcher.workspace_formatter = function(label)
        return wezterm.format({
            { Attribute = { Italic = true } },
            { Foreground = { Color = colors.ansi[3] } },
            { Background = { Color = colors.background } },
            { Text = "󱂬 : " .. label },
        })
    end

    wezterm.on("smart_workspace_switcher.workspace_switcher.created", function(window, path, label)
        wezterm.log_info("Created workspace: " .. label)
        window:gui_window():set_right_status(wezterm.format({
            { Attribute = { Intensity = "Bold" } },
            { Foreground = { Color = colors.ansi[5] } },
            { Text = basename(path) .. "  " },
        }))
        local workspace_state = resurrect.workspace_state

        workspace_state.restore_workspace(resurrect.load_state(label, "workspace"), {
            window = window,
            relative = true,
            restore_text = true,
            on_pane_restore = resurrect.tab_state.default_on_pane_restore,
        })
    end)

    wezterm.on("smart_workspace_switcher.workspace_switcher.chosen", function(window, path, label)
        wezterm.log_info("Chosen workspace: " .. label .. window)
        window:gui_window():set_right_status(wezterm.format({
            { Attribute = { Intensity = "Bold" } },
            { Foreground = { Color = colors.ansi[5] } },
            { Text = basename(path) .. "  " },
        }))
    end)

    wezterm.on("smart_workspace_switcher.workspace_switcher.selected", function(window, path, label)
        wezterm.log_info("Selected workspace: " .. label)
        local workspace_state = resurrect.workspace_state
        resurrect.save_state(workspace_state.get_workspace_state())
        resurrect.write_current_state(label, "workspace")
    end)

    wezterm.on("smart_workspace_switcher.workspace_switcher.start", function(window, _)
        wezterm.log_info(window)
    end)

    wezterm.on("smart_workspace_switcher.workspace_switcher.canceled", function(window, _)
        wezterm.log_info(window)
    end)

    wezterm.on("gui-startup", resurrect.resurrect_on_gui_startup)
end

return workspaces