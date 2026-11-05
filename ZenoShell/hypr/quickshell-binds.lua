-- ~/.config/hypr/quickshell-binds.lua
-- Scorciatoie IDENTICHE a quelle di niri (config.kdl + quickshell.kdl).  Mod = Super, Alt = shell.

local M = {}

function M.apply()
    local mod = "SUPER"
    local qs  = function(args) return hl.dsp.exec_cmd("qs ipc call " .. args) end

    -- Se una funzione non esiste in questa versione di Hyprland, salta solo quella scorciatoia
    local function bind(keys, dsp, opts)
        local ok, err = pcall(function()
            local d = type(dsp) == "function" and dsp() or dsp
            if opts then hl.bind(keys, d, opts) else hl.bind(keys, d) end
        end)
        if not ok then
            hl.exec_cmd("notify-send 'Hyprland' 'Scorciatoia " .. keys .. " non registrata'")
        end
    end

    -- ── Applicazioni ──
    bind(mod .. " + RETURN",       hl.dsp.exec_cmd("kitty"))
    bind(mod .. " + F",            hl.dsp.exec_cmd("firefox"))
    bind(mod .. " + E",            hl.dsp.exec_cmd("nautilus"))

    -- ── Finestre ──
    bind(mod .. " + Q",            hl.dsp.window.close())
    bind(mod .. " + V",            hl.dsp.window.float({ action = "toggle" }))
    bind(mod .. " + CTRL + F",     function() return hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }) end)
    bind(mod .. " + SHIFT + F",    function() return hl.dsp.window.fullscreen({ mode = "maximized",  action = "toggle" }) end)
    bind(mod .. " + C",            function() return hl.dsp.window.center() end)
    bind(mod .. " + MINUS",        function() return hl.dsp.window.resize({ x = -120, y = 0 }) end, { repeating = true })
    bind(mod .. " + W",            function() return hl.dsp.window.resize({ x =  120, y = 0 }) end, { repeating = true })
    bind(mod .. " + SHIFT + E",    function() return hl.dsp.exit() end)

    -- Solo Hyprland (niri ha i suoi equivalenti: Mod+J preset larghezza, Mod+,/. colonne, Mod+Tab overview)
    bind(mod .. " + P",            hl.dsp.window.pseudo())
    bind(mod .. " + J",            hl.dsp.layout("togglesplit"))
    bind(mod .. " + TAB",          qs("workspaces toggle"))
    bind(mod .. " + S",            hl.dsp.workspace.toggle_special("magic"))
    bind(mod .. " + SHIFT + S",    hl.dsp.window.move({ workspace = "special:magic" }))

    -- ── Focus e spostamento ──
    for key, dir in pairs({ left = "left", right = "right", up = "up", down = "down" }) do
        bind(mod .. " + " .. key,             hl.dsp.focus({ direction = dir }))
        bind(mod .. " + SHIFT + " .. key,     function() return hl.dsp.window.move({ direction = dir }) end)
    end

    -- ── Workspace 1-10 ──
    for i = 1, 10 do
        local key = i % 10
        bind(mod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
        bind(mod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
    end
    bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
    bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
    bind(mod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
    bind(mod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })

    -- ── Shell: menu ──
    bind(mod .. " + R",            qs("launcher toggle"))
    bind("ALT + R",                qs("launcher toggle"))
    bind(mod .. " + M",            qs("power toggle"))
    bind("ALT + P",                qs("power toggle"))
    bind("ALT + W",                qs("wallpaper toggle"))
    bind("ALT + L",                qs("lock lock"))
    bind("ALT + I",                qs("system toggle"))
    bind("ALT + O",                qs("settings toggle"))
    bind("ALT + TAB",              qs("workspaces peek"))

    -- ── Shell: modalità ──
    bind("ALT + G",                qs("gamemode toggle"))
    bind("ALT + E",                qs("powersaver toggle"))
    bind("ALT + D",                qs("dnd toggle"))
    bind(mod .. " + SPACE",        qs("layout next"))

    -- ── Shell: stili ──
    bind("ALT + S",                qs("style toggle"))
    bind("ALT + T",                qs("theme toggle"))
    bind("ALT + V",                qs("style variant"))
    bind(mod .. " + ALT + T",      qs("theme mode toggle"))
    bind(mod .. " + ALT + 1",      qs("style set island"))
    bind(mod .. " + ALT + 2",      qs("style set classic"))
    bind(mod .. " + ALT + 3",      qs("style set dash"))
    bind(mod .. " + ALT + 4",      qs("style set side"))

    -- ── Shell: screenshot e registrazione ──
    bind("Print",                          qs("capture toggle"), { locked = true })
    bind(mod .. " + H",                    qs("capture shotscreen"), { locked = true })
    bind(mod .. " + SHIFT + H",            qs("capture shotarea"),   { locked = true })
    bind(mod .. " + CTRL + H",             qs("capture shotwindow"), { locked = true })
    bind(mod .. " + ALT + H",              qs("capture recscreen"),  { locked = true })
    bind(mod .. " + ALT + SHIFT + H",      qs("capture recarea"),    { locked = true })
    bind(mod .. " + ALT + P",              qs("capture pause"),      { locked = true })

    -- ── Volume, luminosità, media ──
    bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
    bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
    bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
    bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
    bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
    bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
    bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
    bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
end

return M
