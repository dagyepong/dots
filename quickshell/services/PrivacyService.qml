// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P R I V A C Y   S E R V I C E                                          │
// │   what is using the microphone, the camera and the screen                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Whether something is listening, watching or sharing the screen, and which
// program. The microphone and the screen are PipeWire streams, read here as
// they come and go; the camera is `privacy.py`, since most programs open the
// device themselves. Built only while the island is allowed to show it
// (`ModuleService.activities`), so a machine that turned it off runs none of
// this.
Singleton {
    id: root

    // Every node, so their properties are bound and readable.
    readonly property PwObjectTracker tracker: PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    function prop(node: var, key: string): string {
        const value = node.properties ? node.properties[key] : undefined
        return value === undefined || value === null ? "" : `${value}`
    }

    // A program's name as a person would say it: the binary, else the name
    // the stream gives, first letter up.
    function nameOf(node: var): string {
        const raw = root.prop(node, "application.process.binary")
            || root.prop(node, "application.name") || node.name || ""
        const base = raw.replace(/\.(exe|bin)$/i, "")
        return base.charAt(0).toUpperCase() + base.slice(1)
    }

    readonly property var nodes: Pipewire.nodes.values

    // Applications recording the microphone (`AudioService.captures`, which
    // leaves out captures of what plays).
    readonly property var listeners: AudioService.captures

    // A video stream reading from somewhere: a camera through PipeWire, or a
    // shared screen.
    readonly property var viewers: root.nodes.filter(node =>
        root.prop(node, "media.class") === "Stream/Input/Video")

    // The screen as a source: the portal's node, named after the portal and
    // present only while a screen or a window is being shared.
    readonly property bool sharing: root.nodes.some(node =>
        root.prop(node, "media.class") === "Video/Source"
            && /xdg-desktop-portal|xdph/.test(node.name))

    // ── THE CAMERA ──────────────────────────────────────────────────────────

    // Program names from `privacy.py`, `pipewire` for a camera read through
    // PipeWire.
    property var cameraHolders: []

    readonly property Process camera: Process {
        command: [Quickshell.shellPath("scripts/privacy.py")]
        running: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.cameraHolders = JSON.parse(line).camera ?? []
                } catch (error) {
                    console.warn("Cannot read the camera's holders:", error)
                }
            }
        }
    }

    // ── WHAT THE ISLAND SHOWS ───────────────────────────────────────────────

    readonly property bool microphone: root.listeners.length > 0
    readonly property bool cameraOn: root.cameraHolders.length > 0
    readonly property bool screen: root.sharing

    readonly property bool active: root.microphone || root.cameraOn || root.screen

    // Who, most telling first: the program on the camera, on the microphone,
    // then whoever reads the shared screen.
    readonly property string who: {
        const names = []
        for (const holder of root.cameraHolders) {
            if (holder !== "pipewire")
                names.push(holder.charAt(0).toUpperCase() + holder.slice(1))
        }
        for (const node of root.listeners.concat(root.viewers))
            names.push(root.nameOf(node))
        return names.find(name => name !== "") ?? ""
    }
}
