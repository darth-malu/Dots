-- Monitors
-- This is for .config/hyprland/hyprland.lua
require("animations")
require("decoration")
require("device")
require("general")
require("gesture")
require("Hyprland-environment-variables")
require("input")
require("keybinds")
require("layouts")
require("misc")
require("rules")
require("submaps")
require("window_workspace_rules")

hl.monitor({
        output = "HDMI-A-1",
        mode = "1920x1080@240",
        position = "0x0",
        scale = 1,
        cm = "auto", -- srgb::, auto(recommended)
})

-- programs?? SEE IF CONFLICTS

local terminal = "kitty"
local filemanager = "dolphin"
