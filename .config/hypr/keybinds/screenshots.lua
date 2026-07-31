local mainMod = "SUPER"

hl.bind("Print", hl.dsp.exec_cmd("grimblast --cursor --notify -e 2 copysave screen"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("grimblast --cursor --notify -e 2 copy screen"))
hl.bind("CONTROL + Print", hl.dsp.exec_cmd("grimblast --notify -e 2 copy area"))
hl.bind("ALT + Print", hl.dsp.exec_cmd("grimblast save area - | satty --filename -"))
