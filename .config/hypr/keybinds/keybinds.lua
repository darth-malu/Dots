local emacs = "app2unit -s a -- emacsclient -c || uwsm-app -s a -- emacsclient -c"
local emacs_restart_ico = "/home/malu/Shibuya/assets/icons/icons8-emacs-color/icons8-emacs-48.png";
local emacs_restarting = "notify-send 'restarting emacs' -i " .. emacs_restart_ico;
local emacs_restarted = "notify-send 'restarted emacs' -i " .. emacs_restart_ico;
local mainMod = "SUPER"
local kitty = "app2unit -s a -- kitty -1 --instance-group kitty || uwsm-app -s a -- kitty -1 --instance-group kitty"
local yazi_kitty =
"app2unit -s a -- kitty -1 --instance-group yazi -e yazi || uwsm-app -s a -- kitty -1 --instance-group yazi -e yazi"
local mainMod = "SUPER"
local mainMod_SHIFT = "SUPER + SHIFT"
local mainMod_CTRL = "SUPER + CTRL"

-- Kitty
hl.bind(mainMod .. " + return", hl.dsp.exec_cmd(kitty))
hl.bind(mainMod .. "+ SHIFT + return", hl.dsp.exec_cmd("[workspace emptym]" .. kitty))
hl.bind(mainMod .. " + CONTROL + return", hl.dsp.focus({ window = "class:^kitty$" }))

hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd("[workspace emptym]" .. yazi_kitty))
hl.bind(mainMod .. " + CONTROL + Y", hl.dsp.focus({ window = "title:^(Yazi)(.*)" }))

-- Stremio
hl.bind(mainMod .. " + CONTROL + 1", hl.dsp.focus({ window = "class:^(com.stremio.Stremio)(.*)" }))
-- hl.bind(mainMod .. " + CONTROL + 9",
-- hl.dsp.focus({ window = [[class:^(com.stremio.Stremio)(.*)]], title = [[^(Stremio)(.*)]] }))
-- hl.dsp.focus({ window = [[class:^(com.stremio.Stremio)(.*)]], title = [[^(Stremio)(.*)]] }))

--dolphin
-- hl.bind(mainMod .. "+ N", hl.dsp.exec_cmd("nautilus", { workspace = "emptym" }))
hl.bind(mainMod .. "+ N", hl.dsp.exec_cmd("app2unit -s a -- nautilus || uwsm-app -s a -- nautilus"))
hl.bind(mainMod .. "+ CONTROL + N", hl.dsp.focus({ window = "class:^org.gnome.nautilus" }))

hl.bind(mainMod .. "+ SHIFT + N", hl.dsp.exec_cmd("app2unit -s a -- dolphin || uwsm-app -s a -- dolphin"))
hl.bind(mainMod .. "+ SHIFT + CONTROL + N", hl.dsp.focus({ window = "class:^org.kde.dolphin$" }))

-- BROWSER
hl.bind("SUPER + B", hl.dsp.exec_cmd("app2unit -s a -- qutebrowser || uwsm-app -s a -- qutebrowser")) -- can be --last
hl.bind("SUPER + CONTROL + B", hl.dsp.focus({ window = "class:^org.qutebrowser.qutebrowser$" }))

hl.bind("SUPER + F", hl.dsp.exec_cmd("app2unit -s a -- firefox || uwsm-app -s a -- firefox "))
hl.bind("SUPER + CONTROL + F", hl.dsp.focus({ window = "class:^firefox$" }))

hl.bind("SUPER + C", hl.dsp.exec_cmd("app2unit -s a -- google-chrome || uwsm-app -s a -- google-chrome "))
hl.bind("SUPER + CONTROL + C", hl.dsp.focus({ window = "class:[Gg]oogle-chrome" }))

hl.bind("SUPER + Z", hl.dsp.exec_cmd("app2unit -s a -- zen || uwsm-app -s a -- zen "))
hl.bind("SUPER + CONTROL + Z", hl.dsp.focus({ window = "class:zen" }))

hl.bind("SUPER + D", hl.dsp.exec_cmd("app2unit -s a -- discord || uwsm-app -s a -- discord "))
hl.bind("SUPER + CONTROL + D", hl.dsp.focus({ window = "class:discord" }))

hl.bind("SUPER + T", hl.dsp.exec_cmd("app2unit -s a -- freetube || uwsm-app -s a -- freetube "))
hl.bind("SUPER + CONTROL + T", hl.dsp.focus({ window = "initialtitle:FreeTube" }))

-- DANGLING FOCUS
-- TODO: see if you can loop through all instances of class mpv inorder
hl.bind("SUPER + CONTROL + M", hl.dsp.focus({ window = "class:^mpv$" }))
-- hl.bind(keys, dispatcher, { flag1 = true, flag2 = true })
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

-- steam
hl.bind(mainMod .. "+ s", hl.dsp.exec_cmd("steam"))
hl.bind(mainMod_CTRL .. " + s", hl.dsp.focus({ window = "class:.*steam.*" }))
hl.bind(mainMod_CTRL .. " + 2", hl.dsp.focus({ window = "class:dota2" }))
-- hl.bind(mainMod .. "+ s", hl.dsp.focus({ last = "urgent_or_last" }))

-- SCREENSHOTS
<<<<<<< HEAD
-- hl.bind("Print", hl.dsp.exec_cmd("grimblast --cursor --notify -e 2 copysave screen"))
hl.bind("Print",
  hl.dsp.exec_cmd('grim - | satty -f - --copy-command wl-copy -o "~/Pictures/Satty/%Y%m%d_%H%M%S.png"'))

hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("grimblast --cursor --notify -e 2 copy screen"))
hl.bind("CONTROL + Print", hl.dsp.exec_cmd("grimblast --notify -e 2 copy area"))
hl.bind("ALT + Print", hl.dsp.exec_cmd("grimblast save area - | satty --filename -"))

=======
>>>>>>> 3691aba (kinda unmodded)
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

-- UUCTL
hl.bind(mainMod .. "+ U", hl.dsp.exec_cmd("uuctl"))
hl.bind(mainMod .. "+ SHIFT + U", hl.dsp.exec_cmd("systemctl --user restart mpd.service"))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "m+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "m-1" }))

hl.bind("SUPER + mouse:275", hl.dsp.window.close(), { mouse = true }) -- ALT + LMB: Floats a window by clicking
hl.bind("SUPER + mouse:276", hl.dsp.focus({ workspace = "previous_per_monitor" }))

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
  { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
  { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
  { locked = true, repeating = true })
-- hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
