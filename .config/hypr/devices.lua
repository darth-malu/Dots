hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "caps:swapescape",
        kb_rules   = "",

        numlock_by_default = true;

        follow_mouse = 1,
        mouse_refocus = true, -- if true mouse must cross boundary for focus change

        float_switch_override_focus = 2; -- (1:: or 2), focus will change to the window under the cursor when changing from tiled-to-floating and vice versa. If 2, focus will also follow mouse on float-to-float switches.
        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = true,
        },
    },
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more

hl.device({
    name = "hp--inc-hyperx-alloy-origins-65",
    repeat_delay = 300, -- 400, ;;380
    repeat_rate = 39; -- ;;25 || nice: 39, 35
})

hl.device({
          name = "razer-razer-viper-mini",
          sensitivity = -0.8,
})

hl.monitor({
        output = "HDMI-A-1",
        mode = "1920x1080@240",
        position = "0x0",
        scale = 1,
        cm = "auto", -- srgb::, auto(recommended)
        -- vrr = 1,
        icc = "/media/Hyogo/Backups/ICC-profiles/XL2740_WHQL-driver_MP_Windows10_Windows7_Windows8/XL2740-WHQL-driver/XL2740.icm",
})
