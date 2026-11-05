pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property string name: ""            // es. "Italian"
    property string code: ""            // es. "IT"
    property bool armed: false          // no toast in the first seconds after startup

    // Layouts to choose from: "xkb" is the name Hyprland uses
    readonly property var layouts: [
        { code: "IT", xkb: "it", label: "Italian" },
        { code: "US", xkb: "us", label: "English (US)" },
        { code: "UK", xkb: "gb", label: "English (UK)" },
        { code: "FR", xkb: "fr", label: "French" },
        { code: "DE", xkb: "de", label: "German" }
    ]

    // Layouts Hyprland really knows (from kb_layout), e.g. ["it", "us", "gb"]
    property var configured: []

    readonly property string xkb: xkbFor(name)
    readonly property string subtitle: name !== "" ? code + " · " + name : "Layout not detected"

    function xkbFor(n) {
        if (/ital/i.test(n)) return "it"
        if (/\buk\b|united kingdom|british/i.test(n)) return "gb"
        if (/english|american|\bus\b/i.test(n)) return "us"
        if (/french|fran[cç]/i.test(n)) return "fr"
        if (/german|deutsch/i.test(n)) return "de"
        return ""
    }

    function codeFor(n) {
        const x = xkbFor(n)
        for (let i = 0; i < layouts.length; i++) if (layouts[i].xkb === x) return layouts[i].code
        return n.slice(0, 2).toUpperCase()
    }

    function announce() {
        Toast.push({
            kind: "notification",
            app: "Keyboard",
            summary: "Layout " + code,
            body: name,
            tone: "accent",
            duration: 1500
        })
    }

    // Applies a new layout and, if it really changed, shows the toast
    function apply(n, from) {
        const v = n.trim()
        console.log("KbLayout:", from, "->", JSON.stringify(v), "(before:", JSON.stringify(name) + ")")
        if (v === "" || v === name) return
        const changed = name !== ""
        name = v
        code = codeFor(v)
        if (changed && armed) announce()
    }

    function refresh() {
        if (Compositor.isNiri) {
            if (!niriProc.running) niriProc.running = true
        } else if (Compositor.isHyprland) {
            if (!devProc.running) devProc.running = true
        }
    }

    function test() {
        console.log("KbLayout: test toast")
        announce()
    }

    function next() {
        if (Compositor.isNiri) Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"])
        else Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
    }

    function previous() {
        if (Compositor.isNiri) Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "prev"])
        else Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "prev"])
    }

    // Picks a specific layout (e.g. "us", "gb", "fr")
    function setLayout(x) {
        const i = configured.indexOf(x)

        if (Compositor.isNiri) {
            if (i >= 0) {
                Quickshell.execDetached(["niri", "msg", "action", "switch-layout", String(i)])
            } else {
                Toast.push({
                    kind: "notification",
                    app: "Keyboard",
                    summary: "Layout not configured",
                    body: "Add it,us,gb,fr,de to layout in the niri config (input > keyboard > xkb)",
                    tone: "danger",
                    duration: 6000
                })
            }
            return
        }

        if (i >= 0) {
            Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(i)])
            return
        }

        // Hyprland does not know it yet: set the full list, then switch to the chosen one
        const list = []
        let idx = 0
        for (let k = 0; k < layouts.length; k++) {
            list.push(layouts[k].xkb)
            if (layouts[k].xkb === x) idx = k
        }
        Quickshell.execDetached(["sh", "-c",
            "hyprctl keyword input:kb_layout \"$1\" >/dev/null 2>&1; sleep 0.4; hyprctl switchxkblayout all \"$2\" >/dev/null 2>&1",
            "sh", list.join(","), String(idx)])
    }

    // Reading Hyprland state
    Process {
        id: devProc
        command: ["hyprctl", "devices", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    const ks = d.keyboards || []
                    let k = null
                    for (let i = 0; i < ks.length; i++) if (ks[i].main) k = ks[i]
                    if (!k && ks.length > 0) k = ks[0]
                    if (k) {
                        root.apply(k.active_keymap || "", "lettura")
                        root.configured = (k.layout || "").split(",").map(s => s.trim())
                    } else {
                        console.log("KbLayout: no keyboard found in hyprctl devices")
                    }
                } catch (e) {
                    console.log("KbLayout: invalid read:", e)
                }
            }
        }
    }

    // niri: list of layouts and the active one
    Process {
        id: niriProc
        command: ["niri", "msg", "--json", "keyboard-layouts"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    const names = d.names || []
                    root.configured = names.map(n => root.xkbFor(n))
                    const i = d.current_idx
                    if (i >= 0 && i < names.length) root.apply(names[i], "niri")
                } catch (e) {
                    console.log("KbLayout: invalid niri read:", e)
                }
            }
        }
    }

    // niri notifies when the layout changes
    Connections {
        target: Compositor

        function onKbChanged() { root.refresh() }
    }

    // Hyprland sends "activelayout>>keyboard,layout name" on every change
    Connections {
        target: Compositor.isHyprland ? Hyprland : null

        function onRawEvent(event) {
            if (event.name !== "activelayout") return
            const i = event.data.indexOf(",")
            root.apply(i >= 0 ? event.data.slice(i + 1) : event.data, "evento")
        }
    }

    // Safety net: re-reads the state every 4 seconds
    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 2500
        running: true
        onTriggered: root.armed = true
    }

    Component.onCompleted: refresh()
}
