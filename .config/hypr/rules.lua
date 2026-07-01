-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

local suppressMaximizeRule = hl.window_rule({
  -- Ignore maximize requests from all apps. You'll probably like this.
  name           = "suppress-maximize-events",
  match          = { class = ".*" },

  suppress_event = "maximize",
})
suppressMaximizeRule:set_enabled(true)

hl.window_rule({
  -- Fix some dragging issues with XWayland
  name     = "fix-xwayland-drags",
  match    = {
    class      = "^$",
    title      = "^$",
    xwayland   = true,
    float      = true,
    fullscreen = false,
    pin        = false,
  },

  no_focus = true,
})

-- hl.window_rule({
--   name  = "fix-xwayland-weird",
--   match = {
--     class    = "^(.*)$",
--     title    = "^(.*)$",
--     xwayland = true,
--   },

--   -- no_focus = true,
--   -- float = true,
-- })

hl.window_rule({
  name  = "Virtual Box New VM - fix",
  match = {
    class    = "VirtualBox",
    title    = "^New Virtual Machine$",
    xwayland = true,
  },
  float = true,
})

hl.window_rule({
  name  = "Select Fonts Qt6 settings",
  match = {
    class = "qt6ct",
    title = "^Select Font$",
  },
  size  = { 1000, 500 },
})

hl.window_rule({
  name = "Floating windows",
  match = { float = true },
  center = true,
  border_size = 0
})

hl.window_rule({
  name = "Hypr pipewire Float",
  match = { class = "hyprpwcenter", title = "Pipewire Control Center" },
  center = true,
  float = true,
})

hl.window_rule({
  name = "No border if only visible window in workspace (except special)",
  match = { workspace = "w[tv1]s[false]" },
  border_size = 0,
})


-- Smart Gaps - No gaps when only 1
-- hl.workspace_rule({
--     workspace = "w[tv1]" ,
--     gaps_out = 0,
--     gaps_in = 0,
--     -- rounding    = 0,
-- })

-- TODO: reconcile no gaps if one visible window

-- WORKSPACE RULES
-- hl.workspace_rule({ workspace = "w[tv1]s[false]", border_size = 0})
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "special:easy", "easyeffects" })
hl.workspace_rule({ workspace = "special:nc", on_created_empty = "app2unit -s a kitty -e ncmpcpp" })
hl.workspace_rule({
  workspace = "special:magic",
  on_created_empty =
  "[workspace special:magic;float true;size (monitor_w*0.9) (monitor_h*0.8);center true] app2unit -s a kitty"
})
-- hl.workspace_rule({ workspace = "7", layout = "scrolling" })

-- TODO: see if I need persistence on QUickshell windows (for testing)
-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.

-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })

-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- TODO: tangier specific


-- kde kalk
hl.window_rule({
  name = "KDE kalk",
  match = { class = "org.kde.kalk" },
  float = true,
  persistent_size = true
})
-- "float true, match:class org.kde.kalk"
-- "persistent_size true, match:class org.kde.kalk"

hl.window_rule({
  name = "Modal windows", -- Are you sure? windows
  match = { modal = true },
  -- size = "(monitor_w*0.8) (monitor_h*0.8)",
  float = true,
  center = true,
})

hl.window_rule({
  name = "Telegram App",
  match = { class = "org.telegram.desktop", initial_title = "^(Telegram)(.*)$", },
  size = "(monitor_w*0.8) (monitor_h*0.6)",
  float = true,
  center = true,
  -- persistent_size = true
})


hl.window_rule({
  name = "Qbittorent - Empty Workspace",
  match = { initial_class = "^(org.qbittorrent.qBittorrent)$", initial_title = "^(.*)(qBittorrent v.*)$", },
  workspace = "emptym",
})


hl.window_rule({
  name = "Viewnior - Images",
  match = { class = "[vV]iewnior", initial_class = "^(.*)([Vv]iewnior)$", },
  workspace = "emptym",
  center = true,
  float = true,
})

hl.window_rule({
  name = "FLoat and center YouTubr",
  match = { initial_title = "youtubr" },
  float = true,
  center = true,
})

hl.window_rule({
  name = "Save to Dialog",
  match = { class = "udiskie", title = "(.*)(save to)(.*)" },
  size = "(monitor_w*0.6) (monitor_h*0.6)",
  center = true,
})

hl.window_rule({
  name = "Udiskie Mount ISO",
  match = { class = "udiskie", title = "Open disc image" },
  size = "(monitor_w*0.7) (monitor_h*0.6)",
  center = true,
  pin = true,
  float = true
})

-- SOUND GAME
hl.window_rule({
  name = "Pwvucontrol",
  match = { class = "com.saivert.pwvucontrol" },
  float = true,
  center = true,
  pin = true,
  size = "(monitor_w*0.7) (monitor_h*0.6)",
})

-- LUKS
hl.window_rule({
  name = "LUKS float entry window etc",
  match = { class = "udiskie", title = "udiskie" },
  float = true,
  center = true,
  size = "(monitor_w*0.2) (monitor_h*0.1)",
})

-- BROWSERS
hl.window_rule({
  name = "Google chrome",
  match = { class = "^(google-chrome)", },
  persistent_size = true,
})

local chrome_menu = hl.window_rule({
  -- Ignore maximize requests from all apps. You'll probably like this.
  name    = "Chrome Weird ness",
  match   = { class = "^()$" },
  no_blur = true,
})
chrome_menu:set_enabled(true)

-- GAMES
hl.window_rule({
  name = "BattleNet",
  match = { initial_class = "steam_app_default", initial_title = "^(.*)(Battle.net)$" },
  workspace = "emptym",
})

local gameTear = hl.window_rule({
  name = "Allow Tearing Dota etc",
  match = { class = "^(cs2|dota)$" },
  immediate = true,
  content = "game",
})
gameTear:set_enabled(false)

local mpv = hl.window_rule({
  name = "MPV emptym launch",
  match = { class = "mpv" },
  workspace = "emptym",
  content = "video",
})
mpv:set_enabled(false)


local emptymSteam = hl.window_rule({
  name      = "Main Steam Page In Emptym -- After everything is loaded",
  match     = { class = "steam", title = "Steam" },
  workspace = "emptym",
})
emptymSteam:set_enabled(true)

local nofocusSteamOffers = hl.window_rule({
  name     = "no focus on steam offers",
  match    = { class = "^steam$ | ^$", title = "^(Special Offers)$" },
  no_focus = true,
})
nofocusSteamOffers:set_enabled(true)

hl.window_rule({
  name      = "Silent Sign In page --steam",
  match     = { class = "^(steam)$", title = "^(Sign in to Steam)$" },
  workspace = "emptym silent",
})

hl.window_rule({
  name = "Discord - Init Load up",
  match = { class = "^(.*)([dD]iscord)$", title = "(Discord Updater)", },
  workspace = "emptym silent",
})

hl.window_rule({
  name = "Discord - Main App",
  match = { initial_title = "^(.*)(Discord)$", initial_class = "^(discord)$", },
  workspace = "emptym",
})

--[[

  MOVED - Keybinds
  ----------------
+ FreeTube
+ Discord
+ Emacs

]]
