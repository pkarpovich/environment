local red = "\27[31m"
local grn = "\27[32m"
local yel = "\27[33m"
local blu = "\27[34m"
local mag = "\27[35m"
local wht = "\27[37m"
local bold = "\27[1m"
local res = "\27[0m"

local turtle = {
    grn .. "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⣀⣀⣀⠀⠀⠀⠀" .. res,
    grn .. "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡴⠊⠁⠀⠀⠀⠀⠈⠙⢦⡀⠀" .. res,
    grn .. "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡜⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢳⠀" .. res,
    grn .. "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⡇" .. res,
    grn .. "⠀⠀⠀⠀⠀⠀⠀⣀⠤⢄⣀⠀⠀⠀⡇⠀⠀⠀⠀⢰⣶⠄⠀⠀⠀⠀⡇" .. res,
    grn .. "⠀⠀⠀⠀⠀⡴⡋⠀⠀⠀⡨⠓⣄⠀⢳⠀⠀⠀⠀⠀⠉⠀⠀⠀⢀⡼⠀" .. res,
    grn .. "⠀⠀⠀⢀⡞⠀⢸⠓⠒⢺⡀⠀⠈⢣⠈⡇⠀⠀⠀⠀⠀⢠⡤⠴⠋⠀⠀" .. res,
    grn .. "⠀⠀⠀⡼⠒⠒⢏⠀⠀⠀⠙⣦⠖⠉⢧⡿⠀⠈⠙⡖⠚⠉⠀⠀⠀⠀⠀" .. res,
    grn .. "⠀⠀⡖⢧⡀⠀⠈⣦⡤⠤⠊⡏⣀⡴⠊⡹⠀⣠⠞⠀⠀⠀⠀⠀⠀⠀⠀" .. res,
    grn .. "⢶⡞⡟⠦⣌⡓⠾⠥⠤⠴⠒⠋⣁⠴⢊⣤⠞⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀" .. res,
    grn .. "⠀⠀⡇⠀⠀⢉⣙⣒⣒⣒⣒⣉⠁⠀⢣⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀" .. res,
    grn .. "⠀⠀⠙⠒⠒⠚      ⠓⠚⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀" .. res,
}

-- Terminal width detection and responsive layout
local function get_terminal_width()
    -- Method 1: Use stty (more reliable than tput in WezTerm)
    local handle = io.popen("stty size 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        if result and result ~= "" then
            local rows, cols = result:match("(%d+)%s+(%d+)")
            if cols then
                local num_width = tonumber(cols)
                if num_width and num_width > 0 and num_width ~= 80 then
                    return num_width
                end
            end
        end
    end

    -- Method 2: Try tput cols with stderr redirection
    local handle = io.popen("{ tput cols; } 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        if result and result ~= "" then
            local cleaned = result:gsub("%s+", "")
            local num_width = tonumber(cleaned)
            if num_width and num_width > 0 and num_width ~= 80 then
                return num_width
            end
        end
    end

    -- If we got 80 from both methods, it might be the WezTerm startup issue
    -- Try to detect if this is actually an 80-column terminal or just the default
    local term = os.getenv("TERM")
    if term and term:find("wezterm") then
        -- For WezTerm, assume we're probably not actually 80 columns wide
        -- Use a more conservative layout
        return 100 -- Reasonable assumption for modern terminals
    end

    return 80 -- Default fallback
end

-- Text truncation helper
local function truncate(text, max_len)
    if #text <= max_len then
        return text
    end
    return text:sub(1, max_len - 3) .. "..."
end

-- Get responsive configuration
local term_width = get_terminal_width()
local turtle_width = 40   -- Approximate width of turtle ASCII art
local min_info_width = 30 -- Minimum space needed for info text

-- Determine layout mode
local vertical_layout = term_width < (turtle_width + min_info_width + 6)
local spacing = vertical_layout and "" or (term_width < 100 and "  " or "      ")

-- Responsive hostname truncation
local hostname = yafetch.hostname()
local max_hostname_len = math.min(60, math.max(30, term_width - turtle_width - 5))
if #hostname > max_hostname_len then
    hostname = truncate(hostname, max_hostname_len)
end

local header = bold .. grn .. yafetch.user() .. res .. bold .. "@" .. bold .. red .. hostname .. res

-- Responsive labels and values
local function format_info_line(label, value, max_value_len)
    if term_width < 80 then
        -- Use shorter labels for narrow terminals
        label = label:gsub("distro", "os"):gsub("memory", "mem"):gsub("battery", "bat"):gsub("local ip", "ip")
    end

    if max_value_len and #value > max_value_len then
        value = truncate(value, max_value_len)
    end

    return blu .. label .. string.rep(" ", math.max(1, 13 - #label)) .. res .. bold .. wht .. value .. res
end

-- Adjust max value length based on terminal width, with special handling for OS info
local max_value_len = term_width < 80 and 30 or (term_width < 100 and 40 or nil)
local os_max_len = term_width < 80 and 35 or (term_width < 100 and 50 or nil)

local info = {
    res .. res,
    res .. res,
    header,
    res .. res,
    format_info_line("distro", yafetch.os(), max_value_len),
    format_info_line("cpu", yafetch.cpu(), max_value_len),
    format_info_line("memory", yafetch.mem_used() .. " / " .. yafetch.mem_total(), max_value_len),
    format_info_line("disk", yafetch.disk_free("/") .. " / " .. yafetch.disk_total("/"), max_value_len),
    format_info_line("battery", yafetch.battery(), max_value_len),
    format_info_line("local ip", yafetch.local_ip(), max_value_len),
    format_info_line("uptime", yafetch.uptime(), max_value_len),
    format_info_line("date/time", yafetch.current_datetime(), max_value_len),
}

if vertical_layout then
    -- Vertical layout: turtle above info
    for i = 1, #turtle do
        print(turtle[i])
    end
    print("")
    for i = 1, #info do
        if info[i] ~= (res .. res) then -- Skip empty lines
            print(info[i])
        end
    end
else
    -- Horizontal layout: turtle beside info
    local max_lines = math.max(#turtle, #info)
    for i = 1, max_lines do
        local turtle_line = turtle[i] or string.rep(" ", turtle_width)
        local info_line = info[i] or ""
        print(turtle_line .. spacing .. info_line)
    end
end