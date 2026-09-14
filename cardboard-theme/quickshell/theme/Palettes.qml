// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P A L E T T E S                                                        │
// │   curated colour schemes · single source of truth                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick

// Curated palettes. This is the only place a palette is described: the
// customizer reads its label and swatches from here, and ThemeService reads
// the tokens from the same entry, so the two can never disagree.
QtObject {
    id: root

    readonly property var list: [
        {
            id: "catppuccin_mocha",
            name: "Catppuccin Mocha",
            badge: "Dark Pastel",
            swatches: ["#89b4fa", "#f5c2e7", "#a6e3a1", "#fab387"],
            colors: {
                background: "#1e1e2e", surface: "#181825", surfaceHover: "#313244",
                border: "#45475a", text: "#cdd6f4", textMuted: "#a6adc8",
                accent: "#89b4fa", accentHover: "#b4befe", accentText: "#11111b",
                red: "#f38ba8", green: "#a6e3a1", yellow: "#f9e2af", blue: "#89b4fa"
            }
        },
        {
            id: "catppuccin_latte",
            name: "Catppuccin Latte",
            badge: "Light Clean",
            swatches: ["#1e66f5", "#8839ef", "#40a02b", "#ea76cb"],
            colors: {
                background: "#eff1f5", surface: "#e6e9ef", surfaceHover: "#ccd0da",
                border: "#bcc0cc", text: "#4c4f69", textMuted: "#6c6f85",
                accent: "#1e66f5", accentHover: "#04a5e5", accentText: "#eff1f5",
                red: "#d20f39", green: "#40a02b", yellow: "#df8e1d", blue: "#1e66f5"
            }
        },
        {
            id: "tokyo_night",
            name: "Tokyo Night",
            badge: "Cyber City",
            swatches: ["#7aa2f7", "#bb9af7", "#9ece6a", "#f7768e"],
            colors: {
                background: "#1a1b26", surface: "#16161e", surfaceHover: "#24283b",
                border: "#292e42", text: "#c0caf5", textMuted: "#7982a9",
                accent: "#7aa2f7", accentHover: "#bb9af7", accentText: "#15161e",
                red: "#f7768e", green: "#9ece6a", yellow: "#e0af68", blue: "#7aa2f7"
            }
        },
        {
            id: "gruvbox_dark",
            name: "Gruvbox Dark",
            badge: "Warm Retro",
            swatches: ["#d79921", "#83a598", "#b8bb26", "#fb4934"],
            colors: {
                background: "#282828", surface: "#1d2021", surfaceHover: "#3c3836",
                border: "#504945", text: "#ebdbb2", textMuted: "#a89984",
                accent: "#d79921", accentHover: "#fabd2f", accentText: "#282828",
                red: "#fb4934", green: "#b8bb26", yellow: "#fabd2f", blue: "#83a598"
            }
        },
        {
            id: "nord",
            name: "Nord",
            badge: "Arctic Frost",
            swatches: ["#88c0d0", "#81a1c1", "#a3be8c", "#bf616a"],
            colors: {
                background: "#2e3440", surface: "#242933", surfaceHover: "#3b4252",
                border: "#434c5e", text: "#eceff4", textMuted: "#d8dee9",
                accent: "#88c0d0", accentHover: "#81a1c1", accentText: "#2e3440",
                red: "#bf616a", green: "#a3be8c", yellow: "#ebcb8b", blue: "#81a1c1"
            }
        },
        {
            id: "rose_pine",
            name: "Rosé Pine",
            badge: "Soho Dusk",
            swatches: ["#ebbcba", "#f6c177", "#31748f", "#eb6f92"],
            colors: {
                background: "#191724", surface: "#1f1d2e", surfaceHover: "#26233a",
                border: "#403d52", text: "#e0def4", textMuted: "#908caa",
                accent: "#ebbcba", accentHover: "#f6c177", accentText: "#191724",
                red: "#eb6f92", green: "#31748f", yellow: "#f6c177", blue: "#9ccfd8"
            }
        },
        {
            id: "cyberpunk",
            name: "Cyberpunk",
            badge: "Neon Synth",
            swatches: ["#ff007f", "#00e5ff", "#ffea00", "#00e676"],
            colors: {
                background: "#0d0f18", surface: "#141726", surfaceHover: "#21253b",
                border: "#ff007f", text: "#e0f7fa", textMuted: "#00e5ff",
                accent: "#ff007f", accentHover: "#00e5ff", accentText: "#ffffff",
                red: "#ff1744", green: "#00e676", yellow: "#ffea00", blue: "#00e5ff"
            }
        },
        {
            id: "bauhaus",
            name: "Bauhaus",
            badge: "Modernist",
            swatches: ["#e52521", "#2b82d9", "#f5a623", "#f5f5f5"],
            colors: {
                background: "#1a1a1a", surface: "#242424", surfaceHover: "#333333",
                border: "#444444", text: "#f5f5f5", textMuted: "#999999",
                accent: "#e52521", accentHover: "#f5a623", accentText: "#ffffff",
                red: "#e52521", green: "#2b82d9", yellow: "#f5a623", blue: "#2b82d9"
            }
        },
        {
            id: "crimson",
            name: "Crimson Moon",
            badge: "Vampiric",
            swatches: ["#e63946", "#ff4d6d", "#ad8394", "#f7e1ea"],
            colors: {
                background: "#120a0d", surface: "#1c1015", surfaceHover: "#2d1822",
                border: "#4a2133", text: "#f7e1ea", textMuted: "#ad8394",
                accent: "#e63946", accentHover: "#ff4d6d", accentText: "#ffffff",
                red: "#e63946", green: "#52b788", yellow: "#ee9b00", blue: "#a2d2ff"
            }
        }
    ]

    function byId(paletteId: string): var {
        return root.list.find(palette => palette.id === paletteId) ?? null
    }
}
