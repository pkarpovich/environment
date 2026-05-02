local wezterm = require("wezterm")

local M = {}

local defaults = {
    dir = wezterm.home_dir .. "/.local/state/wezterm-status",
    leader_icon = utf8.char(0x1f30a),
    zoom_icon = "",
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
    auto_clear = { "stop", "notify" },
    review_key = { key = "b", mods = "ALT" },
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

function M.remove_marker(pane_id)
    if not config then
        return
    end
    os.remove(config.dir .. "/" .. tostring(pane_id))
    cache[pane_id] = nil
end

function M.apply(_, opts)
    config = clone(defaults)
    if opts then
        deep_merge(config, opts)
    end
    cache = {}
    wezterm.on("update-status", function(window)
        M.poll(window)
    end)
    wezterm.on("pane-destroyed", function(_, pane)
        if pane then
            M.remove_marker(pane:pane_id())
        end
    end)
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

return M
