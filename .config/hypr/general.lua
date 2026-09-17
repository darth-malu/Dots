hl.config({
  general = {
    -- https://wiki.hyprland.org/Configuring/Variables/
    col = {
      active_border = { colors = { "rgba(2196F3FF)" } }, --rgba(00FFF5aa)
      -- active_border   = { colors = {"rgba(33ccffee)", "rgba(FF5555FF)"}, angle = 45 },
      inactive_border = "rgba(607D8BFF)",
    },
    gaps_in = 4, -- NOTE: space essential for gaps script
    gaps_out = 9,
    border_size = 1,
    resize_on_border = true,
    resize_corner = 3,        -- 0:: 1-4 clockwise
    hover_icon_on_border = true,
    allow_tearing = false,    -- false:: - alternatively use immediate rule
    no_focus_fallback = false, -- false, will not fall back to the next available window when moving focus in a direction where no window was found
    snap = {
      enabled = true,
      window_gap = 10,
      monitor_gap = 10,
      border_overlap = true, -- false::, if true one borders worth btwn windows
    },
  }
})
