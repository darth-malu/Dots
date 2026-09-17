-- Switch to a submap called `resize`.
hl.bind("SUPER + ALT + R", hl.dsp.submap("resize"))

-- Start a submap called "resize".
hl.define_submap("resize", function()
  -- Set repeating binds for resizing the active window.
  hl.bind("right", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
  hl.bind("left", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
  hl.bind("up", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
  hl.bind("down", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })

  -- Use `reset` to go back to the global submap
  hl.bind("escape", hl.dsp.submap("reset"))
end)

-- Keybinds further down will be global again...

-- NOTE submaps cn be nested - https://wiki.hypr.land/Configuring/Basics/Binds/#nesting

-- MOVE
hl.bind("SUPER + ALT + M", hl.dsp.submap("drag"))

-- Start a submap called "resize".
hl.define_submap("drag", function()
  -- Set repeating binds for resizing the active window.
  hl.bind("right", hl.dsp.window.move({ x = 10, y = 0, relative = true }), { repeating = true })
  hl.bind("left", hl.dsp.window.move({ x = -10, y = 0, relative = true }), { repeating = true })
  hl.bind("up", hl.dsp.window.move({ x = 0, y = 10, relative = true }), { repeating = true })
  hl.bind("down", hl.dsp.window.move({ x = 0, y = -10, relative = true }), { repeating = true })

  -- Use `reset` to go back to the global submap
  hl.bind("escape", hl.dsp.submap("reset")) --
end)

-- GROUP MANAGEMENT
hl.bind("SUPER + G", hl.dsp.submap("group_management"), { description = "Enter a group management submap" })

local map = function(key, action, description)
  hl.bind(key, function()
    hl.dispatch(action)
    hl.dispatch(hl.dsp.submap("reset"))
  end, { description = description })
end

hl.define_submap("group_management", function()
  map("g", hl.dsp.group.toggle(), "Toggle window group")

  map("h", hl.dsp.window.move({ into_group = "l" }), "Move window into a group on the left")
  map("j", hl.dsp.window.move({ into_group = "d" }), "Move window into a group on the bottom")
  map("k", hl.dsp.window.move({ into_group = "u" }), "Move window into a group on the top")
  map("l", hl.dsp.window.move({ into_group = "r" }), "Move window into a group on the right")

  map("e", hl.dsp.window.move({ out_of_group = true }), "Move window out of group")

  map("n", hl.dsp.group.next(), "Next window in group")
  map("p", hl.dsp.group.prev(), "Previous window in group")

  map("f", hl.dsp.group.move_window(), "Move window forward in the group order")
  map("b", hl.dsp.group.move_window({ forward = false }), "Move window backward in the group order")

  map("t", hl.dsp.group.lock_active(), "Toggle group lock")

  for i = 1, 10 do
    map(tostring(i % 10), hl.dsp.group.active({ index = i }), "Focus window " .. i .. " in a group")
  end

  hl.bind("escape", hl.dsp.submap("reset"), { description = "Quit submap" })
end)
