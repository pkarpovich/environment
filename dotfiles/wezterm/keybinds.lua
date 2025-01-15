local wezterm = require("wezterm")
local act = wezterm.action

local pub = {}

local function configure_keys(resurrect, workspace_switcher)
    local keys = {
        { key = "Enter", mods = "ALT",         action = "DisableDefaultAssignment" },
        { key = "p",     mods = "SHIFT|SUPER", action = act.ActivateCommandPalette },
        {
            key = "|",
            mods = "SHIFT|ALT",
            action = act({ SplitHorizontal = { domain = "CurrentPaneDomain" } }),
        },
        {
            key = "_",
            mods = "SHIFT|ALT",
            action = act({ SplitVertical = { domain = "CurrentPaneDomain" } }),
        },
        { key = "LeftArrow",  mods = "ALT|SHIFT", action = act({ ActivatePaneDirection = "Left" }) },
        { key = "RightArrow", mods = "ALT|SHIFT", action = act({ ActivatePaneDirection = "Right" }) },
        { key = "UpArrow",    mods = "ALT|SHIFT", action = act({ ActivatePaneDirection = "Up" }) },
        { key = "DownArrow",  mods = "ALT|SHIFT", action = act({ ActivatePaneDirection = "Down" }) },
        {
            -- Delete a saved session using a fuzzy finder
            key = 'd',
            mods = 'LEADER',
            action = wezterm.action_callback(function(win, pane)
                resurrect.fuzzy_load(
                    win,
                    pane,
                    function(id)
                        resurrect.delete_state(id)
                    end,
                    {
                        title             = 'Delete State',
                        description       = 'Select session to delete and press Enter = accept, Esc = cancel, / = filter',
                        fuzzy_description = 'Search session to delete: ',
                        is_fuzzy          = true,
                    }
                )
            end),
        },
        {
            key = 'r',
            mods = 'LEADER',
            action = wezterm.action.PromptInputLine({
                description = wezterm.format({
                    { Attribute = { Intensity = "Bold" } },
                    { Foreground = { AnsiColor = "Fuchsia" } },
                    { Text = "Renaming Current Workspace Titlel:" },
                }),
                action = wezterm.action_callback(function(window, _, line)
                    if line then
                        local current_name = wezterm.mux.get_active_workspace()
                        wezterm.mux.rename_workspace(current_name, line)
                        resurrect.save_state(resurrect.workspace_state.get_workspace_state())
                        resurrect.delete_state(current_name)
                    end
                end),
            }),
        },
        {
            key = 'u',
            mods = 'LEADER',
            action = wezterm.action_callback(function()
                wezterm.plugin.update_all()
                wezterm.log_info("Plugins updated")
            end),
        },
        {
            key = "w",
            mods = "LEADER",
            action = act.ShowLauncherArgs({ flags = "WORKSPACES", title = "workspaces" }),
        },
        {
            key = "s",
            mods = "LEADER",
            action = workspace_switcher.switch_workspace()
        },
        {
            key = "c",
            mods = "LEADER",
            action = act.CloseCurrentPane { confirm = false },
        },
        {
            key = "C",
            mods = "LEADER",
            action = act.CloseCurrentTab { confirm = false },
        },
        {
            key = "t",
            mods = "LEADER",
            action = act.SpawnTab 'CurrentPaneDomain',
        }
    }

    local function tab_switch_keys(key_table, modifier)
        for i = 1, 9 do
            table.insert(key_table, {
                key = tostring(i),
                mods = modifier,
                action = act.ActivateTab(i - 1),
            })
        end
        table.insert(key_table, {
            key = "0",
            mods = modifier,
            action = act.ActivateTab(9),
        })
    end

    tab_switch_keys(keys, "LEADER")

    return keys
end

pub.configure_keys = configure_keys

return pub