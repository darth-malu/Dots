local mod = "SUPER +"
local mainMod = "SUPER"

-- Media
hl.bind(mainMod .. "+ Control + I", hl.dsp.exec_cmd("qs ipc call mpris toggleMpris"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("qs ipc call mpris next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("qs ipc call mpris pauseAll"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("qs ipc call mpris togglePlaying"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("qs ipc call mpris previous"), { locked = true })
hl.bind(mod .. "XF86AudioPlay", hl.dsp.exec_cmd("qs ipc call mpris toggleView"), { locked = true })
hl.bind("ALT + XF86AudioPlay", hl.dsp.exec_cmd("qs ipc call mpris toggleMpris"), { locked = true })

hl.bind(mod .. "SHIFT+I", hl.dsp.exec_cmd("qs ipc call mpris songArt"), { locked = true })
hl.bind(mod .. "ALT+I", hl.dsp.exec_cmd("qs ipc call notifications showLast"), { locked = true })
hl.bind(mod .. "SHIFT+ space", hl.dsp.exec_cmd("qs ipc call notifications dismissAll"), { locked = true })

-- alt + wheel = cycle the bartop mpris player (up = previous, down = next).
-- the bar is a layer-shell without keyboard focus, so its own wheel events
-- never carry the alt modifier — the compositor's binds see it reliably and
-- consume the wheel before it reaches the bar's volume handler.
hl.bind("ALT + mouse_up", hl.dsp.exec_cmd("qs ipc call mpris cycle prev"), { locked = true })
hl.bind("ALT + mouse_down", hl.dsp.exec_cmd("qs ipc call mpris cycle next"), { locked = true })

-- BAR
hl.bind(mod .. "Delete", hl.dsp.exec_cmd("qs ipc call logout toggle"), { locked = true }) --now integrated into quickshell (toggle via IPC)
hl.bind(mod .. "HOME", hl.dsp.exec_cmd("qs ipc call bar toggleBar"), { locked = true })
hl.bind(mod .. "ALT + HOME", hl.dsp.exec_cmd("systemctl --user restart quickshell"), { locked = true })

-- SETTINGS
hl.bind(mod .. "Prior", hl.dsp.exec_cmd("qs ipc call settings toggle"), { locked = true })

-- TIME
hl.bind(mod .. "backslash", hl.dsp.exec_cmd("qs ipc call Time currentDate"), { locked = true })
hl.bind(mod .. "ALT + backslash", hl.dsp.exec_cmd("qs ipc call Time currentDateTime"), { locked = true })

-- Resources, etc
-- hl.bind(mod .. "ALT + 1", hl.dsp.exec_cmd("qs ipc call netspeed toggleNet"), { locked = true })
hl.bind(mod .. "ALT + Left", hl.dsp.exec_cmd("qs ipc call netspeed toggleNet"), { locked = true })
-- hl.bind(mod .. "ALT + 2", hl.dsp.exec_cmd("qs ipc call resources toggleResources"), { locked = true })
hl.bind(mod .. "ALT + right", hl.dsp.exec_cmd("qs ipc call resources toggleResources"), { locked = true })
-- hl.bind(mod .. "ALT + 3", hl.dsp.exec_cmd("qs ipc call SysTray toggle"), { locked = true })
hl.bind(mod .. "ALT + Down", hl.dsp.exec_cmd("qs ipc call SysTray toggle"), { locked = true })
-- hl.bind(mod .. "ALT + 5", hl.dsp.exec_cmd("qs ipc call activate toggle"), { locked = true })

-- QUISHELL - ROFI
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("qs ipc call appLauncher toggle"))
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("qs ipc call openWindows toggle"))
hl.bind(mainMod .. " + backspace", hl.dsp.exec_cmd("qs ipc call clipHist toggle"))
hl.bind(mainMod .. " + SHIFT + comma", hl.dsp.exec_cmd("qs ipc call calc toggle"))

-- QUICKSHELL - PICKERS
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("qs ipc call emoji toggle"))
hl.bind(mainMod .. " + w", hl.dsp.exec_cmd("qs ipc call wallpaperPicker toggle"))
hl.bind(mainMod .. " + SHIFT + w", hl.dsp.exec_cmd("qs ipc call wallpaper toggleQuotes"), { locked = true })
hl.bind(mainMod .. " + SHIFT + period", hl.dsp.exec_cmd("qs ipc call color toggle"))

--
