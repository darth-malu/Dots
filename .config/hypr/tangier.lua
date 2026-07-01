hl.monitor(
  {
    output = "eDP-1",
    mode = "1920x1080@60", -- Adjust resolution/refresh rate as needed
    position = "0x0",
    scale = 1.25,
    cm = "auto",
  }
)

-- Presentation settings
hl.monitor(
  {
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
    mirror = "eDP-1",
    cm = "auto",
  }
)

hl.device({
  name = "at-translated-set-2-keyboard", -- Example typical laptop keyboard ID
  repeat_delay = 380,
  repeat_rate = 39,
})


hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
      disable_while_typing = true,
      drag_lock = false,
      clickfinger_behavior = true, -- Button presses with 1, 2, or 3 fingers will be mapped to LMB, RMB, and MMB respectively. This disables interpretation of clicks based on location on the touchpad. libinput#clickfinger-behavior
      tap_and_drag = true,
      scroll_factor = 1.0,         --1.2;;
    },
    -- sensitivity = 0.1,
  },
  xwayland = {
    force_zero_scaling = true
  },
  gestures = {
    workspace_swipe_distance = 260,     -- 300::
    workspace_swipe_create_new = false, -- new empty after last workspace
    workspace_swipe_forever = true,     -- NOTE....false sucks
    --workspace_swipe_touch = true,       -- swipe from the edge of touchpad
    -- workspace_swipe_use_r = true; -- r instead of m
  },
})


hl.env("LIBVA_DRIVER_NAME", "nvidia")         --hw acceleration
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia") -- force GBM as backend

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down", mods = "ALT", action = "close" })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
