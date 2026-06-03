-- hl.env("HYPRCURSOR_THEME" ,"theme_GoogleDot-Violet")
-- hl.env("HYPRCURSOR_SIZE" ,"24")

hl.env("SLURP_ARGS" , "-d -b -B F050F022 -b 10101022 -c ff00ff")


-- TODO: Ways To Require based on different hostNames - Tangier
-- hl.env("LIBVA_DRIVER_NAME,nvidia") -hardware acceleration

-- QT
hl.env("QT_QPA_PLATFORM", "wayland;xcb") -- Qt: Use Wayland if available, fall back to X11 if not.
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR" , "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- GDK
hl.env("GDK_SCALE" ,"1")
hl.env("GDK_DPI_SCALE", "1")
hl.env("GDK_BACKEND" ,"wayland,x11,*")
-- hl.env("SDL_VIDEODRIVER", "wayland") -- Run SDL2 applications on Wayland. Remove or set to x11 if games that provide older versions of SDL cause compatibility issues
-- hl.env("CLUTTER_BACKEND", "wayland")
