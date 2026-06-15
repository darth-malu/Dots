hl.monitor(
  {
    output = "HDMI-A-1",
    mode = "1920x1080@240",
    position = "0x0",
    scale = 1,
    cm = "auto",
    -- vrr = 1,
    -- icc = "home/malu/.config/hypr/XL2740.icm",
  }
)

hl.device({
  name = "hp--inc-hyperx-alloy-origins-65",
  repeat_delay = 300,
  repeat_rate = 39,
})

-- Razer Viper Mini configuration for Carthage
hl.device({
  name = "razer-razer-viper-mini",
  sensitivity = -0.8,
})

hl.config({
  input = {scroll_factor = 1.0,}
})
