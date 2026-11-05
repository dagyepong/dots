// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O T I O N                                                            │
// │   singleton · how the compositor moves, described once                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell

// Hyprland animation presets, pushed by CompositorService. Each is one bezier
// and three durations, in deciseconds (2.6 = 260 ms):
//
//   slow    geometry
//   medium  appearing and disappearing
//   fast    colour changes
//
// `windows` and `workspaces` are Hyprland animation styles; a `popin`
// percentage is the size a window starts at. Labels deliberately differ from
// the shell's own curve names (Smooth, Snappy, Springy).
Singleton {
    id: root

    readonly property var presets: [
        {
            // Id kept for existing settings files.
            id: "macos",
            label: "Glide",
            note: "Scales into place and decelerates with a long tail. Quick, and it never bounces.",
            curve: [0.32, 0.72, 0, 1],
            slow: 2.6, medium: 1.8, fast: 1.4,
            windows: "slide", workspaces: "slide"
        },
        {
            id: "snappy",
            label: "Brisk",
            note: "Half the distance and half the time. Movement you register rather than watch.",
            curve: [0.22, 1, 0.36, 1],
            slow: 1.3, medium: 1.0, fast: 0.8,
            windows: "popin 94%", workspaces: "slide"
        },
        {
            id: "smooth",
            label: "Calm",
            note: "Long and soft, and the screen fades between workspaces rather than sliding.",
            curve: [0.25, 0.1, 0.25, 1],
            slow: 4.2, medium: 3.0, fast: 2.2,
            windows: "popin 85%", workspaces: "fade"
        },
        {
            id: "springy",
            label: "Bounce",
            note: "Overshoots a little and settles back. The look most Hyprland presets are after.",
            curve: [0.05, 0.9, 0.1, 1.15],
            slow: 3.2, medium: 2.0, fast: 1.4,
            windows: "popin 80%", workspaces: "slide"
        },
        {
            id: "off",
            label: "None",
            note: "Nothing moves. Windows and workspaces appear where they are going to be."
        }
    ]

    function preset(id: string): var {
        return root.presets.find(entry => entry.id === id) ?? root.presets[0]
    }

    function labelOf(id: string): string {
        return root.preset(id).label
    }

    function noteOf(id: string): string {
        return root.preset(id).note
    }

    // The preset as a single Lua chunk for `hyprctl eval`, so it applies
    // atomically rather than one leaf per process.
    function chunk(id: string): string {
        const entry = root.preset(id)

        if (entry.id === "off")
            return "hl.config({ animations = { enabled = false } })"

        const c = entry.curve

        const lines = ["hl.config({ animations = { enabled = true } })",
                       `hl.curve("preset", { type = "bezier", points = { {${c[0]}, ${c[1]}}, {${c[2]}, ${c[3]}} } })`]

        function leaf(name, speed, style) {
            const tail = style ? `, style = "${style}"` : ""
            lines.push(`hl.animation({ leaf = "${name}", enabled = true, speed = ${speed}, bezier = "preset"${tail} })`)
        }

        // Parent first, so unnamed leaves inherit the preset instead of
        // Hyprland's default.
        leaf("global", entry.slow)

        leaf("windows", entry.slow)
        leaf("windowsIn", entry.slow, entry.windows)
        leaf("windowsOut", entry.medium, entry.windows)

        leaf("workspaces", entry.slow, entry.workspaces)
        leaf("workspacesIn", entry.slow, entry.workspaces)
        leaf("workspacesOut", entry.slow, entry.workspaces)

        leaf("layers", entry.medium)
        leaf("layersIn", entry.medium, "fade")
        leaf("layersOut", entry.fast, "fade")

        leaf("fade", entry.medium)

        // No fade-in. Opening a window re-tiles its neighbours, and a
        // half-transparent new window shows the wallpaper through the gap
        // being opened, which flashes on bright wallpapers.
        lines.push(`hl.animation({ leaf = "fadeIn", enabled = false })`)

        leaf("fadeOut", entry.fast)
        leaf("fadeLayersIn", entry.medium)
        leaf("fadeLayersOut", entry.fast)

        leaf("border", entry.fast)

        return lines.join(" ")
    }
}
