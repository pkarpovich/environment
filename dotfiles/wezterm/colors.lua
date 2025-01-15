local wezterm = require("wezterm")

local pub = {}

local function mergeTables(t1, t2)
    for key, value in pairs(t2) do
        t1[key] = value
    end
end

local function configure_colors(color_scheme)
    return wezterm.color.get_builtin_schemes()[color_scheme]
end

pub.configure_colors = configure_colors

return pub