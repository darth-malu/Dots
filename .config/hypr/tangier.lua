hl.monitor(
  {
    output = "eDP-1",
    mode = "1920x1080@60", -- Adjust resolution/refresh rate as needed
    position = "0x0",
    scale = 1.25,
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
    },
  },
})


hl.env("LIBVA_DRIVER_NAME,nvidia")         --hw acceleration
hl.env("__GLX_VENDOR_LIBRARY_NAME,nvidia") -- force GBM as backend
