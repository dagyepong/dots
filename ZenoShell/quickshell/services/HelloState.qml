pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Session-start welcome: on/off (saved in ~/.local/state/quickshell/hello.json)
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"

    property bool enabled: true

    signal preview()

    FileView {
        id: store
        path: root.stateDir + "/hello.json"
        blockLoading: true
        printErrors: false
    }

    function set(v) {
        enabled = v
        try {
            store.setText(JSON.stringify({ enabled: v }))
        } catch (e) {
            console.log("hello: save:", e)
        }
    }

    function toggle() { set(!enabled) }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir])
        try {
            const d = JSON.parse(store.text())
            if (typeof d.enabled === "boolean") enabled = d.enabled
        } catch (e) {}
    }
}
