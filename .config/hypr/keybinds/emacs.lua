local emacs = "app2unit -s a -- emacsclient -c"
local emacs_restart_ico = "/home/malu/Shibuya/assets/icons/icons8-emacs-color/icons8-emacs-48.png";
local emacs_restarting = "notify-send 'restarting emacs' -i " .. emacs_restart_ico;
local emacs_restarted = "notify-send 'restarted emacs' -i " .. emacs_restart_ico;

-- Emacs
hl.bind("SUPER + E", hl.dsp.exec_cmd(emacs))
hl.bind("SUPER + CONTROL + E", hl.dsp.focus({ window = "class:^[eE]macs$" }))
hl.bind("SUPER + SHIFT+ CONTROL + E",
  hl.dsp.exec_cmd(emacs_restarting .. " ; systemctl --user restart emacs && " .. emacs_restarted .. " ; " .. emacs))

local emptyEmacs = hl.window_rule({
  name = "Emacs - Launch in emptym",
  match = { class = "[eE]macs", initial_title = "^(.*)(Doom Emacs)$ | [eE]macs", },
  workspace = "emptym",
})
emptyEmacs:set_enabled(true)
