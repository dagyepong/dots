-- ~/.config/hypr/hyprland.lua
-- Hyprland 0.55+ (config in Lua), pensata per la shell Quickshell
-- Gemella di ~/.config/niri/config.kdl: stesse scorciatoie, stessa shell, stessi stili.
-- Scorciatoie: quickshell-binds.lua   |   Monitor (pagina Monitors della shell): quickshell-outputs.lua

------------------
---- MONITORS ----
------------------
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "1",
})

-- Posizione/scala/rotazione scelte dalla pagina Monitors della shell (file gestito da Quickshell)
pcall(function()
    package.loaded["quickshell-outputs"] = nil
    require("quickshell-outputs").apply()
end)

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("qs")                                                     -- shell (barra, notifiche, polkit...)
    hl.exec_cmd("sh ~/.config/quickshell/scripts/restore-wallpaper.sh")   -- sfondo e colori
    hl.exec_cmd("mkdir -p ~/Screenshots")                                 -- cartella screenshot
    hl.exec_cmd("sh ~/.config/quickshell/scripts/pywalfox-watch.sh")      -- colori Firefox (se pywalfox c'è)
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 15,

        -- Senza cornici
        border_size = 0,

        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 12,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 0.95,

        shadow = {
            enabled      = true,
            range        = 8,
            render_power = 3,
            color        = 0x66000000,
        },

        blur = {
            enabled  = true,
            size     = 6,
            passes   = 2,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Curve
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

-- Animazioni
hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

-- Layout
hl.config({ dwindle   = { preserve_split = true } })
hl.config({ master    = { new_status = "master" } })
hl.config({ scrolling = { fullscreen_on_one_column = true } })

-- Varie (lo sfondo lo disegna awww, quindi niente logo di Hyprland)
hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})

---------------
---- INPUT ----
---------------
hl.config({
    input = {
        kb_layout  = "it,us,gb,fr,de",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
-- Ignora le richieste di massimizzazione delle app
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix dei trascinamenti con XWayland
hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = "20 monitor_h-120",
    float = true,
})

-- Layer della shell Quickshell
hl.layer_rule({
    name = "blur-wallpaper-picker",
    match = { namespace = "shell-wallpaper" },
    blur = true,
})

hl.layer_rule({
    name = "no-anim-osd",
    match = { namespace = "shell-osd" },
    no_anim = true,
})

hl.layer_rule({
    name = "blur-hello",
    match = { namespace = "shell-hello" },
    blur = true,
})

---------------------
---- KEYBINDINGS ----
---------------------
-- Tutte le scorciatoie (finestre + shell) stanno in quickshell-binds.lua,
-- identiche a quelle di niri (~/.config/niri/config.kdl + quickshell.kdl).
-- package.loaded = nil: così anche dopo un reload le scorciatoie vengono registrate di nuovo.
do
    package.loaded["quickshell-binds"] = nil
    local ok, err = pcall(function() require("quickshell-binds").apply() end)
    if not ok then
        hl.exec_cmd("notify-send -u critical 'Hyprland' 'quickshell-binds.lua: " .. tostring(err):gsub("['\n]", " ") .. "'")
    end
end
