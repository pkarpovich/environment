#!/usr/bin/env lua

local tmpdir = os.getenv("TMPDIR") or "/tmp"
tmpdir = tmpdir:gsub("/$", "") .. "/wezterm-status-test-" .. tostring(os.time()) .. "-" .. tostring(math.random(1, 1e6))
os.execute("mkdir -p '" .. tmpdir .. "'")

local handlers = {}

local wezterm_stub = {
    home_dir = os.getenv("HOME") or "/tmp",
    on = function(event, cb)
        handlers[event] = cb
    end,
    json_parse = function(s)
        local lua_src = s:gsub('"([%w_]+)"%s*:', "%1="):gsub("null", "nil")
        local loader = load or loadstring
        local f, err = loader("return " .. lua_src)
        if not f then
            error("parse failed: " .. tostring(err))
        end
        return f()
    end,
    column_width = function(s)
        return #s
    end,
    truncate_right = function(s, n)
        return s:sub(1, n)
    end,
    format = function(cells)
        local out = {}
        for _, c in ipairs(cells) do
            if type(c) == "table" and c.Text then
                table.insert(out, c.Text)
            end
        end
        return table.concat(out)
    end,
}

package.preload["wezterm"] = function()
    return wezterm_stub
end

if not utf8 then
    utf8 = { char = function(_) return "?" end }
end

package.path = (debug.getinfo(1, "S").source:match("@(.*/)") or "./") .. "?.lua;" .. package.path

local status = require("status")

local function fail(msg)
    io.stderr:write("FAIL: " .. msg .. "\n")
    os.exit(1)
end

local function assert_eq(got, want, msg)
    if got ~= want then
        fail((msg or "assert_eq") .. " — got=" .. tostring(got) .. " want=" .. tostring(want))
    end
end

local function write_marker(pane_id, body)
    local path = tmpdir .. "/" .. tostring(pane_id)
    local f = assert(io.open(path, "w"))
    f:write(body)
    f:close()
end

status.apply(nil, { dir = tmpdir })

assert_eq(handlers["update-status"] ~= nil, true, "update-status handler registered")
assert_eq(handlers["pane-destroyed"] ~= nil, true, "pane-destroyed handler registered")

local m = status._read_marker(tmpdir, 999)
assert_eq(m, nil, "missing file returns nil")

write_marker(1, '{"type":"thinking","frame":2}')
local parsed = status._read_marker(tmpdir, 1)
assert(parsed, "valid marker parsed")
assert_eq(parsed.type, "thinking", "type=thinking")
assert_eq(parsed.frame, 2, "frame=2")

write_marker(2, '{"type":"bogus"}')
assert_eq(status._read_marker(tmpdir, 2), nil, "bogus type rejected")

write_marker(3, "not json at all")
assert_eq(status._read_marker(tmpdir, 3), nil, "garbage rejected")

write_marker(4, "")
assert_eq(status._read_marker(tmpdir, 4), nil, "empty file rejected")

write_marker(10, '{"type":"stop"}')
write_marker(11, '{"type":"notify"}')

local function fake_pane(id)
    return { pane_id = function() return id end }
end
local function fake_tab(panes)
    return { panes = function() return panes end }
end
local function fake_window(tabs)
    return {
        mux_window = function(self) return self end,
        tabs = function() return tabs end,
    }
end

local window = fake_window({
    fake_tab({ fake_pane(10), fake_pane(11) }),
})

handlers["update-status"](window)

local cache = status._cache()
assert(cache[10], "pane 10 cached")
assert_eq(cache[10].type, "stop", "pane 10 type")
assert(cache[11], "pane 11 cached")
assert_eq(cache[11].type, "notify", "pane 11 type")

assert_eq(status.get_attention(10).type, "stop", "get_attention works")

os.remove(tmpdir .. "/10")
handlers["update-status"](window)
assert_eq(status._cache()[10], nil, "pane 10 cleared after marker removed")
assert(status._cache()[11], "pane 11 still cached")

