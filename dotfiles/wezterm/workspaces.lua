local wezterm = require("wezterm")

local pub = {}

local function basename(s)
    return string.gsub(s, "(.*[/\\])(.*)", "%2")
end

local function configure_workspaces(resurrect, workspace_switcher, colors)
    resurrect.state_manager.periodic_save({
        interval_seconds = 15 * 60,
        save_workspaces = true,
        save_windows = true,
        save_tabs = true,
    })
    resurrect.state_manager.set_max_nlines(5000)

    workspace_switcher.zoxide_path = "/opt/homebrew/bin/zoxide"
    workspace_switcher.workspace_formatter = function(label)
        return wezterm.format({
            { Attribute = { Italic = true } },
            { Foreground = { Color = colors.ansi[3] } },
            { Background = { Color = colors.background } },
            { Text = "󱂬 : " .. label },
        })
    end

    local function setup_event_handlers()
        wezterm.on("resurrect.error", function(err)
            wezterm.log_error("ERROR!")
            wezterm.gui.gui_windows()[1]:toast_notification("resurrect", err, nil, 3000)
        end)

        wezterm.on("smart_workspace_switcher.workspace_switcher.created", function(window, path, label)
            wezterm.log_info("Created workspace: " .. label)
            window:gui_window():set_right_status(wezterm.format({
                { Attribute = { Intensity = "Bold" } },
                { Foreground = { Color = colors.ansi[5] } },
                { Text = basename(path) .. "  " },
            }))
            resurrect.workspace_state.restore_workspace(resurrect.state_manager.load_state(label, "workspace"), {
                window = window,
                relative = true,
                restore_text = true,
                on_pane_restore = resurrect.tab_state.default_on_pane_restore,
            })
        end)

        wezterm.on("smart_workspace_switcher.workspace_switcher.chosen", function(window, path, label)
            wezterm.log_info("Chosen workspace: " .. label)
            window:gui_window():set_right_status(wezterm.format({
                { Attribute = { Intensity = "Bold" } },
                { Foreground = { Color = colors.ansi[5] } },
                { Text = basename(path) .. "  " },
            }))
        end)

        wezterm.on("smart_workspace_switcher.workspace_switcher.selected", function(_, _, label)
            wezterm.log_info("Selected workspace: " .. label)
            resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
            resurrect.state_manager.write_current_state(label, "workspace")
        end)

        wezterm.on("smart_workspace_switcher.workspace_switcher.start", function(window, _)
            wezterm.log_info(window)
        end)

        wezterm.on("smart_workspace_switcher.workspace_switcher.canceled", function(window, _)
            wezterm.log_info(window)
        end)
    end

    setup_event_handlers()
end

pub.configure_workspaces = configure_workspaces

return pub