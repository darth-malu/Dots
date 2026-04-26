hl.config({
    decoration = {
      shadow = {
        enabled = true,
        -- "col.shadow" = "rgba(1E202966)";
        -- shadow_range = 60,
        color = "0xee1a1a1a",
        -- color_inactive = unset,
        range = 4,
        offset = "1 2",
        render_power = 3, -- TODO: different for tangier
        scale = 0.97,
      },
      blur = {
        enabled = true,
        size = 2, -- 2,
        passes = 3, -- 1:: - more strain on gpu-help with higher blur sizes looking wrong
        xray = true,
        -- vibrancy = 0.1696; #0.1696::, [0.0-1.0] saturation of blurred colours
        noise = 0.01,
      },

      rounding = 4,
      rounding_power = 4.0, -- 2.0::, larger is smoother, 2 is circle, 4 is squircle [2.0-10.0]
      active_opacity = 1,
      -- inactive_opacity = 0.95;
      dim_special = 0.7, -- 0.0 - 1.0
      dim_around = 0.4, -- dimaround rule
      # dim_strength = 0.8, -- how much inactive windows should be dimmed [0.0 - 1.0]
      dim_inactive = false,
      -- screen_shader
    },
    }
})
