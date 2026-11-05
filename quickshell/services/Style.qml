pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Bar style: chosen from the selector (qs ipc call style toggle), saved in ~/.local/state/quickshell/style.json
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"

    property string current: "island"
    property bool pickerOpen: false

    // Versions of the Dashboard style: "pill" (the pill that grows) or "attached" (a bar fused with the top edge)
    property string dashVariant: "pill"
    readonly property bool dashAttached: dashVariant === "attached"
    readonly property var dashVariants: [
        { id: "pill",     name: "Pill",     hint: "The floating pill" },
        { id: "attached", name: "Attached", hint: "A bar fused with the top edge" }
    ]
    property bool variantOpen: false        // the selector, inside the pill
    property string variantScreen: ""

    readonly property var styles: [
        { id: "island",  name: "Island",    hint: "Pills that expand",         ready: true },
        { id: "classic", name: "Classic",   hint: "Full-width bar",            ready: true },
        { id: "dash",    name: "Dashboard", hint: "One pill that grows",       ready: true },
        { id: "side",    name: "Vertical",  hint: "Bar and panels attached",     ready: true }
    ]

    FileView {
        id: store
        path: root.stateDir + "/style.json"
        blockLoading: true
        printErrors: false
    }

    function set(id) {
        for (let i = 0; i < styles.length; i++) {
            if (styles[i].id === id && styles[i].ready) {
                current = id
                save()
                return true
            }
        }
        return false
    }

    function save() {
        try { store.setText(JSON.stringify({ style: current, dashVariant: dashVariant })) } catch (e) { console.log("style: save:", e) }
    }

    function setDashVariant(id) {
        for (let i = 0; i < dashVariants.length; i++) {
            if (dashVariants[i].id === id) { dashVariant = id; save(); return true }
        }
        return false
    }

    function openVariants(screenName) {
        variantScreen = screenName
        variantOpen = true
    }

    function togglePicker() { pickerOpen = !pickerOpen }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir])
        try {
            const d = JSON.parse(store.text())
            for (let i = 0; i < styles.length; i++)
                if (styles[i].id === d.style && styles[i].ready) current = d.style
            if (d.dashVariant === "pill" || d.dashVariant === "attached") dashVariant = d.dashVariant
        } catch (e) {}
    }
}
