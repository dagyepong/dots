pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Look of the shell: light / dark mode and color theme.
//  - mode:  "dark" | "light". Regenerates the pywal palette from the current wallpaper
//           (wal -l for light), so the terminal and Firefox follow as well.
//  - theme: how the shell uses the pywal colors (see theme/themes.js). Only the shell changes.
// Saved in ~/.local/state/quickshell/appearance.json
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"

    property string mode: "dark"
    property string theme: "classic"
    property bool pickerOpen: false      // the selector inside the pill / side panel
    property string pickerScreen: ""    // monitor where it opens ("" = all)
    property bool applying: false

    readonly property var themes: [
        { id: "classic",    name: "Classic",       hint: "As it always was" },
        { id: "vivid",      name: "Vivid",         hint: "The most saturated color" },
        { id: "complement", name: "Complementary", hint: "Opposite hue to the wallpaper" },
        { id: "triad",      name: "Triad",         hint: "Three balanced hues" },
        { id: "analog",     name: "Analogous",     hint: "Neighbouring hues, soft" },
        { id: "mono",       name: "Monochrome",    hint: "One single hue" },
        { id: "tinted",     name: "Tinted",        hint: "Surfaces take the accent" },
        { id: "sober",      name: "Sober",         hint: "Muted and neutral" },
        { id: "contrast",   name: "Contrast",      hint: "Pure black / white, sharp" },
        { id: "neon",       name: "Neon",          hint: "Saturation to the max" }
    ]

    FileView {
        id: store
        path: root.stateDir + "/appearance.json"
        blockLoading: true
        printErrors: false
    }

    function save() {
        try { store.setText(JSON.stringify({ mode: mode, theme: theme })) } catch (e) { console.log("appearance: save:", e) }
    }

    function setTheme(id) {
        for (let i = 0; i < themes.length; i++) {
            if (themes[i].id === id) { theme = id; save(); return true }
        }
        return false
    }

    function setMode(m) {
        if (m === "toggle") m = (mode === "light") ? "dark" : "light"
        if (m !== "light" && m !== "dark") return false
        mode = m
        save()
        applying = true
        applyProc.command = ["sh", Quickshell.shellPath("scripts/apply-mode.sh"), m]
        applyProc.running = true
        return true
    }

    function open(screenName) {
        pickerScreen = screenName
        pickerOpen = true
    }

    function togglePicker() { pickerOpen = !pickerOpen }

    Process {
        id: applyProc
        onRunningChanged: if (!running) root.applying = false
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir])
        try {
            const d = JSON.parse(store.text())
            if (d.mode === "light" || d.mode === "dark") mode = d.mode
            for (let i = 0; i < themes.length; i++) if (themes[i].id === d.theme) theme = d.theme
        } catch (e) {}
        // the scripts that change the wallpaper read the mode from here
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$HOME/.cache/quickshell-theme-mode\"", "sh", mode])
    }
}
