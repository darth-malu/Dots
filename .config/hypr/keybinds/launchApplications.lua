local emacs = "app2unit -s a -- emacsclient -c"
local emacs_restart_ico = "/home/malu/Shibuya/assets/icons/icons8-emacs-color/icons8-emacs-48.png";
local emacs_restarting = "notify-send 'restarting emacs' -i " .. emacs_restart_ico;
local emacs_restarted = "notify-send 'restarted emacs' -i ".. emacs_restart_ico;
local mainMod = "SUPER"
local kitty = "app2unit -s a -- kitty -1 --instance-group kitty"
local yazi_kitty = "app2unit -s a -- kitty -1 --instance-group yazi -e yazi"

-- Kitty
hl.bind(mainMod .. " + return", hl.dsp.exec_cmd(kitty))
hl.bind(mainMod .. "+ SHIFT + return", hl.dsp.exec_cmd("[workspace emptym]" ..kitty))
hl.bind(mainMod .. " + CONTROL + return", hl.dsp.focus({window="class:^kitty$"}))

hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd("[workspace emptym]" .. yazi_kitty))
hl.bind(mainMod .. " + CONTROL + Y", hl.dsp.focus({window="title:^(Yazi)(.*)"}))

-- Emacs
hl.bind("SUPER + E", hl.dsp.exec_cmd(emacs))
hl.bind("SUPER + CONTROL + E", hl.dsp.focus({window="class:^[eE]macs$"}))
hl.bind("SUPER + ALT + E", hl.dsp.exec_cmd(emacs_restarting .." ; systemctl --user restart emacs && " .. emacs_restarted .. " ; " .. emacs))
local emptyEmacs = hl.window_rule({
    name = "Emacs - Launch in emptym",    
    match= {  class = "[eE]macs", initial_title = "^(.*)(Doom Emacs)$ | [eE]macs", },
    workspace = "emptym",
})
emptyEmacs:set_enabled(true)

--dolphin
hl.bind(mainMod .. "+ N", hl.dsp.exec_cmd("dolphin"))
hl.bind(mainMod .. "+ CONTROL + N", hl.dsp.focus({window="class:^org.kde.dolphin$"}))

hl.bind(mainMod .. "+ SHIFT + N", hl.dsp.exec_cmd("nautilus"))
hl.bind(mainMod .. "+ SHIFT + CONTROL + N", hl.dsp.focus({window="class:^org.gnome.nautilus"}))

-- QUISHELL - ROFI
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("qs ipc call appLauncher toggle"))
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("qs ipc call openWindows toggle"))
hl.bind(mainMod .. " + backspace", hl.dsp.exec_cmd("qs ipc call clipHist toggle"))

-- BROWSER
hl.bind("SUPER + B", hl.dsp.exec_cmd("app2unit -s a -- qutebrowser")) -- can be --last
hl.bind("SUPER + CONTROL + B", hl.dsp.focus({window = "class:^org.qutebrowser.qutebrowser$"}))

hl.bind("SUPER + F", hl.dsp.exec_cmd("app2unit -s a -- firefox"))
hl.bind("SUPER + CONTROL + F", hl.dsp.focus({window = "class:^firefox$"}))

hl.bind("SUPER + C", hl.dsp.exec_cmd("app2unit -s a -- google-chrome"))
hl.bind("SUPER + CONTROL + C", hl.dsp.focus({window="class:[Gg]oogle-chrome"}))

hl.bind("SUPER + D", hl.dsp.exec_cmd("app2unit -s a -- discord"))
hl.bind("SUPER + CONTROL + D", hl.dsp.focus({window = "class:discord"}))
hl.window_rule({
    name = "Discord - Init Load up",    
    match= {  class = "^(.*)([dD]iscord)$", title = "(Discord Updater)", },
    workspace = "emptym silent",
})
hl.window_rule({
    name = "Discord - Main App",    
    match= {  initial_title = "^(.*)(Discord)$", initial_class = "^(discord)$", },
    workspace = "emptym",
})

hl.bind("SUPER + T", hl.dsp.exec_cmd("app2unit -s a -- freetube"))
hl.bind("SUPER + CONTROL + T", hl.dsp.focus({window = "initialtitle:FreeTube"}))
hl.window_rule({
    name = "FreeTube to w10",
    match = {class = "^(FreeTube)$"},
})

-- DANGLING FOCUS
-- TODO: see if you can loop through all instances of class mpv inorder
hl.bind("SUPER + CONTROL + M", hl.dsp.focus({window="class:^mpv$"}))