handlers["pane-destroyed"](nil, fake_pane(11))
assert_eq(status._cache()[11], nil, "pane 11 cleared after destroy")

write_marker(11, '{"type":"stop"}')
local stat_check = io.open(tmpdir .. "/11", "r")
assert_eq(stat_check ~= nil, true, "pre-check: file exists")
stat_check:close()
status.remove_marker(11)
assert_eq(io.open(tmpdir .. "/11", "r"), nil, "remove_marker deletes file")

write_marker(20, '{"type":"thinking"}')
handlers["update-status"](fake_window({ fake_tab({ fake_pane(20) }) }))
assert(status._cache()[20], "pane 20 cached")
handlers["update-status"](fake_window({ fake_tab({}) }))
assert_eq(status._cache()[20], nil, "stale cache pruned when pane absent")

assert_eq(handlers["format-tab-title"] ~= nil, true, "format-tab-title handler registered")

local function fake_tab_info(opts)
    return {
        tab_index = opts.tab_index or 0,
        is_active = opts.is_active or false,
        tab_title = opts.tab_title,
        active_pane = opts.active_pane,
        panes = opts.panes or {},
    }
end
local function pane_info(id, title)
    return { pane_id = id, title = title or "" }
end

for k in pairs(status._cache()) do
    status._cache()[k] = nil
end

local tab_no_marker = fake_tab_info({
    tab_index = 0,
    is_active = false,
    active_pane = pane_info(100, "shell"),
    panes = { pane_info(100, "shell") },
})
assert_eq(status._get_tab_attention(tab_no_marker), nil, "no marker -> no attention")

write_marker(101, '{"type":"thinking","frame":2}')
write_marker(102, '{"type":"stop"}')
handlers["update-status"](fake_window({
    fake_tab({ fake_pane(101), fake_pane(102) }),
}))

local tab_priority = fake_tab_info({
    tab_index = 1,
    is_active = false,
    active_pane = pane_info(101, "build"),
    panes = { pane_info(101, "build"), pane_info(102, "log") },
})
local att = status._get_tab_attention(tab_priority)
assert(att, "attention returned")
assert_eq(att.type, "thinking", "thinking has higher priority than stop")
assert_eq(att.indicator, "◔ ", "thinking frame=2 -> second frame")

local rendered = handlers["format-tab-title"](tab_priority, {}, {}, {}, false, 80)
assert_eq(type(rendered), "string", "no color tint -> plain string")
assert(rendered:find("◔"), "rendered string contains thinking indicator")
assert(rendered:find("2: build"), "rendered string contains index and title")

local stop_only_tab = fake_tab_info({
    tab_index = 2,
    is_active = false,
    active_pane = pane_info(102, "log"),
    panes = { pane_info(102, "log") },
})
local stop_att = status._get_tab_attention(stop_only_tab)
assert(stop_att, "stop attention returned")
assert_eq(stop_att.type, "stop", "stop type")
assert_eq(stop_att.indicator, "✓ ", "stop indicator")

local tinted_tab = fake_tab_info({
    tab_index = 3,
    is_active = false,
    active_pane = pane_info(102, "log"),
    panes = { pane_info(102, "log") },
})
status._config().colors.stop = "#ff0000"
local rendered_tint = handlers["format-tab-title"](tinted_tab, {}, {}, {}, false, 80)
assert_eq(type(rendered_tint), "table", "color tint -> format cells")
assert_eq(rendered_tint[1].Background.Color, "#ff0000", "Background color cell")
status._config().colors.stop = false

write_marker(101, '{"type":"thinking","frame":2}')
write_marker(102, '{"type":"stop"}')
handlers["update-status"](fake_window({
    fake_tab({ fake_pane(101), fake_pane(102) }),
}))
assert(status._cache()[102], "stop cached pre-active")
local active_tab = fake_tab_info({
    tab_index = 4,
    is_active = true,
    active_pane = pane_info(102, "log"),
    panes = { pane_info(102, "log") },
})
local rendered_active = handlers["format-tab-title"](active_tab, {}, {}, {}, false, 80)
assert_eq(type(rendered_active), "string", "active tab returns plain string")
assert(not rendered_active:find("✓"), "active tab strips stop indicator after auto-clear")
assert_eq(status._cache()[102], nil, "stop marker auto-cleared on active tab")
assert_eq(io.open(tmpdir .. "/102", "r"), nil, "stop marker file removed on auto-clear")

