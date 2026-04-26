require("mouse_bind")

local mainMod = "SUPER"
local cl = "Control_L"
local al = "Alt_L"
local ar = "Alt_R"
local cr = "Control_R"
local sl = "SHIFT_L"
local sr = "SHIFT_R"
local kitty = "app2unit -s a -- kitty -1 --instance-group kitty"
local yazi_kitty = "app2unit -s a -- kitty -1 --instance-group yazi -e yazi"
local gaps = "gaps toggle_gaps_out"
local emacs = "app2unit -s a -- emacsclient -c"
local emacs_restart_ico = "/home/malu/Shibuya/assets/icons/icons8-emacs-color/icons8-emacs-48.png"
local notify_send_emacs_restarting = "notify-send 'restarting emacs' -i $emacs_restart_ico"
local notify_send_emacs_restarted = "notify-send 'restarted emacs' -i $emacs_restart_ico"
local formated_rgba = "$(hyprpicker -f rgb - | sed 's/^/(/; s/$/,1.0)/; y/ /,/' | wl-copy -n)"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))

local closeWindowBind = hl.bind(mainMod .. " + Escape", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
-- hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + /", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only

-- QUISHELL - ROFI
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("qs ipc call appLauncher toggle"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))


-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
-- hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("qs ipc call mpris next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("qs ipc call mpris togglePlaying"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("qs ipc call mpris togglePlaying"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("qs ipc call mpris previous"),   { locked = true })
