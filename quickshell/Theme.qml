pragma Singleton
import QtQuick

QtObject {
    id: theme

    // Active Theme Selector ("srcery", "catppuccin", "nord")
    property string currentTheme: "srcery"

    // Srcery Palette (Derived from your Foot terminal configuration)
    readonly property var srcery: {
        "background": "#121110",
        "cardBackground": "#1c1a19",
        "foreground": "#fce8c3",
        "accent": "#fbb829",
        "green": "#519f50",
        "red": "#ef2f27",
        "blue": "#2c78bf",
        "muted": "#917e6b",
        "border": "#2a2826"
    }

    // Catppuccin Mocha (Smooth pastel eye-candy)
    readonly property var catppuccin: {
        "background": "#1e1e2e",
        "cardBackground": "#181825",
        "foreground": "#cdd6f4",
        "accent": "#fab387",
        "green": "#a6e3a1",
        "red": "#f38ba8",
        "blue": "#89b4fa",
        "muted": "#6c7086",
        "border": "#313244"
    }

    // Nord (Ice-cold arctic contrast)
    readonly property var nord: {
        "background": "#2e3440",
        "cardBackground": "#3b4252",
        "foreground": "#eceff4",
        "accent": "#88c0d0",
        "green": "#a3be8c",
        "red": "#bf616a",
        "blue": "#81a1c1",
        "muted": "#4c566a",
        "border": "#434c5e"
    }

    // Active Palette Map
    readonly property var palette: {
        switch (currentTheme) {
            case "catppuccin": return catppuccin;
            case "nord": return nord;
            default: return srcery;
        }
    }

    // Global Shortcuts for Quick Access in Cards and Pills
    property color bg: palette.background
    property color cardBg: palette.cardBackground
    property color fg: palette.foreground
    property color accent: palette.accent
    property color green: palette.green
    property color red: palette.red
    property color blue: palette.blue
    property color muted: palette.muted
    property color border: palette.border
}
