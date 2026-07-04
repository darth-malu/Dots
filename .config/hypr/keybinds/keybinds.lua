require("keybinds.launchApplications")
require("keybinds.quickshell")
require("keybinds.multimedia")

-- hl.bind(keys, dispatcher, { flag1 = true, flag2 = true })
local mainMod = "SUPER"
-- local gaps = "gaps toggle_gaps_out"
-- local emacs_restart_ico = "/home/malu/Shibuya/assets/icons/icons8-emacs-color/icons8-emacs-48.png"
-- local notify_send_emacs_restarting = "notify-send 'restarting emacs' -i $emacs_restart_ico"
-- local notify_send_emacs_restarted = "notify-send 'restarted emacs' -i $emacs_restart_ico"
-- local formated_rgba = "$(hyprpicker -f rgb - | sed 's/^/(/; s/$/,1.0)/; y/ /,/' | wl-copy -n)"

local closeWindowBind = hl.bind(mainMod .. " + escape", hl.dsp.window.close())
closeWindowBind:set_enabled(true)

-- hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + slash", hl.dsp.layout("swapsplit")) -- dwindle only
hl.bind("SUPER + SHIFT + slash", hl.dsp.layout("togglesplit"))
-- hl.bind("SUPER + A", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. "+ A", hl.dsp.window.pseudo())

-- SCREENSHOTS
hl.bind("Print", hl.dsp.exec_cmd("grimblast --cursor --notify -e 2 copysave screen"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("grimblast --cursor --notify -e 2 copy screen"))
hl.bind("CONTROL + Print", hl.dsp.exec_cmd("grimblast --notify -e 2 copy area"))
hl.bind("ALT + Print", hl.dsp.exec_cmd("grimblast save area - | satty --filename -"))

-- "SUPER, G, exec, sh -c 'grimblast save area - | satty --filename -'"
hl.bind(mainMod .. " + M", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + q", hl.dsp.workspace.toggle_special("quanta"))
hl.bind(mainMod .. " + SHIFT + q", hl.dsp.window.move({ workspace = "special:quanta" }))

hl.bind(mainMod .. " + Next", hl.dsp.workspace.toggle_special("easy"))
hl.bind(mainMod .. " + SHIFT + Next", hl.dsp.window.move({ workspace = "special:easy" }))

hl.bind(mainMod .. " + I", hl.dsp.workspace.toggle_special("nc"))

hl.bind(mainMod .. " + ALT + return", hl.dsp.focus({ workspace = "emptym" }))

hl.bind(mainMod .. " + up", hl.dsp.group.toggle({ "activewindow" }))
hl.bind(mainMod .. " + down", hl.dsp.group.lock_active({ "toggle" })) -- TODO: check out lock

-- hl.bind(mainMod .. " + left",         hl.dsp.group.active({1})) -- TODO: check out changegroup active
hl.bind(mainMod .. " + right", hl.dsp.group.next())
hl.bind(mainMod .. " + left", hl.dsp.group.prev())
hl.bind(mainMod .. "+ SHIFT + right", hl.dsp.group.move_window())
hl.bind(mainMod .. "+ SHIFT + left", hl.dsp.group.move_window())

-- hl.bind(mainMod .. " + apostrophe",         hl.dsp.group.active({f})) -- TODO: check out changegroup active
-- # "$mod ,apostrophe,changegroupactive,f"
-- # "$mod ,quotedbl,changegroupactive,b"

-- "$mod $sl , right, movewindoworgroup, r"
-- "$mod $sl , left, movewindoworgroup, l"

-- MOVEMENT
-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. "+ CONTROL + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. "+ CONTROL + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. "+ CONTROL + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. "+ CONTROL + j", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. "+ CONTROL + H", hl.dsp.focus({ direction = "left" }))

hl.bind("SUPER + l", hl.dsp.focus({ workspace = "m+1" }))
hl.bind("SUPER + h", hl.dsp.focus({ workspace = "m-1" }))

-- URGENT, LAST , EMPTY
hl.bind(mainMod .. "+ O", hl.dsp.window.move({ workspace = "emptym" }))
hl.bind(mainMod .. "+ K", hl.dsp.focus({ last = "urgent_or_last" })) -- can be --last

hl.bind("SUPER + space", hl.dsp.window.cycle_next())                 -- can be --last

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
  local key = i % 10 -- 10 maps to key 0
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
-- hl.config({
--     binds {
--         drag_threshold = 10 -- Fire a drag event only after dragging for more than 10px
--     }
-- })

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. "+ mouse:272", hl.dsp.window.drag(), { mouse = true })   -- ALT + LMB: Move a window by dragging more than 10px.
hl.bind(mainMod .. "+ mouse:273", hl.dsp.window.resize(), { mouse = true }) -- ALT + LMB: Floats a window by clicking
hl.bind(mainMod .. "+ CONTROL + mouse:273", hl.dsp.exec_cmd("qs ipc call openWindows toggle"))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "m+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "m-1" }))

hl.bind("SUPER + mouse:275", hl.dsp.window.close(), { mouse = true }) -- ALT + LMB: Floats a window by clicking
hl.bind("SUPER + mouse:276", hl.dsp.focus({ workspace = "previous_per_monitor" }))
