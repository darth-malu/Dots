hl.config({
  binds = {
    allow_workspace_cycles = true,           --false::
    workspace_back_and_forth = true,         --false::
    hide_special_on_workspace_change = true, --false::
  }
})

hl.config({
  input = {
    kb_layout                   = "us",
    kb_variant                  = "",
    kb_model                    = "",
    kb_options                  = "caps:swapescape",
    kb_rules                    = "",

    numlock_by_default          = true,

    follow_mouse                = 1,
    mouse_refocus               = true, -- if true mouse must cross boundary for focus change

    float_switch_override_focus = 2,    -- (1:: or 2), focus will change to the window under the cursor when changing from tiled-to-floating and vice versa. If 2, focus will also follow mouse on float-to-float switches.
    sensitivity                 = 0,    -- -1.0 - 1.0, 0 means no modification.
  },
})

hl.config({
  group = {
    groupbar = {
      enabled = true,
      font_size = 13,
      font_family = "quicksand medium",
      gradients = false,
      -- height = 14,
      -- indicator_gap = 2,
      -- indicator_height = 4,
      -- indicator_padding = 4,
      -- rendering_affected_by_opacity = false,
      text_color = "rgba(171, 141, 237, 0.90)",
      text_color_inactive = "rgba(147, 249, 255, 0.65)",
      col = {
        active = "rgba(171, 141, 237, 0.69)",
        inactive = "rgba(147, 249, 255, 189)",
        -- urgent = "rgb(85, 85, 255)",
      },
    },
  },
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
