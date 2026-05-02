local wezterm = require("wezterm")

local M = {}

local defaults = {
    dir = wezterm.home_dir .. "/.local/state/wezterm-status",
    leader_icon = utf8.char(0x1f30a),
    zoom_icon = "",
    leader_color = "Blue",
    zoom_color = "Red",
    indicators = {
        thinking_frames = { "◌ ", "◔ ", "◑ ", "◕ " },
        stop = "✓ ",
        notify = "! ",
        review = "◆ ",
    },
    colors = {
        thinking = false,
        stop = false,
        notify = false,
        review = false,
    },
    priority = { "thinking", "review", "stop", "notify" },
    auto_clear = { stop = true, notify = true },
}

local config = nil
local cache = {}

local allowed_types = { thinking = true, stop = true, notify = true, review = true }

local function deep_merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            deep_merge(dst[k], v)
        else
            dst[k] = v
        end
    end
    return dst
end

local function clone(t)
    local out = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            out[k] = clone(v)
        else
            out[k] = v
        end
    end
    return out
end

local function read_marker(dir, pane_id)
    local path = dir .. "/" .. tostring(pane_id)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local content = f:read("*a")
    f:close()
    if not content or content == "" then
        return nil
    end
    local ok, parsed = pcall(wezterm.json_parse, content)
    if not ok or type(parsed) ~= "table" then
        return nil
    end
    if not allowed_types[parsed.type] then
        return nil
    end
    if type(parsed.frame) ~= "number" then
        parsed.frame = nil
    end
    return parsed
end

function M.poll(window)
    if not config or not window then
        return
    end
    local mux_window = window.mux_window and window:mux_window() or window
    local seen = {}
    for _, tab in ipairs(mux_window:tabs()) do
        for _, pane in ipairs(tab:panes()) do
            local pane_id = pane:pane_id()
            seen[pane_id] = true
            cache[pane_id] = read_marker(config.dir, pane_id)
        end
    end
    for pane_id in pairs(cache) do
        if not seen[pane_id] then
            cache[pane_id] = nil
        end
    end
end

local function active_tab_is_zoomed(window)
    local mux_window = window.mux_window and window:mux_window() or window
    local active = mux_window.active_tab and mux_window:active_tab() or nil
    if not active or not active.panes_with_info then
        return false
    end
    for _, info in ipairs(active:panes_with_info()) do
        if info.is_zoomed then
            return true
        end
    end
    return false
end

local function build_left_status(window)
    local cells = {}
    if config.leader_icon and config.leader_icon ~= "" and window.leader_is_active and window:leader_is_active() then
        table.insert(cells, { Foreground = { AnsiColor = config.leader_color } })
        table.insert(cells, { Text = " " .. config.leader_icon .. " " })
    end
    if config.zoom_icon and config.zoom_icon ~= "" and active_tab_is_zoomed(window) then
        table.insert(cells, { Foreground = { AnsiColor = config.zoom_color } })
        table.insert(cells, { Text = " " .. config.zoom_icon .. " " })
    end
    return cells
end

local function update_left_status(window)
    if not config or not window then
        return
    end
    local cells = build_left_status(window)
    if not window.set_left_status then
        return
    end
    if #cells == 0 then
        window:set_left_status("")
    else
        window:set_left_status(wezterm.format(cells))
    end
end

function M.remove_marker(pane_id)
    if not config then
        return
    end
    os.remove(config.dir .. "/" .. tostring(pane_id))
    cache[pane_id] = nil
end

local function is_auto_clear(t)
    return config ~= nil and t ~= nil and config.auto_clear[t] == true
end

local function get_tab_attention(tab)
    if not config or not tab or not tab.panes then
        return nil
    end
    local best, best_pri
    for _, pane in ipairs(tab.panes) do
        local entry = cache[pane.pane_id]
        if entry then
            for i, name in ipairs(config.priority) do
                if entry.type == name then
                    if not best_pri or i < best_pri then
                        best, best_pri = entry, i
                    end
                    break
                end
            end
        end
    end
    if not best then
        return nil
    end
    local indicator
    if best.type == "thinking" then
        local frames = config.indicators.thinking_frames
        local n = frames and #frames or 0
        if n == 0 then
            return nil
        end
        local idx = ((best.frame or 1) - 1) % n + 1
        indicator = frames[idx]
    else
        indicator = config.indicators[best.type]
    end
    if not indicator then
        return nil
    end
    return { indicator = indicator, type = best.type, color = config.colors[best.type] }
end

local function visual_width(s)
    if wezterm.column_width then
        return wezterm.column_width(s)
    end
    return #s
end

local function truncate(s, max_width)
    if not max_width or max_width <= 0 then
        return s
    end
    if visual_width(s) <= max_width then
        return s
    end
    if max_width <= 1 then
        if wezterm.truncate_right then
            return wezterm.truncate_right(s, max_width)
        end
        return s:sub(1, max_width)
    end
    if wezterm.truncate_right then
        return wezterm.truncate_right(s, max_width - 1) .. "…"
    end
    return s:sub(1, max_width - 1) .. "…"
end

local function tab_title(tab)
    local t = tab.tab_title
    if t and t ~= "" then
        return t
    end
    if tab.active_pane and tab.active_pane.title then
        return tab.active_pane.title
    end
    return ""
end

local function format_tab(tab, _tabs, _panes, _conf, _hover, max_width)
    local attention = get_tab_attention(tab)
    local label = string.format("%d: %s", (tab.tab_index or 0) + 1, tab_title(tab))
    local budget = math.max(1, (max_width or 999) - 2)

    if tab.is_active then
        if attention and is_auto_clear(attention.type) then
            for _, pane in ipairs(tab.panes or {}) do
                local entry = cache[pane.pane_id]
                if entry and is_auto_clear(entry.type) then
                    M.remove_marker(pane.pane_id)
                end
            end
            attention = nil
        end
        return " " .. truncate(label, budget) .. " "
    end

    local prefix = attention and attention.indicator or ""
    local text = " " .. truncate(prefix .. label, budget) .. " "
    if attention and attention.color then
        return {
            { Background = { Color = attention.color } },
            { Text = text },
        }
    end
    return text
end

function M.apply(_, opts)
    config = clone(defaults)
    if opts then
        deep_merge(config, opts)
    end
    cache = {}
    wezterm.on("update-status", function(window)
        M.poll(window)
        update_left_status(window)
    end)
    wezterm.on("format-tab-title", format_tab)
    return config
end

function M.get_attention(pane_id)
    return cache[pane_id]
end

function M._config()
    return config
end

function M._cache()
    return cache
end

function M._read_marker(dir, pane_id)
    return read_marker(dir, pane_id)
end

function M._get_tab_attention(tab)
    return get_tab_attention(tab)
end

function M._format_tab(tab, tabs, panes, conf, hover, max_width)
    return format_tab(tab, tabs, panes, conf, hover, max_width)
end

function M._build_left_status(window)
    return build_left_status(window)
end

return M
