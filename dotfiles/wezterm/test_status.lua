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

os.execute("rm -rf '" .. tmpdir .. "'")
print("OK")
