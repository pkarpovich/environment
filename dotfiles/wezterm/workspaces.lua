local wezterm = require("wezterm")

local pub = {}

local function configure_workspaces(resurrect)
    resurrect.state_manager.periodic_save({
        interval_seconds = 120,
        save_workspaces = true,
        save_windows = true,
        save_tabs = true,
    })
    resurrect.state_manager.set_max_nlines(5000)

    wezterm.on("resurrect.error", function(err)
        wezterm.log_error("resurrect error: " .. tostring(err))
        local gw = wezterm.gui.gui_windows()[1]
        if gw then gw:toast_notification("resurrect", err, nil, 3000) end
    end)

    local last_current_write = 0
    wezterm.on("update-status", function(window)
        local now = os.time()
        if now - last_current_write < 60 then
            return
        end
        last_current_write = now
        local ws = window:active_workspace()
        if ws and ws ~= "" then
            resurrect.state_manager.write_current_state(ws, "workspace")
        end
    end)
end

pub.configure_workspaces = configure_workspaces

return pub
