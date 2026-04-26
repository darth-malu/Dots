hl.config({
    general = {
      -- https://wiki.hyprland.org/Configuring/Variables/
      col = {
        -- active_border = { colors= "rgba(00FFF5aa)" },
        active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
        inactive_border = "rgba(595959aa)",
      },
      gaps_in = 6, -- NOTE: space essential for gaps script
      gaps_out = 12,
      border_size = 1,
      resize_on_border = true,
      resize_corner = 3, -- 0:: 1-4 clockwise
      hover_icon_on_border = true;
      layout = vars.layout,
      allow_tearing = false, -- false:: - alternatively use immediate rule
      -- no_border_on_floating = true,
      no_focus_fallback = true, -- false, will not fall back to the next available window when moving focus in a direction where no window was found
      snap = {
        enabled = true,
        window_gap = 10,
        monitor_gap = 10,
        border_overlap = true, -- false::, if true one borders worth btwn windows
      };
    }

})
