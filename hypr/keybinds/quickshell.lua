local mod = "SUPER +"

-- Media
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("qs ipc call mpris next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("qs ipc call mpris togglePlaying"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("qs ipc call mpris togglePlaying"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("qs ipc call mpris previous"),   { locked = true })

hl.bind(mod .. "+ SHIFT + I",  hl.dsp.exec_cmd("qs ipc call mpris songArt"),   { locked = true })

hl.bind(mod .. "Delete",  hl.dsp.exec_cmd("qs -p $HOME/.config/quickshell/notBar/wlogout/shell.qml"),   { locked = true })

hl.bind(mod .. "ALT + 0",  hl.dsp.exec_cmd("systemctl --user restart quickshell"),   { locked = true })
hl.bind(mod .. "ALT + 9",  hl.dsp.exec_cmd("qs ipc call bar toggleBar"),   { locked = true })
hl.bind(mod .. "ALT + 1",  hl.dsp.exec_cmd("qs ipc call activate toggle"),   { locked = true })

hl.bind(mod ..  "ALT + x",  hl.dsp.exec_cmd("qs ipc call notifications dismissAll"),   { locked = true })
hl.bind(mod ..  "ALT + t",  hl.dsp.exec_cmd("qs ipc call Time currentDate"),   { locked = true })
hl.bind(mod ..  "backslash",  hl.dsp.exec_cmd("qs ipc call Time currentDate"),   { locked = true })

        -- "$mod $al, N, execr, qs ipc call netspeed toggleNet"
        -- "$mod $al, R, execr, qs ipc call resources toggleResources"
        -- "$mod , BackSpace, execr, qs ipc call clipHist toggle"
