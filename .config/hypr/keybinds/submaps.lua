-- Switch to a submap called `resize`.
hl.bind("ALT + R", hl.dsp.submap("resize"))

-- Start a submap called "resize".
hl.define_submap("resize", function()

    -- Set repeating binds for resizing the active window.
    hl.bind("right", hl.resize({ x = 10, y = 0, relative = true}), { repeating = true })
    hl.bind("left", hl.resize({ x = -10, y = 0, relative = true}), { repeating = true })
    hl.bind("up", hl.resize({ x = 0, y = 10, relative = true}), { repeating = true })
    hl.bind("down", hl.resize({ x = 10, y = -10, relative = true}), { repeating = true })

    -- Use `reset` to go back to the global submap
    hl.bind("escape", hl.dsp.submap("reset"))

end)

-- Keybinds further down will be global again...

-- NOTE submaps cn be nested - https://wiki.hypr.land/Configuring/Basics/Binds/#nesting
