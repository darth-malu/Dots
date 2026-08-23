local mod = "SUPER +"
local mainMod = "SUPER"

-- Media
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("qs ipc call mpris next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("qs ipc call mpris togglePlaying"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("qs ipc call mpris togglePlaying"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("qs ipc call mpris previous"), { locked = true })
hl.bind(mod .. "+ XF86AudioPlay", hl.dsp.exec_cmd("qs ipc call mpris toggleMprisArt"), { locked = true })

hl.bind(mod .. "+ SHIFT + I", hl.dsp.exec_cmd("qs ipc call mpris songArt"), { locked = true })
hl.bind(mod .. "+ ALT + I", hl.dsp.exec_cmd("qs ipc call notifications showLast"), { locked = true })
hl.bind(mod .. "SHIFT+ space", hl.dsp.exec_cmd("qs ipc call notifications dismissAll"), { locked = true })

-- BAR
hl.bind(mod .. "Delete", hl.dsp.exec_cmd("qs ipc call logout toggle"), { locked = true }) --now integrated into quickshell (toggle via IPC)
hl.bind(mod .. "HOME", hl.dsp.exec_cmd("qs ipc call bar toggleBar"), { locked = true })
hl.bind(mod .. "ALT + HOME", hl.dsp.exec_cmd("systemctl --user restart quickshell"), { locked = true })

-- TIME
hl.bind(mod .. "backslash", hl.dsp.exec_cmd("qs ipc call Time currentDate"), { locked = true })
hl.bind(mod .. "ALT + backslash", hl.dsp.exec_cmd("qs ipc call Time currentDateTime"), { locked = true })

-- Resources, etc
hl.bind(mod .. "ALT + 1", hl.dsp.exec_cmd("qs ipc call netspeed toggleNet"), { locked = true })
hl.bind(mod .. "ALT + Left", hl.dsp.exec_cmd("qs ipc call netspeed toggleNet"), { locked = true })
hl.bind(mod .. "ALT + 2", hl.dsp.exec_cmd("qs ipc call resources toggleResources"), { locked = true })
hl.bind(mod .. "ALT + right", hl.dsp.exec_cmd("qs ipc call resources toggleResources"), { locked = true })
hl.bind(mod .. "ALT + 3", hl.dsp.exec_cmd("qs ipc call SysTray toggle"), { locked = true })
hl.bind(mod .. "ALT + Down", hl.dsp.exec_cmd("qs ipc call SysTray toggle"), { locked = true })
hl.bind(mod .. "ALT + 5", hl.dsp.exec_cmd("qs ipc call activate toggle"), { locked = true })

-- QUISHELL - ROFI
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("qs ipc call appLauncher toggle"))
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("qs ipc call openWindows toggle"))
hl.bind(mainMod .. " + backspace", hl.dsp.exec_cmd("qs ipc call clipHist toggle"))
