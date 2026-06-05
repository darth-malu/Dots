require("hyprland_environment_variables")
require("devices")
require("animations")
require("decoration")
require("general")
-- require("gesture")
require("keybinds.keybinds") --Has other imports inside it
require("layouts")
require("rules")
require("misc")
-- require("keybinds.submaps")

local f = io.popen("hostname")
local hostname = f and f:read("*a"):gsub("%s+", "") or "default"
if f then f:close() end

if hostname == "carthage" then
  -- require("animations")
  require("carthage")
elseif hostname == "tangier" then
  require("tangier")
end
-- programs?? SEE IF CONFLICTS


hl.on("hyprland.start", function()
  hl.exec_cmd("app2unit -s a kitty")
  hl.exec_cmd("[workspace special:easy silent] app2unit -s a easyeffects")
  -- hl.exec_cmd("dbus-update-activation-environment --systemd --all")
  -- hl.exec_cmd("systemctl --user import-environment QT_QPA_PLATFORMTHEME")
end)
