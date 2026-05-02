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

function M.apply(_, opts)
    config = clone(defaults)
    if opts then
        deep_merge(config, opts)
    end
    cache = {}
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

return M
