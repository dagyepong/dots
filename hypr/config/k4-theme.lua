-- Generado por k4 · módulo HyprTheme.
-- No lo edites a mano: se reescribe cada vez que guardas desde la barra.
-- Para revertirlo: borra este archivo y su línea require de hyprland.lua.

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(30d158ff)", "rgba(0a6b3dff)" }, angle = 45 },
            inactive_border = "rgba(3a5c48ff)",
        },
    },
    decoration = {
        rounding = 10,
        active_opacity = 0.95,
        inactive_opacity = 0.85,
        blur = {
            enabled = true,
            size = 5,
            passes = 4,
        },
        shadow = { enabled = true },
    },
})

hl.animation({ leaf = "global", enabled = true, speed = 3, bezier = "quick" })
