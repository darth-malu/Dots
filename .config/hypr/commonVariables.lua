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

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
