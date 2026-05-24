-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this # the split (side/top) will not change regardless of what happens to the container.
        force_split = 2,       --2 right, 1 -left, 0 - folow mouse
        use_active_for_splits = true,
    },
})
