require("hyprland_environment_variables")
require("devices")
require("animations")
require("decoration")
require("general")
-- require("gesture")
require("keybinds.keybinds")    --Has other imports inside it
require("layouts")
require("rules")
require("misc")
-- require("keybinds.submaps")

-- programs?? SEE IF CONFLICTS

-- dbus-update-activation-environment --systemd --all
-- systemctl --user import-environment QT_QPA_PLATFORMTHEME


hl.on("hyprland.start", function () 
  hl.exec_cmd("app2unit -s a kitty")
  hl.exec_cmd("[workspace special:easy silent] app2unit -s a easyeffects")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")
  -- hl.exec_cmd("systemctl --user import-environment QT_QPA_PLATFORMTHEME")
end)
