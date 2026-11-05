pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Options chosen in the Settings window. Saved in ~/.local/state/quickshell/settings.json.
// (Style, dashboard version, theme and light/dark have their own files and services: see Style and Appearance.)
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property string version: "1.1.49"

    // The Settings window
    property bool open: false
    property string screenName: ""      // monitor where it opens: the one with focus
    property string page: "appearance"

    // Clock
    property bool clock24: true                 // 24 h or 12 h with AM/PM
    property int weekStart: 1                   // 1 = Monday, 0 = Sunday
    readonly property string timeFormat: clock24 ? "HH:mm" : "h:mm AP"

    // OSD (volume / brightness) and Do Not Disturb
    property bool osdEnabled: true
    property int osdMs: 1500                    // how long the OSD stays on screen

    // Lock and inactivity (0 = never)
    property int lockMin: 0
    property int screenOffMin: 0

    FileView {
        id: store
        path: root.stateDir + "/settings.json"
        blockLoading: true
        printErrors: false
    }

    readonly property var keys: ["clock24", "weekStart", "osdEnabled", "osdMs", "lockMin", "screenOffMin"]

    function save() {
        const d = {}
        for (let i = 0; i < keys.length; i++) d[keys[i]] = root[keys[i]]
        try { store.setText(JSON.stringify(d)) } catch (e) { console.log("settings: save:", e) }
    }

    // Changes one option and saves it
    function set(key, value) {
        if (keys.indexOf(key) < 0) return false
        root[key] = value
        save()
        return true
    }

    function toggle() {
        if (!open) screenName = Compositor.focusedMonitor
        open = !open
    }
    function show(p) {
        if (p) page = p
        if (!open) screenName = Compositor.focusedMonitor
        open = true
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir])
        try {
            const d = JSON.parse(store.text())
            if (typeof d.clock24 === "boolean") clock24 = d.clock24
            if (d.weekStart === 0 || d.weekStart === 1) weekStart = d.weekStart
            if (typeof d.osdEnabled === "boolean") osdEnabled = d.osdEnabled
            if (typeof d.osdMs === "number" && d.osdMs >= 500 && d.osdMs <= 10000) osdMs = d.osdMs
            if (typeof d.lockMin === "number" && d.lockMin >= 0) lockMin = d.lockMin
            if (typeof d.screenOffMin === "number" && d.screenOffMin >= 0) screenOffMin = d.screenOffMin
        } catch (e) {}
    }
}
