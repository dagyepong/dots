pragma Singleton
import QtQuick 6.10
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool wifiEnabled: false
    property bool ethernetAvailable: false
    property bool ethernetConnected: false
    property bool connected: false
    property string activeType: "none"
    property string connectionName: ""
    property int signalStrength: 0
    property var accessPoints: []
    property bool refreshing: false
    property string stateText: {
        if (ethernetConnected) return connectionName.length > 0 ? connectionName : "Ethernet connected"
        if (!wifiEnabled && !ethernetAvailable) return "Network unavailable"
        if (!wifiEnabled && ethernetAvailable) return "Ethernet disconnected"
        if (connected && connectionName.length > 0) return connectionName
        return "Disconnected"
    }

    function updateStateFromOutput(output) {
        var text = output.trim()
        if (text.length === 0) {
            root.wifiEnabled = false
            root.ethernetAvailable = false
            root.ethernetConnected = false
            root.connected = false
            root.activeType = "none"
            root.connectionName = ""
            return
        }
        var lines = text.split("\n")
        var wifiPresent = false
        var wifiConnected = false
        var wifiConnection = ""
        var ethernetPresent = false
        var ethernetConnected = false
        var ethernetConnection = ""
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line) continue
            var parts = line.split(":")
            var deviceType = parts.length > 0 ? parts[0] : ""
            var state = parts.length > 1 ? parts[1] : "unavailable"
            var connection = parts.length > 2 ? parts.slice(2).join(":") : ""
            if (deviceType === "wifi") {
                wifiPresent = true
                if (state === "connected") {
                    wifiConnected = true
                    wifiConnection = connection
                }
            } else if (deviceType === "ethernet") {
                ethernetPresent = true
                if (state === "connected") {
                    ethernetConnected = true
                    ethernetConnection = connection
                }
            }
        }
        root.wifiEnabled = wifiPresent
        root.ethernetAvailable = ethernetPresent
        root.ethernetConnected = ethernetConnected

        if (root.ethernetConnected) {
            root.activeType = "ethernet"
            root.connected = true
            root.connectionName = ethernetConnection !== "--" ? ethernetConnection : ""
            return
        }

        if (wifiConnected) {
            root.activeType = "wifi"
            root.connected = true
            root.connectionName = wifiConnection !== "--" ? wifiConnection : ""
            return
        }

        root.activeType = "none"
        root.connected = false
        root.connectionName = ""
    }

    function updateAccessPointsFromOutput(output) {
        var text = output.trim()
        var points = []
        var strength = 0
        if (text.length > 0) {
            var lines = text.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                if (!line) continue
                var parts = line.split(":")
                if (parts.length < 4) continue
                var inUse = parts[0] === "*"
                var ssid = parts[1]
                var signal = parseInt(parts[2])
                var security = parts.slice(3).join(":")
                points.push({
                    inUse: inUse,
                    ssid: ssid.length > 0 ? ssid : "Hidden network",
                    signal: isNaN(signal) ? 0 : signal,
                    security: security
                })
                if (inUse) strength = isNaN(signal) ? 0 : signal
            }
        }
        root.accessPoints = points
        root.signalStrength = strength
    }

    function refresh() {
        if (root.refreshing) return
        root.refreshing = true
        wifiStateProcess.running = true
    }

    function setWifiEnabled(enabled) {
        toggleWifiProcess.command = ["nmcli", "radio", "wifi", enabled ? "on" : "off"]
        toggleWifiProcess.running = true
    }

    Process {
        id: wifiStateProcess
        running: false
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.updateStateFromOutput(text)
                wifiListProcess.running = true
            }
        }
        onExited: if (exitCode !== 0) wifiListProcess.running = true
    }

    Process {
        id: wifiListProcess
        running: false
        command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan auto 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.updateAccessPointsFromOutput(text)
                root.refreshing = false
            }
        }
        onExited: root.refreshing = false
    }

    Process {
        id: toggleWifiProcess
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: root.refresh()
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
