hl.config({
    binds {
        drag_threshold = 10 -- Fire a drag event only after dragging for more than 10px
    }
})

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind("ALT + mouse:272", hl.dsp.window.drag(), { mouse = true })    -- ALT + LMB: Move a window by dragging more than 10px.
hl.bind("ALT + mouse:272", hl.dsp.window.resize(), { mouse = true })  -- ALT + LMB: Floats a window by clicking

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "m-1" }))