write_marker(103, '{"type":"thinking"}')
handlers["update-status"](fake_window({
    fake_tab({ fake_pane(103) }),
}))
local active_thinking = fake_tab_info({
    tab_index = 5,
    is_active = true,
    active_pane = pane_info(103, "build"),
    panes = { pane_info(103, "build") },
})
handlers["format-tab-title"](active_thinking, {}, {}, {}, false, 80)
assert(status._cache()[103], "thinking marker NOT auto-cleared on active tab")

local long_title = string.rep("x", 200)
local long_tab = fake_tab_info({
    tab_index = 0,
    is_active = false,
    active_pane = pane_info(200, long_title),
    panes = { pane_info(200, long_title) },
})
local rendered_long = handlers["format-tab-title"](long_tab, {}, {}, {}, false, 12)
assert_eq(type(rendered_long), "string", "long title rendered")
assert(rendered_long:find("…"), "long title gets ellipsis")
assert(#rendered_long <= 14, "long title respects max_width budget (got=" .. #rendered_long .. ")")

local function fake_window_status(opts)
    opts = opts or {}
    local left_status_capture = {}
    local mux = {
        tabs = function() return opts.tabs or {} end,
        active_tab = function()
            return opts.active_tab
        end,
    }
    local win = {
        mux_window = function(self) return mux end,
        leader_is_active = function() return opts.leader == true end,
        set_left_status = function(self, s)
            left_status_capture[1] = s
        end,
    }
    return win, left_status_capture
end

local function fake_active_tab(zoom_flags)
    return {
        panes_with_info = function()
            local out = {}
            for _, z in ipairs(zoom_flags) do
                table.insert(out, { is_zoomed = z })
            end
            return out
        end,
        panes = function() return {} end,
    }
end

local idle_win, idle_capture = fake_window_status({
    leader = false,
    active_tab = fake_active_tab({ false }),
})
handlers["update-status"](idle_win)
assert_eq(idle_capture[1], "", "idle window: empty left status")

local cfg = status._config()
local prev_leader_icon = cfg.leader_icon
cfg.leader_icon = "L"
cfg.zoom_icon = "Z"

local lead_win, lead_capture = fake_window_status({
    leader = true,
    active_tab = fake_active_tab({ false }),
})
handlers["update-status"](lead_win)
assert(lead_capture[1] and lead_capture[1]:find("L"), "leader active: icon present (got=" .. tostring(lead_capture[1]) .. ")")
assert(not lead_capture[1]:find("Z"), "leader active no zoom: zoom absent")

local zoom_win, zoom_capture = fake_window_status({
    leader = false,
    active_tab = fake_active_tab({ false, true }),
})
handlers["update-status"](zoom_win)
assert(zoom_capture[1] and zoom_capture[1]:find("Z"), "zoomed: icon present")
assert(not zoom_capture[1]:find("L"), "no leader: icon absent")

local both_win, both_capture = fake_window_status({
    leader = true,
    active_tab = fake_active_tab({ true }),
})
handlers["update-status"](both_win)
assert(both_capture[1]:find("L") and both_capture[1]:find("Z"), "both leader and zoom present")
assert(both_capture[1]:find("L") < both_capture[1]:find("Z"), "leader before zoom")

local cells = status._build_left_status(both_win)
local foreground_seen = false
for _, c in ipairs(cells) do
    if type(c) == "table" and c.Foreground and c.Foreground.AnsiColor then
        foreground_seen = true
    end
end
assert_eq(foreground_seen, true, "build_left_status emits Foreground cells")

cfg.leader_icon = prev_leader_icon
cfg.zoom_icon = ""

os.execute("rm -rf '" .. tmpdir .. "'")
print("OK")
