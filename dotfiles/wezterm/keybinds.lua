local wezterm = require("wezterm")
local act = wezterm.action

local pub = {}

local function resize_panes_to_ratio(window, pane, first_pane_ratio)
    local tab = window:active_tab()
    local panes = tab:panes_with_info()

    if #panes ~= 2 then
        return
    end

    local current_pane = pane
    tab:set_zoomed(false)
    
    -- Add tolerance to prevent infinite adjustments
    local tolerance = 2  -- pixels
    
    -- Find which pane is active
    local active_pane_index = 1
    for i, p in ipairs(panes) do
        if p.is_active then
            active_pane_index = i
            break
        end
    end
    
    -- Adjust ratio based on which pane is active
    -- If second pane is active, we need to invert the ratio
    local target_ratio = active_pane_index == 1 and first_pane_ratio or (1 - first_pane_ratio)

    -- Determine if panes are split horizontally or vertically
    -- In a horizontal split, panes are side by side (different x positions)
    -- In a vertical split, panes are stacked (different y positions)
    local is_horizontal = panes[1].left ~= panes[2].left

    if is_horizontal then
        -- Calculate total width and target sizes
        local total_width = panes[1].width + panes[2].width
        local target_first_width = math.floor(total_width * target_ratio)
        local current_first_width = panes[1].width
        local adjustment = target_first_width - current_first_width

        -- Only adjust if difference is greater than tolerance
        if math.abs(adjustment) > tolerance then
            -- Activate first pane and adjust
            panes[1].pane:activate()
            if adjustment > 0 then
                window:perform_action(
                    wezterm.action.AdjustPaneSize({ "Right", adjustment }),
                    panes[1].pane
                )
            elseif adjustment < 0 then
                window:perform_action(
                    wezterm.action.AdjustPaneSize({ "Left", -adjustment }),
                    panes[1].pane
                )
            end
        end
    else
        -- For vertical split
        local total_height = panes[1].height + panes[2].height
        local target_first_height = math.floor(total_height * target_ratio)
        local current_first_height = panes[1].height
        local adjustment = target_first_height - current_first_height

        -- Only adjust if difference is greater than tolerance
        if math.abs(adjustment) > tolerance then
            panes[1].pane:activate()
            if adjustment > 0 then
                window:perform_action(
                    wezterm.action.AdjustPaneSize({ "Down", adjustment }),
                    panes[1].pane
                )
            elseif adjustment < 0 then
                window:perform_action(
                    wezterm.action.AdjustPaneSize({ "Up", -adjustment }),
                    panes[1].pane
                )
            end
        end
    end

    -- Return to original pane
    current_pane:activate()
end

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
            key = "}",
            mods = "ALT|SHIFT",
            action = wezterm.action_callback(function(window, pane)
                resize_panes_to_ratio(window, pane, 0.333)
            end),
        },
        {
            key = "{",
            mods = "ALT|SHIFT",
            action = wezterm.action_callback(function(window, pane)
                resize_panes_to_ratio(window, pane, 0.667)
            end),
        },
        {
            key = "P",
            mods = "ALT|SHIFT",
            action = wezterm.action_callback(function(window, pane)
                resize_panes_to_ratio(window, pane, 0.5)
            end),
        },
        {
            key = "O",
            mods = "ALT|SHIFT",
            action = wezterm.action_callback(function(window, pane)
                resize_panes_to_ratio(window, pane, 0.25)
            end),
        },
        {
            key = 'LeftArrow',
            mods = 'CMD',
            action = wezterm.action { SendString = "\x1bOH" },
        },
        {
            key = 'RightArrow',
            mods = 'CMD',
            action = wezterm.action { SendString = "\x1bOF" },
        },
        {
            key = 'Backspace',
            mods = 'CMD',
            action = wezterm.action { SendString = "\x15" },
        },
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