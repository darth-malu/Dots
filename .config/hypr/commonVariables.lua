hl.config({
  binds = {
    allow_workspace_cycles = true,           --false::
    workspace_back_and_forth = true,         --false::
    hide_special_on_workspace_change = true, --false::
  }
})

hl.config({
  render = {
    async_commit = true, --false:: -- reduce hw latency by sending DRM commits async when possible
  },
  cursor = {
    hide_on_key_press = true,
  }
})

hl.config({
  ecosystem = {
    no_donation_nag = true, --OMARXCY lol
  },
})

hl.config({
  input = {
    kb_layout                   = "us",
    kb_variant                  = "",
    kb_model                    = "",
    -- kb_options                  = "caps:swapescape",
    kb_rules                    = "",

    numlock_by_default          = true,

    follow_mouse                = 1,
    mouse_refocus               = false, -- true:: -- if true mouse must cross boundary for focus change, follow_mouse must be 1

    float_switch_override_focus = 2,     -- (1:: or 2), focus will change to the window under the cursor when changing from tiled-to-floating and vice versa. If 2, focus will also follow mouse on float-to-float switches.
    -- TODO: see if this is what is causing issues with my focusss
    sensitivity                 = 0,     -- -1.0 - 1.0, 0 means no modification.
  },
})

hl.config({
  group = {
    col = {
      -- border_active
      -- border_inactive
    },
    groupbar = {
      enabled = true,
      blur = true,
      font_size = 13,
      font_family = "quicksand medium",
      gradients = true,
      -- height = 14,
      -- indicator_gap = 2,
      -- indicator_height = 4,
      -- indicator_padding = 4,
      -- rendering_affected_by_opacity = false,
      text_color = "rgba(215, 200, 255, 0.95)",
      text_color_inactive = "rgba(160, 195, 215, 0.60)",
      col = {
        active = "rgba(130, 110, 200, 0.49)",
        inactive = "rgba(45, 55, 75, 0.75)",
        -- urgent = "rgba(255, 140, 170, 0.90)",
      },
    },
  },
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
