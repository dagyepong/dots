pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int temperature: 4200
    property bool wanted: false              // what you chose (remembered across restarts)
    property bool restartPending: false

    readonly property bool on: proc.running
    readonly property string statePath: Quickshell.env("HOME") + "/.cache/quickshell-nightlight.json"

    function save() {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sh",
                                 JSON.stringify({ on: wanted, temperature: temperature }),
                                 statePath])
    }

    function set(enable) {
        wanted = enable
        proc.running = enable
        save()
    }

    function toggle() { set(!wanted) }

    function setTemperature(t) {
        temperature = Math.round(Math.max(2500, Math.min(6500, t)) / 100) * 100
        restartTimer.restart()
        saveTimer.restart()
    }

    // Restore at shell startup
    FileView {
        id: store
        path: root.statePath
        blockLoading: true
    }

    function load() {
        try {
            const d = JSON.parse(store.text())
            if (d.temperature) temperature = d.temperature
            wanted = !!d.on
        } catch (e) {}
        if (wanted) proc.running = true
    }

    Component.onCompleted: load()

    // Save the temperature only when you stop dragging the slider
    Timer {
        id: saveTimer
        interval: 600
        onTriggered: root.save()
    }

    // Change temperature: restarts gammastep with the new value
    Timer {
        id: restartTimer
        interval: 300
        onTriggered: {
            if (proc.running) {
                root.restartPending = true
                proc.running = false
            }
        }
    }

    Process {
        id: proc
        command: ["gammastep", "-O", String(root.temperature)]
        onRunningChanged: {
            if (!running && root.restartPending) {
                root.restartPending = false
                running = true
            }
        }
    }
}
