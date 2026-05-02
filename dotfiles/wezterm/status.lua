local wezterm = require("wezterm")

local M = {}

local defaults = {
    dir = wezterm.home_dir .. "/.local/state/wezterm-status",
    leader_icon = utf8.char(0x1f30a),
    zoom_icon = utf8.char(0x1f50d),
    leader_color = "Blue",
    zoom_color = "Red",
    indicators = {
        thinking_frames = { "" },
        stop = "",
        notify = "",
        review = "",
    },
    colors = {
        thinking = "#d97706",
        stop = "#16a34a",
        notify = "#dc2626",
        review = false,
    },
    foreground = "#f5f5f5",
    priority = { "thinking", "review", "stop", "notify" },
    auto_clear = { stop = true, notify = true },
    min_width = 30,
}

local config = nil
local cache = {}
local handlers_registered = false

local allowed_types = { thinking = true, stop = true, notify = true, review = true }

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

local function is_list(t)
    if type(t) ~= "table" then
        return false
    end
    local n = #t
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count == n
end

local function deep_merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" and not is_list(v) and not is_list(dst[k]) then
            deep_merge(dst[k], v)
        elseif type(v) == "table" then
            dst[k] = clone(v)
        else
            dst[k] = v
        end
    end
    return dst
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
    for _, tab in ipairs(mux_window:tabs()) do
        for _, pane in ipairs(tab:panes()) do
            local pane_id = pane:pane_id()
            cache[pane_id] = read_marker(config.dir, pane_id)
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

local function build_right_status(window)
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

local function update_right_status(window)
    if not config or not window then
        return
    end
    local cells = build_right_status(window)
    if not window.set_right_status then
        return
    end
    if #cells == 0 then
        window:set_right_status("")
    else
        window:set_right_status(wezterm.format(cells))
    end
end

function M.remove_marker(pane_id)
    if not config then
        return
    end
    os.remove(config.dir .. "/" .. tostring(pane_id))
    cache[pane_id] = nil
end

local function auto_clear_marker(pane_id, expected_type)
    if not config then
        return
    end
    local current = read_marker(config.dir, pane_id)
    if current and current.type ~= expected_type then
        cache[pane_id] = current
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

local function pad_to_min(s, min_width)
    if not min_width or min_width <= 0 then
        return s
    end
    local w = visual_width(s)
    if w >= min_width then
        return s
    end
    return s .. string.rep(" ", min_width - w)
end

local function strip_cc_prefix(s)
    if not s then
        return ""
    end
    s = s:gsub("^%*%s*", "")
    s = s:gsub("^\xc2\xb7%s*", "")
    s = s:gsub("^\xe2\x80\xa2%s*", "")
    s = s:gsub("^\xe2[\x94-\x97][\x80-\xbf]%s*", "")
    s = s:gsub("^\xe2[\x9c-\x9e][\x80-\xbf]%s*", "")
    s = s:gsub("^\xe2[\xa0-\xa3][\x80-\xbf]%s*", "")
    return s
end

local function log_title(raw)
    if not config or not config.debug_log then
        return
    end
    local f = io.open(config.debug_log, "a")
    if not f then
        return
    end
    f:write(os.date("%H:%M:%S"), " ", tostring(raw or ""), "\n")
    f:close()
end

local function tab_title(tab)
    local t = tab.tab_title
    if t and t ~= "" then
        log_title(t)
        return strip_cc_prefix(t)
    end
    if tab.active_pane and tab.active_pane.title then
        log_title(tab.active_pane.title)
        return strip_cc_prefix(tab.active_pane.title)
    end
    return ""
end

local function format_tab(tab, _tabs, _panes, _conf, _hover, max_width)
    local attention = get_tab_attention(tab)
    local label = string.format("%d: %s", (tab.tab_index or 0) + 1, tab_title(tab))
    local budget = math.max(1, (max_width or 999) - 2)

    if tab.is_active then
        for _, pane in ipairs(tab.panes or {}) do
            local entry = cache[pane.pane_id]
            if entry and is_auto_clear(entry.type) then
                auto_clear_marker(pane.pane_id, entry.type)
            end
        end
        return pad_to_min(" " .. truncate(label, budget) .. " ", config.min_width)
    end

    local prefix = attention and attention.indicator or ""
    local text = pad_to_min(" " .. truncate(prefix .. label, budget) .. " ", config.min_width)
    if attention and attention.color then
        local cells = {
            { Background = { Color = attention.color } },
        }
        if config.foreground then
            table.insert(cells, { Foreground = { Color = config.foreground } })
        end
        table.insert(cells, { Text = text })
        return cells
    end
    return text
end

function M.apply(_, opts)
    config = clone(defaults)
    if opts then
        deep_merge(config, opts)
    end
    if type(config.auto_clear) == "table" and is_list(config.auto_clear) then
        local normalized = {}
        for _, name in ipairs(config.auto_clear) do
            normalized[name] = true
        end
        config.auto_clear = normalized
    end
    cache = {}
    if not handlers_registered then
        wezterm.on("update-status", function(window)
            M.poll(window)
            update_right_status(window)
        end)
        wezterm.on("format-tab-title", format_tab)
        handlers_registered = true
    end
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

function M._build_right_status(window)
    return build_right_status(window)
end

return M
